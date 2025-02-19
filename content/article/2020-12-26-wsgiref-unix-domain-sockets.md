---
date: 2020-12-26T11:15:00-08:00
title: wsgiref and Unix Domain Sockets
slug: wsgiref-unix-domain-sockets
tags:
  - AF_UNIX
  - network
  - programming
  - Python
  - webdev
  - wsgi
---

Recently, I needed to hack together a quick server-side application for a test page.
When it comes to quick and dirty, most people turn to [Python](https://www.python.org/).
While Python is hardly my *favorite* language, it is certainly suited for the task.

One of my requirements was that I wanted to minimize the number of dependencies.
Installing Python is bad enough (my nginx container is *extremely* bare bones), but installing a massive framework for what was effectively a wrapper around a system command would make things even worse.
So I decided to make due with `wsgiref.simple_server` that ships with CPython.

Unfortunately, when it came time to installing the script on the server, I discovered that `simple_server` only supports IPv4 and that is baked in.
For security purposes, I like to use unix domain sockets whenever possible.
It guarantees the endpoint can only be access from the local host and I can even configure permissions based on the *user*.
Fortunately, it isn't that hard to modify `simple_server` to support other protocols.

## Socket Families and Python

Each protocol family has its own unique representation for an address.
Most people are familiar with IPv4 (`AF_INET`), which uses a 32-bit IP address and a 16-bit port.
Related to IPV4 is IPv6 (`AF_INET6`), which extends the address to 128 bits and adds two more fields: scope id and flow id.
These later two are ignored by most people, but are used to handle link local addresses (scope id) and multicast (flow id).
But simplest of all are unix domain sockets (`AF_UNIX`), which need only a string.

Whereas these address are represented with unique types in C, Python represents them all as tuples (except for `AF_UNIX` which is just the string).
`AF_INET` addresses are a two element tuple.
`AF_INET6` addresses can be either four elements (the full representation) or two elements (a compatibility hack with `AF_INET`).
Unfortunately, throughout the `simple_server` code, it just naively assumes everything is `AF_INET`.
There's some hand waving at `AF_INET6` support, but it fails miserably when faced with the bare string of `AF_UNIX`.

## Fixing `WSGIServer`

The first problem we encounter can be found in the implementation of `WSGIServer`.
More accurately, this is inherited from the [base implementation of `HTTPServer`](https://github.com/python/cpython/blob/v3.9.1/Lib/http/server.py#L136) itself:

```python
def server_bind(self):
    """Override server_bind to store the server name."""
    socketserver.TCPServer.server_bind(self)
    host, port = self.server_address[:2]
    self.server_name = socket.getfqdn(host)
    self.server_port = port
```

Here, we see it just naively assumes the address is a tuple of two or more elements.
While that will work for `AF_INET` and `AF_INET6`, it will fail for `AF_UNIX`.
To fix this, we need to wholesale replace the implementation of `server_bind`:

```python
from wsgiref.simple_server import WSGIServer
import socket
import socketserver

class NewWSGISServer(WSGIServer):
    def __init__(self, server_address, RequestHandlerClass,
                 address_family = socket.AF_INET):
        # Override Address Family
        self.address_family = address_family
        WSGIServer.__init__(self, server_address, RequestHandler)

    def server_bind(self):
        # Expand HTTPServer's handling of address families
        socketserver.TCPServer.server_bind(self)
        if self.address_family == socket.AF_UNIX:
            server_name = socket.gethostname()
            self.server_port = 0
        else:
            server_name = self.server_address[0]
            self.server_port = self.server_address[1]
        self.server_name = socket.getfqdn(server_name)
        self.setup_environ()
```

The unresolved question is how best to fill out `server_name` and `server_port` for a `AF_UNIX` address.
In this case, I simply used the local hostname and a zero.
Assigning `None` to `server_port` ends up creating a problem later when it's inevitably converted to a string.

## Fixing `WSGIRequestHandler`

The next problem can be found in the implementation of `WSGIRequestHandler`.
More accurately, it can be found throughout the implementation of `HTTPRequestHandler`.
However, it's used purely for cosmetic purposes so we can simply inject a placeholder value.

```python
from wsgiref.simple_server import WSGIRequestHandler
import socket

class NewWSGIRequestHandler(WSGIRequestHandler):
    def __init__(self, request, client_address, server):
        self.address_family = server.address_family
        if self.address_family == socket.AF_UNIX:
            client_address = ('<unix>', 0)
        WSGIRequestHandler.__init__(self, request, client_address, server)
```

One of the problems with unix domain sockets is that the client generally has *no* address, so we just fill in `<unix>` so it has *something*.

## Putting It Together

There's one last problem to address with unix domain sockets.
There is a file on the filesystem associated with the socket.
If that file exists when we create the socket, the process will fail.
When we close the socket, the file is not cleaned up for us.
So, we're going to need a helper to manage this for us.

```python
import os

class AddressManager(object):
    def __init__(self, family, addr=None, path=None):
        self.family = family
        self.addr = addr or path
        self.path = path

    def __enter__(self):
        self.delete()
        return (self.family, self.addr)

    def __exit__(self, type, value, traceback):
        try:
            self.delete()
        except PermissionError:
            logging.warning('Failed to delete socket %s', self.path)

    def delete(self):
        if not self.path:
            return
        try:
            os.remove(self.path)
        except FileNotFoundError:
            pass
```

Now, we can create our `simple_server` and start answering requests.

```python
with AddressManager(socket.AF_UNIX, path=path) as (family, addr):
    with NewWSGISServer(addr, NewWSGIRequestHandler, family) as httpd:
        httpd.set_app(handler)
        httpd.serve_forever()
```

> **Note:** You'll probably want to fix the permissions on the socket after it is created.
> FreeBSD applies the file permissions when determining connection rights for the socket but this is system-dependent.

## Other Annoyances: Initial Environment

`wsgiref` commits one of the greatest programmer sins possible: the use of *hidden* global state.
When the module is *first loaded*, it makes [a copy of the global environment](https://github.com/python/cpython/blob/v3.9.1/Lib/wsgiref/handlers.py#L110) and then uses it to populate every request handler.

As part of our overhaul, we can stem this information leak, too.
First, we need to write a replacement for `WSGIServerHandler`:

```python
from wsgiref.simple_server import WSGIServerHandler

class NewServerHandler(WSGIServerHandler):
    os_environ = {}
```

And then we need to make our request handler use it.
Unfortunately, `wsgiref` does not make this easy, so we're going to need to duplicate a lot of code.

```python
from wsgiref.simple_server import WSGIRequestHandler
import socket

class NewWSGIRequestHandler(WSGIRequestHandler):
    def __init__(self, request, client_address, server):
        # NOTE: This is unchanged from the previous example
        self.address_family = server.address_family
        if self.address_family == socket.AF_UNIX:
            client_address = ('<unix>', None)
        WSGIRequestHandler.__init__(self, request, client_address, server)

    def handle(self):
        self.raw_requestline = self.rfile.readline(65537)
        if len(self.raw_requestline) > 65536:
            self.requestline = ''
            self.request_version = ''
            self.command = ''
            self.send_error(414)
            return
        if not self.parse_request():
            return
        handler = NewServerHandler(
            self.rfile, self.wfile, self.get_stderr(), self.get_environ(),
            multithread=False,
        )
        handler.request_handler = self
        handler.run(self.server.get_app())
```

And there you have it: an implementation of `wsgiref` that lets you listen on unix domain sockets and won't leak your environment.
