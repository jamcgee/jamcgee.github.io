---
date: 2021-01-13T10:00:00-08:00
title: "Portable Sockets: Basics"
slug: portable-sockets-basics
tags:
  - network
  - portability
  - programming
  - Unix
  - Windows
---

In the modern world, people tend to use massive frameworks to accomplish simple tasks.
Nothing quite like swatting a fly with a nuclear missile when you load up 100 megs of runtime just to execute `ping` and post the result to a database.
But sometimes, when you're writing a utility, you want it to be quick and lightweight.
And if you're going through the effort, you might as well see about making it portable.

Every extent Unix system uses BSD sockets for their networking layer, which traces back to 1983 and the release of 4.2BSD.
In this model, network connections ("sockets") are full fledged kernel objects that built on top of the existing Unix API (e.g. `read`, `write`, and `close`).
Additional system calls were introduced both to create new sockets (e.g. `socket`) as well as provide networking-related operations (e.g. `connect`, `listen`, and `accept`).

By comparison, the original version of WinSock was a completely user space affair with its own API, loosely modeled on BSD sockets, but distinct from the system's native interface.
As the interface transitioned into the 32-Bit era with WinSock 2, it began to integrate more closely into the Win32 API.
While Microsoft has written some material on [porting Unix applications to WinSock](https://docs.microsoft.com/en-us/windows/win32/winsock/porting-socket-applications-to-winsock), it leaves unanswered the question as to how to portably target both platforms.

<!--more-->

## Header Files

The first visible difference will be the set of headers to include.
The networking functions in Unix are spread across a dozen different headers.
Most of these headers are fairly obvious in function, but one of the more subtle points is the existence of `<sys/types.h>`.
While many platforms will include it transitively, this header needs to be included before many others per POSIX.
For broadest compatibility, it's better to explicitly include it at the beginning of the `#include` block.

Windows is much simpler in this respect, nearly everything being drawn in by the `<WinSock2.h>` header.
The only complication comes from its transitive dependency on `<Windows.h>`.
By default, `<Windows.h>` will pull in a lot of extra stuff, some of it simultaneously deprecated and conflicting with modern API's (e.g. the original iteration of WinSock), so we need to define `WIN32_LEAN_AND_MEAN` to exclude these problematic headers.
When using `C++`, it's good to make sure `NOMINMAX` is defined to prevent conflicts with the `min` and `max` functions from `<algorithm>`.

Unfortunately, this transitive dependency means that `<WinSock2.h>` brings in an awful lot of stuff, much of it irrelevant to networking applications.
This slows down compilation times (hence why precompiled headers are nearly ubiquitous in Win32 applications) and, worse, pollutes the namespace with a bunch of preprocessor macros.
Given that socket handles and related types frequently end up getting referenced in type definitions, this means the entire application often ends up with a transitive dependency on the Win32 API even when doing nothing more than interacting with the various higher level wrappers.
As such, one will often want to provide a separate header which declares basic types without pulling in the entire sockets library.

## Library Dependencies

Under Windows, the library or application needs to link with `ws2_32.dll`, provided by the matching import library `Ws2_32.lib`.
Despite the use of the `32` designator, the 64-bit library shares the same name.
The dependency can imported automatically with the [comment pragma](https://docs.microsoft.com/en-us/cpp/preprocessor/comment-c-cpp) in MSVC.

Under most Unix platforms, sockets are part of the standard C library and no additional dependencies are required.

## Socket Representation

Under BSD sockets, socket descriptors are normal file descriptors and share all the same properties, being small non-negative integers (generally limited to a few thousand).

Under WinSock, socket descriptors are (usually) normal NT kernel object handles.
This means, that instead of `int`, sockets need to be of type `SOCKET` and the classic
comparison with zero to detect error conditions is no longer valid.
While sockets are supposed to be interchangeable with instances of `HANDLE` in many APIs, Microsoft choose to use a different representation so casting is necessary when sockets are used with normal Win32 function calls.

Unfortunately, this dependence on `SOCKET` translates to a dependency on `<WinSock2.h>`, which we were actively trying to avoid.
We can take advantage of the fact that Microsoft guarantees a stable ABI and simply use the underlying type, `UINT_PTR`, or the more standard `uintptr_t` from `<stdint.h>`.

## Error Reporting

Under Unix, socket calls report their error status by returning `-1` and setting `errno`.
The set of errors they can report are a superset of those generated by other Unix calls and are fully enumerated as [constants](https://en.cppreference.com/w/cpp/error/errno_macros) in `<errno.h>`.

However, under Windows, `errno` is part of the compiler runtime and not a system API; therefore, WinSock is forced to use a different reporting mechanism.
As with BSD sockets, `-1` is returned on error but as a WinSock handle is not an integer, one cannot simply check the sign when examining the return values from functions like [`socket`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-socket) or [`accept`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-accept).
Instead, the program is expected to check for equality with `INVALID_SOCKET` or `SOCKET_ERROR`.
Once an error is detected, the application calls [`WSAGetLastError()`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-wsagetlasterror) to retrieve the actual error code.
Under extant versions of windows, this call is simply forwarded to the standard Win32 function [`GetLastError()`](https://docs.microsoft.com/en-us/windows/win32/api/errhandlingapi/nf-errhandlingapi-getlasterror), so the same error handling can be used for all system calls.

Complicating the situations further are the actual error values.
While the most trivial of applications may abort on the first error, most applications will need to test for at least a few "errors" that occur in normal operation, namely those associated with non-blocking operation: `EWOULDBLOCK`, `EINPROGRESS`, and `EAGAIN`.
When the application is handling signals under Unix, `EINTR` is also important although it has no equivalent in modern versions of WinSock.
Even within different varieties of Unix, there's no guarantee that `EWOULDBLOCK` and `EAGAIN` have distinct values (making them unsuitable for use in a `switch` statement).

Confusingly, the runtime provided by Visual Studio has the full set of POSIX error numbers provided in its copy of `<errno.h>` but these are disjoint from the codes actually used by WinSock.
Instead, the error codes used by WinSock are prefixed with `WSA` (e.g. `WSAEWOULDBLOCK`).
The simplest solution would be to simply `#define` aliases for [WinSock error codes](https://docs.microsoft.com/en-us/windows/win32/winsock/windows-sockets-error-codes-2) under Unix.

Care should be taken because not all error codes match up, even when they share the same name.
For example, `connect` returns `WSAEWOULDBLOCK` under Windows when connecting asynchronously but `EINPROGRESS` under Unix.
In fact, `WSAEINPROGRESS` only arises from library reentry so it should never occur in a properly written WinSock application.
As a result, it's often best to just define a function to test against the different error codes to distinguish between expected conditions and actual failures.

Alternatively, when using [`<system_error>`](https://en.cppreference.com/w/cpp/header/system_error), Microsoft's implementation of [`std::system_category`](https://en.cppreference.com/w/cpp/error/system_category) will automatically handle the translations when compared to values from [`std::errc`](https://en.cppreference.com/w/cpp/error/errc).

```c++
auto error = std::error_code(last_socket_error(), std::system_category());
if (error == std::errc::would_block) {
  // Logic
}
```

Retrieving the error string is similarly different as [`strerror`](https://en.cppreference.com/w/c/string/byte/strerror) and [`perror`](https://en.cppreference.com/w/c/io/perror) only work with the standard values from [`<errno.h>`](https://en.cppreference.com/w/cpp/error/errno_macros).
Under Windows, this action requires the use of [`FormatMessage`](https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-formatmessagea) or `std::system_category`.

## Library Initialization

Prior to use of any socket-related function, Windows requires that the socket library be initialized.
This is performed by a call to [`WSAStartup`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-wsastartup).
Unlike most functions (but similar to the `getaddrinfo` family), any error code is returned by the function so there is no need to consult `WSAGetLastError()`.
For the most part, failure is limited to improper use of the function or excessive demand on system resources.

There is a matching function [`WSACleanup`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-wsacleanup) that should be called as part of application shutdown.
Together, `WSAStartup` and `WSACleanup` implement a reference counting scheme.
After the initial initialization, each subsequent call to `WSAStartup` simply increments the counter.
Calls to `WSACleanup` will decrement the counter until the final matching call, which will destroy all sockets and unload the library.

The version provided during initialization should be `MAKEWORD(2,2)`.
This represents the newest version of the WinSock API and was introduced during the Windows 95 and NT4 era, making it available in any system one would need to support.
The only consideration is to verify that an earlier call to `WSAStartup` was not made by code targeting a deprecated version of the WinSock API.

Under Unix, no such initialization is required.

## Basic Functions

In Unix, a socket is a normal file descriptor and is closed using [`close`](https://www.freebsd.org/cgi/man.cgi?query=close&sektion=2) from `<unistd.h>`.
Under Windows, we need to use [`closesocket`](https://docs.microsoft.com/en-us/windows/win32/api/winsock/nf-winsock2-closesocket) instead.
This difference is trivially resolved by create a new function `closesocket` under Unix that aliases with `close` to use with our sockets.

Both systems provide the [`send`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-send) and [`recv`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-recv) functions, which operate identically for the most part.
The primary difference centers on types: WinSock uses `int` for the buffer size (instead of `size_t`) and expects the buffers to be of type `char` (instead of a more proper `void`).
This means that all calls to `send` and `recv` need to be cast to char.

```c
void copy_data(void *buffer, size_t buflen) {
  intptr_t bytes = recv(sock1, (char*)buffer, buflen, 0);
  send(sock2, (const char*)buffer, bytes, 0);
}
```

The practical limitation of `send` and `recv` is that they are exclusively for use with sockets.
In order to share a code path for both sockets and other descriptors (e.g. pipes), it is necessary to use the core read/write functions.
Under Unix, this would be `read` and `write` but under Windows, this would be [`ReadFile`](https://docs.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-readfile) and [`WriteFile`](https://docs.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-writefile).

It should be pointed out that it is not guaranteed under WinSock that sockets are native kernel objects (and, by extension, compatible with `ReadFile` and `WriteFile`).
Thankfully, these cases are rare with the [responsible API being deprecated](https://docs.microsoft.com/en-us/windows/win32/winsock/categorizing-layered-service-providers-and-applications), but it is something to consider as it may lead to confusing error conditions in user applications.
As a result, it is recommended that `send` and `recv` (or their extended specializations) be used exclusively.

The unorthodox use of types extends to related functions such as [`getsockopt`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-getsockopt) and [`setsockopt`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-setsockopt).
As with `send` and `recv`, Windows uses `int` to represent sizes and expects buffers to be of type `char`.

Many other function families are identical between the platforms beyond the difference in headers, such as [`accept`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-accept), [`bind`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-bind), [`listen`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-listen), [`connect`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-connect), [`getaddrinfo`](https://docs.microsoft.com/en-us/windows/win32/api/ws2tcpip/nf-ws2tcpip-getaddrinfo), [`htonl`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-htonl), [`htons`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-htons), [`inet_ntop`](https://docs.microsoft.com/en-us/windows/win32/api/ws2tcpip/nf-ws2tcpip-inet_ntop), [`inet_pton`](https://docs.microsoft.com/en-us/windows/win32/api/ws2tcpip/nf-ws2tcpip-inet_pton), and [`socket`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-socket).
In a few cases, constants have different names.
For example, under Unix, the constants for [`shutdown`](https://www.freebsd.org/cgi/man.cgi?query=shutdown&sektion=2) are named `SHUT_RD`, `SHUT_WR`, and `SHUT_RDWR` [while under Windows](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-shutdown), these are `SD_RECV`, `SD_SEND`, and `SD_BOTH`.
This can be trivially overcome by defining one set's names as aliases to the other.

[`gai_strerror`](https://docs.microsoft.com/en-us/windows/win32/api/ws2tcpip/nf-ws2tcpip-gai_strerrora) on Windows has a thread safety issue, so the use of [`FormatMessage`](https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-formatmessage) is preferred.

## Non-Blocking I/O

While non-blocking I/O operates similarly under both platforms, kicking a socket into non-blocking mode is very different.
Under Unix, this is configured by manipulating the descriptor status flags using the `F_SETFL` operation with [`fcntl`](ttps://www.freebsd.org/cgi/man.cgi?query=fcntl&sektion=2).
Alternatively, most modern platforms support the use of the `SOCK_NONBLOCK` bitflag during socket creation, either as the second parameter to [`socket`](https://www.freebsd.org/cgi/man.cgi?query=socket&sektion=2) or the fourth parameter in [`accept4`](https://www.freebsd.org/cgi/man.cgi?query=accept4&sektion=2).

As Windows has no equivalent to `fcntl`, the manipulation is made using the `FIONBIO` operation with [`ioctlsocket`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-ioctlsocket).
There is no equivalent to `F_GETFL` under Windows, so directly querying the non-blocking status is not possible.
This is not a huge loss as configuring non-blocking status is generally part of the socket creation process and not something done reactively.

## Close-On-Exec

One of the questionable design decisions shared between Windows and Unix is that descriptors are inherited by child processes by default.
In addition to causing files and sockets to remain open longer than anticipated, this can have profound consequences on Linux's `epoll` due to certain defects in its design.
Under certain conditions, a Linux process can continue to receive notifications for sockets it no longer has access to with no mechanism to cancel them.

Under Unix, the inheritance property can be partially controlled through the use of the `O_CLOEXEC` flag, manipulated using `fcntl`, or configured during socket creation with the `SOCK_CLOEXEC` flag as the second parameter to [`socket`](https://www.freebsd.org/cgi/man.cgi?query=socket&sektion=2) or the fourth parameter in [`accept4`](https://www.freebsd.org/cgi/man.cgi?query=accept4&sektion=2).
In a multi-threaded environment, this is especially critical as a race condition exists between creation of a descriptor and modification of the close-on-exec flag.
While such descriptors will be closed upon successful completion of an [`execve`](https://www.freebsd.org/cgi/man.cgi?query=execve&sektion=2) call, forked children will maintain the descriptor unless explicitly closed.

On windows, most handles are not inherited by default; however, this is not the case for sockets.
Similarly to Unix, sockets are created with the inherited bit enabled but can be disabled at creation by calling [`WSASocketW`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-wsasocketw) and supplying the `WSA_FLAG_NO_HANDLE_INHERIT` bit (Windows 7 SP1 and later); however, there is no equivalent to `accept4`.
The functionality provided by `F_SETFD` is available from [`SetHandleInformation`](https://docs.microsoft.com/en-us/windows/win32/api/handleapi/nf-handleapi-sethandleinformation).

Due to the complex interactions between threads, processes, and descriptors, many projects have simply forbidden the use of subprocesses in threaded network applications.

## Scatter/Gather (Vectored I/O)

A common programming pattern is to insert framing into a data stream.
For example, under HTTP/1.1, chunked encoding requires the addition of a length prefix and a suffix of `\r\n`.
While this can implement this as three separate calls to `send`, the sequence has pretty significant performance considerations due to its interaction with TCP packetization.
Instead, it is better to make use of a *gathered write*.

Under Unix, there are two sets of functions available for vectored I/O.
The first are the generic descriptor functions functions [`readv`](https://www.freebsd.org/cgi/man.cgi?query=readv&sektion=2) and [`writev`](https://www.freebsd.org/cgi/man.cgi?query=writev&sektion=2).
Imported from `<sys/uio.h>`, they work on descriptors of all types and use an array of type `struct iovec` to enumerate the associated buffers.
The socket-specific equivalents are [`recvmsg`](https://www.freebsd.org/cgi/man.cgi?query=recvmsg&sektion=2) and [`sendmsg`](https://www.freebsd.org/cgi/man.cgi?query=sendmsg&sektion=2).
These extend `readv` and `writev`, not just in supporting the flags argument, but by exchanging other bits of sideband information such as file descriptors in the case of Unix domain sockets.

Under Windows, the situation is more complicated.
The vectored equivalents to the generic descriptor functions, [`ReadFileScatter`](https://docs.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-readfilescatter) and [`WriteFileGather`](https://docs.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-writefilegather), are exclusive to file handles and will not function with sockets or pipes.
The functions [`WSARecvMsg`](https://docs.microsoft.com/en-us/windows/win32/api/mswsock/nc-mswsock-lpfn_wsarecvmsg) and [`WSASendMsg`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-wsasendmsg) are the most direct equivalents to `recvmsg` and `sendmsg`; however, they only work on raw (`SOCK_RAW`) and datagram (`SOCK_DGRAM`) sockets.
Further, `WSARecvMsg` is not exported by `ws2_32.dll` and needs to be retrieved using [`WSAIoctl`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-wsaioctl).

The functions [`WSARecv`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-wsarecv) and [`WSASend`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-wsasend) are intermediate in behavior between `recvmsg`/`sendmsg` and `readv`/`writev`.
The types [`WSABUF`](https://docs.microsoft.com/en-us/windows/win32/api/ws2def/ns-ws2def-wsabuf) and [`WSAMSG`](https://docs.microsoft.com/en-us/windows/desktop/api/ws2def/ns-ws2def-wsamsg) serve as the equivalents to `struct iovec` and `struct msghdr`.
Unfortunately, while Microsoft copied the conventions of `struct iovec` and `struct msghdr`, they changed the name of the members to reflect Win32 conventions.
This means we either need to write translation functions or abuse the ABI stability Windows provides and cast from custom types.

Due to this difference, it's recommended that `sendmsg` and `recvmsg` only be used when their specific functionality is required and a separate wrapper function is introduced for vectored operation on stream sockets.

## Socket Multiplexing

The classic socket multiplexing functions are [`select`](https://www.freebsd.org/cgi/man.cgi?query=select&sektion=2) and [`poll`](https://www.freebsd.org/cgi/man.cgi?query=poll&sektion=2), which are now available on all relevant platforms.

Since `select` is the inferior function, there is little point to using it (outside of some [dumb designs by Apple](https://code.saghul.net/2016/05/libuv-internals-the-osx-select2-trick/) or compatibility with old versions of Windows).
If you need to use it, the largest problem is going to be the number of descriptors that can be represented by `fd_set`.
On all platforms, this can be tuned by setting `FD_SETSIZE` *before* including the socket headers.
Due to the different nature in socket representation, the interpretation of the constant is slightly different.
On Windows, `fd_set` is implemented as an array and `FD_SETSIZE` determines the *number* of sockets that can be stored in the array (defaulting to 64).
On Unix, `fd_set` is implemented as a bitfield and `FD_SETSIZE` impacts the *highest* descriptor number that can be saved in the structure (typically defaulting to 1024).

The superior option, `poll`, is available on all currently *supported* platforms, introduced by Microsoft in Windows 8.1 under the name [`WSAPoll`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-wsapoll).
Its absence from Windows 7 may cause issues for some developers despite that system no longer being supported by Microsoft.
The only notable difference is that `WSAPoll` is very picky about the values placed in the `events` field: including `POLLHUP`, `POLLERR`, or `POLLNVAL` will cause the function to fail.
As these conditions are checked regardless, excluding them does not introduce any meaningful compatibility issue.

For applications dealing with a larger number of simultaneous connections, it is generally necessary to move onto the more modern systems, such as [epoll](https://man7.org/linux/man-pages/man7/epoll.7.html) on Linux, [kqueue](https://www.freebsd.org/cgi/man.cgi?query=kqueue&sektion=2) on BSD derivatives (including macOS), and [I/O Completion Ports](https://docs.microsoft.com/en-us/windows/win32/fileio/i-o-completion-ports) or [Registered I/O](https://docs.microsoft.com/en-us/windows/win32/api/mswsock/ns-mswsock-rio_extension_function_table) on Windows.
Commercial Unices (AIX, Solaris) have adopted the IOCP model from Windows.
Due to the complexity of these interfaces and significant differences in their conceptual models, greater levels of abstraction are required to provide source compatibility.
At this point, libraries like [libuv](https://libuv.org/) or [asio](https://think-async.com/) become attractive.

## Missing Functionality

Windows has no equivalent for the [`socketpair`](https://www.freebsd.org/cgi/man.cgi?query=socketpair&sektion=2) function.
While it can be emulated by the creation and manipulation of multiple sockets, one needs to consider its utility under Windows.
The primary purpose in Unix is provide a channel for communication with a subprocess, especially for purposes of exchanging file descriptors over a Unix domain socket.
Given the radically different paradigms regarding the creation of subprocesses and exchanging handles across process boundaries, there is little need to fully abstract this function.

In order to transmit handles to another process in Windows, the process is more akin to serialization.
The sending process will serialize a socket descriptor using [`WSADuplicateSocketW`](https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-wsaduplicatesocketw), dump the contents of `WSAPROTOCOL_INFO` on the wire, and deserialize in the receiving process by calling [`WSASocketW`](https://docs.microsoft.com/en-us/windows/desktop/api/winsock2/nf-winsock2-wsasocketw).
Other kernel objects can be transferred using the [`DuplicateHandle`](https://docs.microsoft.com/en-us/windows/win32/api/handleapi/nf-handleapi-duplicatehandle) function.
By contrast, Unix can exchange file descriptors using the ancillary data buffer in `recvmsg` and `sendmsg`.

## Example Headers

Combining all the previous information, we can produce a very basic library to provide us transparent source compatibility.
First, we declare a header that lets us stash socket handles inside structures and classes without pulling on the entire API.

```c
// socket-fwd.h
#ifndef SOCKET_FWD_H_
#define SOCKET_FWD_H_
#include <stdint.h>

// Declare Structures
struct iovec;
struct msghdr;

// Platform Specific Types
#ifndef _WIN32
typedef int socket_t;
#else
typedef uintptr_t socket_t;
// These types are missing from WinSock
typedef int socklen_t;
typedef intptr_t ssize_t;
#endif

#endif  // SOCKET_FWD_H_
```

Second, we declare a header that provides the compatibility shims between the various APIs.

```c
// socket.h
#ifndef SOCKET_H_
#define SOCKET_H_
#include "socket-fwd.h"

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <WinSock2.h>
#include <Ws2tcpip.h>
#else
#include <sys/types.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/uio.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <poll.h>
#include <unistd.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Constants
#ifndef _WIN32
#define INVALID_SOCKET (-1)
#define SOCKET_ERROR   (-1)
#else
#define SOCK_CLOEXEC   WSA_FLAG_NO_HANDLE_INHERIT
#define SOCK_NONBLOCK  (+1)  // Arbitrary Value
#define SHUT_WR        SD_SEND
#define SHUT_RD        SD_RECV
#define SHUT_RDWR      SD_BOTH
#endif

// Types
#ifdef _WIN32
// Layout compatible with WSABUF
struct iovec {
  ULONG iov_len;
  void *iov_base;
};

// Layout compatible with WSAMSG
struct msghdr {
  void         *msg_name;
  socklen_t     msg_namelen;
  struct iovec *msg_iov;
  ULONG         msg_iovlen;
  ULONG         msg_controllen;
  void         *msg_control;
  ULONG         msg_flags;
};
#endif

// External Functions
extern int socket_startup(void);
extern int socket_strerror(int error, char *buffer, size_t buflen);

// Name-Translating Wrappers
#ifndef _WIN32
inline int closesocket(socket_t sock) {
  return close(sock);
}
#endif

inline int last_socket_error(void) {
#ifdef _WIN32
  return WSAGetLastError();
#else
  return errno;
#endif
}

inline int inprogress(int error) {
#ifdef _WIN32
  return (error == WSAEWOULDBLOCK);
#else
  return (error == EWOULDBLOCK) || (error == EAGAIN)
      || (error == EINPROGRESS);
#endif
}

inline int get_cloexec(socket_t sock) {
#ifndef _WIN32
  return fcntl(sock, F_GETFD);
#else
  DWORD flags = 0;
  return GetHandleInformation((HANDLE)sock, & flags)
      ? (flags & HANDLE_FLAG_INHERIT) : -1;
#endif
}

inline int set_cloexec(socket_t sock, int value) {
#ifndef _WIN32
  return fcntl(sock, F_SETFD, value ? FD_CLOEXEC : 0);
#else
  return SetHandleInformation((HANDLE)sock, HANDLE_FLAG_INHERIT,
                              value ? HANDLE_FLAG_INHERIT : 0) ? 0 : -1;
#endif
}

#ifndef _WIN32
inline int set_nonblock(socket_t sock, int value) {
  int oflags = fcntl(sock, F_GETFL);
  if (oflags < 0) return oflags;
  int nflags = value ? (oflags | O_NONBLOCK) : (oflags & ~O_NONBLOCK);
  return (oflags != nflags) ? fcntl(sock, F_SETFL, nflags) : 0;
}
#else
inline int set_nonblock(socket_t sock, u_long value) {
  return ioctlsocket(sock, FIONBIO, &value);
}
#endif

inline socket_t socket4(int domain, int type, int protocol, int flags) {
#ifndef _WIN32
  return socket(domain, type | flags, protocol);
#else
  // Create socket
  socket_t sock = WSASocketW(domain, type, protocol, NULL, 0,
      WSA_FLAG_OVERLAPPED | (flags & SOCK_CLOEXEC));
  if (sock == INVALID_SOCKET) return sock;
  // Apply remaining flags
  u_long arg = 1;
  if (flags & SOCK_NONBLOCK) ioctlsocket(sock, FIONBIO, &arg);
  return sock;
#endif
}

inline int socket_cleanup(void) {
#ifdef _WIN32
  return WSACleanup();
#else
  return 0;
#endif
}

#ifdef _WIN32
inline int poll(struct pollfd *fds, int nfds, int timeout) {
  return WSAPoll(fds, nfds, timeout);
}

inline ssize_t recvmsg(socket_t sock, struct msghdr *msg, DWORD flags) {
  // NOTE: This does not implement the ancillary data feature
  DWORD bytes = 0;
  int result = WSARecvFrom(sock, (WSABUF*)msg->msg_iov, msg->msg_iovlen,
                           &bytes, &flags, (struct sockaddr*)msg->msg_name,
                           &msg->msg_namelen, NULL, NULL);
  if (result == SOCKET_ERROR) return -1;
  msg->msg_flags = flags;
  msg->msg_controllen = 0;
  return (ssize_t)bytes;
}

inline ssize_t sendmsg(socket_t sock, const struct msghdr *msg, DWORD flags) {
  // NOTE: This does not implement the ancillary data feature
  DWORD bytes = 0;
  int result = WSASendTo(sock, (WSABUF*)msg->msg_iov, msg->msg_iovlen,
                         &bytes, flags, (const struct sockaddr*)msg->msg_name,
                         msg->msg_namelen, NULL, NULL);
  if (result == SOCKET_ERROR) return -1;
  return (ssize_t)bytes;
}
#endif

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // SOCKET_H_
```

Finally, we create a file that addresses the more involved functions and forces instantiation of the inline functions.

```c
// socket.c
#include "socket.h"
#include <stdio.h>
#include <string.h>

#ifdef _WIN32
#pragma comment(lib, "Ws2_32.lib")
#endif

int socket_startup() {
#ifdef _WIN32
  WSADATA wsadata;
  int error = WSAStartup(MAKEWORD(2, 2), &wsadata);
  if (error) return error;

  if (wsadata.wVersion < MAKEWORD(2, 2)) {
    WSACleanup();
    return WSAVERNOTSUPPORTED;
  }
#endif

  return 0;
}

int socket_strerror(int error, char *buffer, size_t buflen) {
#if _WIN32
  DWORD length = FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM, NULL,
                                error, 0, buffer, buflen, NULL);
  if (length == 0) return -1;
  char *eol = strchr(buffer, '\n');
  if (eol != NULL) *eol = '\0';
  return 0;
#else
  // Can be replaced with strlcpy if known to be available
  snprintf(buffer, buflen, "%s", strerror(error));
  return 0;
#endif
}

// Instantiate Inline Functions.
int inprogress(int error);
int last_socket_error(void);
int get_cloexec(socket_t sock);
int set_cloexec(socket_t sock, int value);
int socket_cleanup(void);
socket_t socket4(int domain, int type, int protocol, int flags);
#ifndef _WIN32
int closesocket(int sock);
int get_nonblock(socket_t sock);
int set_nonblock(socket_t sock, int value);
#else
int poll(struct pollfd *fds, int nfds, int timeout);
int set_nonblock(socket_t sock, u_long value);
ssize_t recvmsg(socket_t sock, struct msghdr *msg, DWORD flags);
ssize_t sendmsg(socket_t sock, const struct msghdr *msg, DWORD flags);
#endif
```

### Example Program

Using this library, we can construct a basic application that doesn't need to perform any platform-specific checks in order to make use of the sockets library.
Here, we only perform a check on `_WIN32` for purposes of outputing a diagnostic message regarding the current platform.

```c
// example.c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "socket.h"

static const char prefix[] =
    "GET / HTTP/1.1\r\n"
    "Host: ";
static const char suffix[] = "\r\n"
    "Connection: close\r\n"
    "\r\n";

int main(int argc, char **argv) {
  int init = 0;
  socket_t sock = INVALID_SOCKET;
  struct addrinfo *addr = NULL;
  const char *func = "unknown";
  const char *hostname = (argc > 1) ? argv[1] : "google.com";
  const char *servname = (argc > 2) ? argv[2] : "www";

  printf("Running on ");
#ifdef _WIN32
  printf("Windows %zd-Bit\n", sizeof(void*) * 8);
#else
  fflush(stdout);
  system("uname -o");
#endif

  int error = socket_startup();
  if (error) {
    func = "socket_startup";
    goto haveerror;
  }
  ++init;

  printf("Looking up %s:%s\n", hostname, servname);
  struct addrinfo hints = {};
  hints.ai_socktype = SOCK_STREAM;
  error = getaddrinfo(hostname, servname, &hints, &addr);
  if (error) {
    fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(error));
    return EXIT_FAILURE;
  }

  printf("Creating socket.\n");
  sock = socket4(addr->ai_family, addr->ai_socktype, addr->ai_protocol,
                 SOCK_CLOEXEC | SOCK_NONBLOCK);
  if (sock == INVALID_SOCKET) {
    func = "socket";
    goto fail;
  }

  printf("Connecting to %s:%s.\n", hostname, servname);
  error = connect(sock, addr->ai_addr, addr->ai_addrlen);
  if ((error == SOCKET_ERROR) && !inprogress(last_socket_error())) {
    func = "connect";
    goto fail;
  }

  printf("Waiting for connection.\n");
  struct pollfd fds;
  fds.fd = sock;
  fds.events = POLLWRNORM;
  if (poll(&fds, 1, -1) == SOCKET_ERROR) {
    func = "poll";
    goto fail;
  }

  struct iovec iov[3];
  iov[0].iov_base = (char*)prefix;
  iov[0].iov_len = strlen(prefix);
  iov[1].iov_base = (char*)hostname;
  iov[1].iov_len = strlen(hostname);
  iov[2].iov_base = (char*)suffix;
  iov[2].iov_len = strlen(suffix);
  struct msghdr hdr = {};
  hdr.msg_iov = iov;
  hdr.msg_iovlen = 3;

  printf("Sending request to %s:%s.\n", hostname, servname);
  ssize_t bytes = sendmsg(sock, &hdr, 0);
  if (bytes == SOCKET_ERROR) {
    func = "sendmsg";
    goto fail;
  }
  printf("Sent %zd bytes.\n", bytes);

  if (shutdown(sock, SHUT_WR) == SOCKET_ERROR) {
    func = "shutdown";
    goto fail;
  }

  char buffer[4096];
  iov[0].iov_base = buffer;
  iov[1].iov_len = sizeof(buffer);
  hdr.msg_iovlen = 1;
  printf("Receiving response from %s:%s.\n", hostname, servname);
  size_t total = 0;
  while ((bytes = recvmsg(sock, &hdr, 0)) != 0) {
    if (bytes == SOCKET_ERROR) {
      if (!inprogress(last_socket_error())) {
        func = "recvmsg";
        goto fail;
      } else {
        fds.events = POLLRDNORM;
        if (poll(&fds, 1, -1) == SOCKET_ERROR) {
          func = "poll";
          goto fail;
        }
      }
    } else {
      fwrite(buffer, 1, bytes, stdout);
      total += bytes;
    }
  }

  printf("Received %zu bytes from %s:%s.\n", total, hostname, servname);
  freeaddrinfo(addr);
  closesocket(sock);
  socket_cleanup();
  return EXIT_SUCCESS;

fail:
  error = last_socket_error();
haveerror:
  socket_strerror(error, buffer, sizeof(buffer));
  fprintf(stderr, "%s: %s\n", func, buffer);

  if (addr != NULL) {
    freeaddrinfo(addr);
  }
  if (sock != INVALID_SOCKET) {
    closesocket(sock);
  }
  if (init) {
    socket_cleanup();
  }
  return EXIT_FAILURE;
}
```

### Unix Results

```
Running on FreeBSD
Looking up google.com:www
Creating socket.
Connecting to google.com:www.
Waiting for connection.
Sending request to google.com:www.
Sent 55 bytes.
Receiving response from google.com:www.
HTTP/1.1 301 Moved Permanently
Location: http://www.google.com/
Content-Type: text/html; charset=UTF-8
Date: Wed, 13 Jan 2021 08:29:45 GMT
Expires: Fri, 12 Feb 2021 08:29:45 GMT
Cache-Control: public, max-age=2592000
Server: gws
Content-Length: 219
X-XSS-Protection: 0
X-Frame-Options: SAMEORIGIN
Connection: close

<HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
<TITLE>301 Moved</TITLE></HEAD><BODY>
<H1>301 Moved</H1>
The document has moved
<A HREF="http://www.google.com/">here</A>.
</BODY></HTML>
Received 547 bytes from google.com:www.
```

```plain
Running on GNU/Linux
Looking up google.com:www
Creating socket.
Connecting to google.com:www.
Waiting for connection.
Sending request to google.com:www.
Sent 55 bytes.
Receiving response from google.com:www.
HTTP/1.1 301 Moved Permanently
Location: http://www.google.com/
Content-Type: text/html; charset=UTF-8
Date: Wed, 13 Jan 2021 07:48:24 GMT
Expires: Fri, 12 Feb 2021 07:48:24 GMT
Cache-Control: public, max-age=2592000
Server: gws
Content-Length: 219
X-XSS-Protection: 0
X-Frame-Options: SAMEORIGIN
Connection: close

<HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
<TITLE>301 Moved</TITLE></HEAD><BODY>
<H1>301 Moved</H1>
The document has moved
<A HREF="http://www.google.com/">here</A>.
</BODY></HTML>
Received 547 bytes from google.com:www.
```

### Windows Results

```plain
Running on Windows 32-Bit
Looking up google.com:www
Creating socket.
Connecting to google.com:www.
Waiting for connection.
Sending request to google.com:www.
Sent 55 bytes.
Receiving response from google.com:www.
HTTP/1.1 301 Moved Permanently
Location: http://www.google.com/
Content-Type: text/html; charset=UTF-8
Date: Wed, 13 Jan 2021 08:01:05 GMT
Expires: Fri, 12 Feb 2021 08:01:05 GMT
Cache-Control: public, max-age=2592000
Server: gws
Content-Length: 219
X-XSS-Protection: 0
X-Frame-Options: SAMEORIGIN
Connection: close

<HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
<TITLE>301 Moved</TITLE></HEAD><BODY>
<H1>301 Moved</H1>
The document has moved
<A HREF="http://www.google.com/">here</A>.
</BODY></HTML>
Received 547 bytes from google.com:www.
```

```plain
Running on Windows 64-Bit
Looking up google.com:www
Creating socket.
Waiting for connection.
Connecting to google.com:www.
Sending request to google.com:www.
Sent 55 bytes.
Receiving response from google.com:www.
HTTP/1.1 301 Moved Permanently
Location: http://www.google.com/
Content-Type: text/html; charset=UTF-8
Date: Wed, 13 Jan 2021 07:59:30 GMT
Expires: Fri, 12 Feb 2021 07:59:30 GMT
Cache-Control: public, max-age=2592000
Server: gws
Content-Length: 219
X-XSS-Protection: 0
X-Frame-Options: SAMEORIGIN
Connection: close

<HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
<TITLE>301 Moved</TITLE></HEAD><BODY>
<H1>301 Moved</H1>
The document has moved
<A HREF="http://www.google.com/">here</A>.
</BODY></HTML>
Received 547 bytes from google.com:www.
```
