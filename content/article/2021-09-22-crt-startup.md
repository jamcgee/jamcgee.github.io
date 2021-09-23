---
date: 2021-09-22T13:45:00-0700
title: C/C++ Runtime Startup
slug: crt-startup
tags:
  - C
  - C++
  - ELF
  - embedded
  - firmware
  - freestanding
  - programming
---

When writing a freestanding application, it's generally necessary for the firmware engineer to handle runtime initialization.
Even when a library like newlib includes a rudimentary implementation of `crt0.o`, initialization is a very application-specific process owing to the need to initialize hardware, memory, and other loading tasks.

In this essay, we examine the current and historical implementation of executable initialization, finishing with a minimal implementation usable with firmware applications.

> **Note:** Most firmware applications need to address the initialization of `.data` and `.bss` from nonvolatile memory.
> That is not addressed in this essay.

<!--more-->

## Program Entry Point

Files: `crt0.o` (number often indicates ABI version)<br>
Symbols: `_start`

In the classic Unix model, program execution begins at the executable entry point, which is the symbol `_start` in the GCC toolchain.
Its basic purpose is to extract the runtime information from the system, initialize the program data structures, call `main`, and terminate the program when `main` returns.

The [original Unix startup code](https://github.com/dspinellis/unix-history-repo/blob/Research-Release/usr/src/libc/csu/crt0.s) was quite simple.
It extracts `argc`, `argv`, and `environ` from the stack; stores the stack in `environ`; calls `main`; and finally executes `exit` to terminate the process.
We could summarize it like this:

```c
void start(int argc, ...) {
    // Extract parameters from stack
    char **argv = &argc + 1;
    char **envp = &argc + 2 + argc;

    // Save block environment pointer
    environ = envp;

    // Invoke user entry point
    exit(main(argc, argv, envp));
    syscall(1);
}
```

After the image is loaded, the kernel would store the arguments on the stack, set the initial instruction pointer to `start` and let it run.
The only automatic cleanup on the part of the runtime is provided by stdio, which we can see within [exit](https://github.com/dspinellis/unix-history-repo/blob/Research-Release/usr/src/libc/gen/cuexit.s) and [_cleanup](https://github.com/dspinellis/unix-history-repo/blob/Research-Release/usr/src/libc/stdio/flsbuf.c), where it will close all open files and flush their buffers.

The requirements for initialization and cleanup increased over time.
Once we get to System V, we start to see additional features:

```c
void _start(int argc, ...) {
    // Extract parameters from stack
    char **argv = &argc + 1;
    char **envp = &argc + 2 + argc;

    // Save block environment pointer
    environ = envp;

    // Initialize global state
    atexit(_cleanup);
    _init();

    // Invoke user code
    exit(main(argc, argv, envp));
}
```

With the addition of dynamic linking and additional requirements from languages like C++, things get a little more complicated.
Since Linux (or, more accurately, [glibc](https://github.com/bminor/glibc/blob/master/csu/libc-start.c)) makes things complicated, let's look at the [amd64 startup code from FreeBSD](https://github.com/freebsd/freebsd-src/blob/master/lib/csu/amd64/crt1_c.c) (commentary added by author):

```c
/* The entry function. */
void
_start(char **ap, void (*cleanup)(void))
{
    int argc;
    char **argv;
    char **env;

    // Extract program arguments
    argc = *(long *)(void *)ap;
    argv = ap + 1;
    env = ap + 2 + argc;

    // Set environ and initialize getprogname()
    handle_argv(argc, argv, env);

    // Perform relocations if necessary
    if (&_DYNAMIC != NULL) {
        atexit(cleanup);
    } else {
        process_irelocs();
        _init_tls();
    }

    // Call _init() and .init_array (unless rtld already handled)
    handle_static_init(argc, argv, env);

    // Enter user code
    exit(main(argc, argv, env));
}
```

`_DYNAMIC` is a symbol provided by the dynamic linker.
If set, the program has been dynamically linked and all the complicated stuff has already been handled for us by the runtime linker.
In this case, we need only register its termination function (since it can't talk to libc itself) and make our call to `main`.

If this symbol is `NULL` (i.e. not bound), we are statically linked and have to handle some of the things the dynamic linker normally handles for us, such as program relocations (e.g. position-independent executable), TLS (thread-local storage), and global initialization.

> **Note:** The symbol `_start` is only for the benefit of the software developer.
> From the standpoint of the runtime loader, execution will begin either at a predetermined location (e.g. firmware) or a location specified in the executable header (e.g. a.out, COFF, ELF, etc.).

## Program Initialization

Files: `crti.o`, `crtn.o`, `crtbegin.o`, `crtend.o`

Things like global C++ constructors, or just the objects in `<stdio.h>`, need to be executed before the call to `main`.
How this has handled has changed over the years.

From the Unix perspective, the initialization functions `_init` and `_fini` were introduced around the time SysV and BSD4 roled around.
The entry point `_start` would register `_fini` with `atexit` and call `init` before calling `main`.

From the GCC perspective, they had to introduce a platform-independent scheme for C++ initialization.
For this, they [introduced the `.ctors` and `.dtors` sections](https://gcc.gnu.org/onlinedocs/gccint/Initialization.html).
To schedule their execution they either injected a callback into either the platform's initialization scheme (when available) or instrumented the `main` function during compilation.

Finally, ELF produced a standard data structure for all initialization purposes.
As part of the standard file format, it is visible to the runtime linker, allowing the linker to orchestrate the initialization process.

> **Note:** In a modern binary, the legacy functions (`_init`, `_fini`) and arrays (`.ctors`, `.dtors`) are generally empty.
> In a firmware application, it's generally safe to discard support for these constructs and use the ELF mechanism exclusively.

### Initialization Functions

Files: `crti.o`, `crtn.o`<br>
Sections: `.init`, `.fini`<br>
Symbols: `_init`, `_fini`

The earliest Unix initialization model was based on the functions `_init` and `_fini`.
Prior to execution of `main`, the startup function would register `_fini` for execution at program exit (using [`atext`](https://en.cppreference.com/w/c/program/atexit)) before calling `_init`.
`_fini` is registered first in case of a call to `exit` in the middle of `_init`.

These two functions are assembled by the linker from three parts: the function prologues (from `crti.o`), the function body from the linked objects, and the function epilogues (from `crtn.o`).
This construction is what leads to their position at the "bookends" of the linker command line.

As this code generation is architecture and ABI-specific, we have to pick a concrete example, such as the amd64 platform from FreeBSD.
As described, [`crti.o`](https://github.com/freebsd/freebsd-src/blob/master/lib/csu/amd64/crti.S) contains the function prologues:

```gas
        .section .init,"ax",@progbits
        .align	4
        .globl	_init
        .type	_init,@function
_init:
        subq	$8,%rsp

        .section .fini,"ax",@progbits
        .align	4
        .globl	_fini
        .type	_fini,@function
_fini:
        subq	$8,%rsp
```

In this case, there's no more than simply reserving the stack frame, a copy for each of the two functions with its own section.

And at the other end of the functions, we have the matching epilogue, from [`crtn.o`](https://github.com/freebsd/freebsd-src/blob/master/lib/csu/amd64/crtn.S), which simply cleans the stack frame and returns.

```gas
        .section .init,"ax",@progbits
        addq	$8,%rsp
        ret

        .section .fini,"ax",@progbits
        addq	$8,%rsp
        ret
```

And looking at a real executable, in this case `/bin/ls`:

```
Disassembly of section .init:

000000000020805c <.init>:
  20805c:       48 83 ec 08             sub    $0x8,%rsp
  208060:       e8 cb ff ff ff          callq  208030
  208065:       48 83 c4 08             add    $0x8,%rsp
  208069:       c3                      retq
```

We can see the sandwich of prologue from `crti.o` (`0x20805c`), the initialization code from a module (`0x208060`), and the epilogue from `crtn.o` (`0x208065`).
In practice, use of this function has been largely replaced by the ELF initialization tables, so it's often empty.
The function at `0x208030` is actually `__do_global_ctors_aux` from `crtend.o`, another deprecated initialization framework.

> **Note:** Modern compliers will not generate code for this section under normal conditions.
> For most embedded applications, it's safe to eliminate this mechanism entirely.

It should be noted that there is no exported symbol bound to `.init` or `.fini`.
The names `_init` and `_fini` are simply for the benefit of the entry code.
As with `_start` itself, the runtime linker simply uses the information stored in the ELF headers.
In this case, the linker will simply call into `.init` or `.fini` directly under the assumption that the initialization function begins with the first instruction.

> **Note:** On machines with multiple instruction sets, namely 32-Bit ARM, there is no mechanism to communicate to the runtime linker which instruction set is in use for `.init` and `.fini` as this is handled by the LSB in the symbol address.
> This means the functions must be written in the processor's primary instruction set, even if the rest of the application has been compiled in an alternate ISA.

### ELF Initialization Sections

ELF defines the sections `.init_array`, `.fini_array`, and `.preinit_array` for initialization purposes.
The section `.init_array` handles all normal initialization tasks, including C++ global objects.
It is automatically populated by the compiler when constructing global objects or marking a function with the [`constructor`](https://gcc.gnu.org/onlinedocs/gcc/Common-Function-Attributes.html#index-constructor-function-attribute) attribute in GCC.

The section `.fini_array` is rarely used (C++ destructors are handled separately), but can be used to register callbacks for execution on *normal* process termination.
Programmatically, it can be accessed using the [`destructor`](https://gcc.gnu.org/onlinedocs/gcc/Common-Function-Attributes.html#index-destructor-function-attribute) attribute in GCC.

Finally, `.preinit_array` gives the *executable* a chance to run initialization takes prior to the initialization of shared objects.
It's rarely used in practice and needs to be accessed through use of explicit section placement.
For example:

```c
// The actual name of this function is irrelevant
static void preinit_func(void) {
  // Perform pre-initialization task here
}

// The actual name of this variable is irrelevant
__attribute__((used, section(".preinit_array")))
static void (*preinit_array)(void) = preinit_func;
```

To facilitate access to these sections from inside the executable, it's common for the linker to define a set of symbols to bookend the data.
A standard linker script would look like this:

```
SECTIONS {
    .preinit_array : {
        HIDDEN (__preinit_array_start = .);
        KEEP (*(.preinit_array))
        HIDDEN (__preinit_array_end = .);
    }
    .init_array : {
        HIDDEN (__init_array_start = .);
        KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*)))
        KEEP (*(.init_array))
        HIDDEN (__init_array_end = .);
    }
    .fini_array : {
        HIDDEN (__fini_array_start = .);
        KEEP (*(SORT_BY_INIT_PRIORITY(.fini_array.*)))
        KEEP (*(.fini_array))
        HIDDEN (__fini_array_end = .);
    }
}
```

The use of `HIDDEN` is to facilitate the presence of shared objects.
Each object linked into the memory space will carry its own initialization tables.
The symbols are only required when an object is initializing itself as the runtime linker will find the tables using the section definition in the ELF headers.

We can see the associated [initialization code from FreeBSD](https://github.com/freebsd/freebsd-src/blob/master/lib/csu/common/ignore_init.c):

```c
static inline void
handle_static_init(int argc, char **argv, char **env)
{
    void (*fn)(int, char **, char **);
    size_t array_size, n;

    if (&_DYNAMIC != NULL)
        return;

    atexit(finalizer);

    array_size = __preinit_array_end - __preinit_array_start;
    for (n = 0; n < array_size; n++) {
        fn = __preinit_array_start[n];
        if ((uintptr_t)fn != 0 && (uintptr_t)fn != 1)
            fn(argc, argv, env);
    }
    _init();
    array_size = __init_array_end - __init_array_start;
    for (n = 0; n < array_size; n++) {
        fn = __init_array_start[n];
        if ((uintptr_t)fn != 0 && (uintptr_t)fn != 1)
            fn(argc, argv, env);
  }
}
```

There are four observations:

- If we have been dynamically linked (i.e. `_DYNAMIC` is bound), we skip the initialization entirely.
  It has been handled for us by the dynamic linker.
- The finalizer is registered prior to executing the initializers.
  This is to provide reliable execution of the finalizers even if someone calls `exit` in the middle of the initialization process.
  This does mean that your finalizer cannot assume your initializer has been called.
- The function pointers are compared to sentinel values prior to execution.
  This is for compatibility with the legacy GNU C++ initializer lists.
  Compilers will not generate these values so this guard is not required in normal situations.
- The same arguments as `main` (i.e. `argc`, `argv`, `env`) are passed to the initializer functions.
  This is a platform ABI extension, allowing a library to customize its behavior or enable debugging features based on environment variables, for example.
  Initializer functions cannot normally assume any arguments.

The global finalizer is found in the same file and simply iterates through it `.fini_array` *in reverse*.
Since the `.init_array` and `.fini_array` will be constructed in the order the objects are linked, they will have a similar order.
By reversing the direction of finalization, we can ensure the lifetimes of global objects are properly nested.

```c
static void
finalizer(void)
{
    void (*fn)(void);
    size_t array_size, n;

    array_size = __fini_array_end - __fini_array_start;
    for (n = array_size; n > 0; n--) {
        fn = __fini_array_start[n - 1];
        if ((uintptr_t)fn != 0 && (uintptr_t)fn != 1)
            (fn)();
    }
    _fini();
}
```

> **Note:** These arrays are typically generated as *mutable* and many linker script will place them with `.data`.
> This is for the benefit of position-independent code, which would require fixups when loaded into the target memory space.
> In firmware or other fixed-position applications, it's safe to store these sections in `.rodata`.

## C++ ABI Extensions

Files: [`crtbegin.o`](https://github.com/freebsd/freebsd-src/blob/main/lib/csu/common/crtbegin.c), [`crtend.o`](https://github.com/freebsd/freebsd-src/blob/main/lib/csu/common/crtend.c)

While mostly compatible with C, C++ throws a few wrinkles into the initialization process.
The first, global constructors, has been dealt with with the same platform-specific mechanisms available for C.

### Destruction

The second consideration is global *destructors*.
The native solution is to register them with `.fini_array`, but this has a subtle failure condition: a destructor should only be called once the object has been *successfully* initialized.
If the program is terminated mid-initialization, we can only destruct those objects that have completed their constructor.
The global finalizer, by contrast, runs through *everything* in `_fini` or `.fini_array`.

The official solution called out by the [Itanium C++ ABI](https://itanium-cxx-abi.github.io/cxx-abi/abi.html#dso-dtor-runtime-api) (which, despite its name, is used by almost everyone) is to register each object with the `atexit` framework once the constructor completes.
More specifically, a function `__cxa_atexit` is provided by the runtime with three arguments:

1. The termination callback, normally the class destructor.
2. An opaque pointer, which is generally the `this` pointer for use by the destructor.
3. A pointer within the memory space of the object that constructed the object.

Point (3) requires more explanation.
When a shared object is loaded, it may have its own global objects to be initialized.
When it's *unloaded*, the memory containing the objects and related functions is released, so we need to execute the associated finalizers or it will leave a bunch of dangling pointers.
The object will load the appropriate pointer from `__dso_handle` when calling `__cxa_atexit`.
This is typically defined in `crtbegin.o` and generally just points to itself.
For example, [from FreeBSD](https://github.com/freebsd/freebsd-src/blob/release/13.0.0/lib/csu/common/crtbegin.c#L35):

```c
#ifndef SHARED
void *__dso_handle = 0;
#else
void *__dso_handle = &__dso_handle;
#endif
```

Before the shared object is unloaded, the runtime linker will call `__cxa_finalize` with that binary's value of `__dso_handle`.
This allows the runtime to identify those finalizers to execute.
When tearing down the process itself, the value `NULL` is used, signalling that *all* remaining finalizers are to be executed.

> **Note:** As with the initialization structures, this is typically a *mutable* variable.
> As an *absolute* pointer, it is subject to relocation fixups and would dirty a text page if stored in `.rodata`.
> For static executables (e.g. firmware), it's safe to make this a `.rodata` pointer to `NULL`.
> It's still required since compiled C++ code will try to access it when invoking their global constructors but may be eliminated by LTO.

> **Note:** ARM defines a related function in their ABI, `__aeabi_atexit`, which is functionally equivalent to `__cxa_atexit` but swaps the order of arguments (1) and (2).
> This is to provide a code size reduction by leaving the object pointer in the register `this` would normally reside.

### Legacy G++ Initialization

Prior to the availability of ELF, G++ implemented its own initialization scheme using `crtbegin.o` and `crtend.o`.
In this case, the sections `.ctors` and `.dtors` are bookended in much the same way `_init` and `_fini` are constructed using `crti.o` and `crtn.o`.

Being an array of function pointers, they are compatible with the more modern `.init_array` and `.fini_array`.
As such, most modern linker scripts will remap their contents into those sections and leave the G++ lists empty.
The actual bookend objects need to be left out since they contain sentinel values instead of valid pointers, unless checks are included such as the FreeBSD code above.

```
SECTIONS {
    .init_array : {
        PROVIDE_HIDDEN (__init_array_start = .);
        KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))
        KEEP (*(.init_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .ctors))
        PROVIDE_HIDDEN (__init_array_end = .);
    }
    .fini_array : {
        PROVIDE_HIDDEN (__fini_array_start = .);
        KEEP (*(SORT_BY_INIT_PRIORITY(.fini_array.*) SORT_BY_INIT_PRIORITY(.dtors.*)))
        KEEP (*(.fini_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .dtors))
        PROVIDE_HIDDEN (__fini_array_end = .);
    }
}
```

In practice, these data structures will not be used by any modern complier targeting ARM.
Unless you're an OS developer trying to maintain a long tail of backwards ABI compatibility or using an archaic executable format, it's acceptable to leave them out.

## Implementation in Newlib

In the embedded space, newlib is the most commonly seen C Library for all its warts.
Its implementation of these functions is divided between `libc` and `libgloss`.

As the startup code is often written in assembly, newlib provides the functions [`__libc_init_array`](https://github.com/bminor/newlib/blob/master/newlib/libc/misc/init.c) and [`__libc_fini_array`](https://github.com/bminor/newlib/blob/master/newlib/libc/misc/fini.c) to run through the ELF initializers.
Unlike the FreeBSD example, no allowances are made for dynamic linking and `__libc_init_array` will not register the global destructor with `atexit`.
If either are required for your application, you need to address it yourself.

The C++ finalizer implementation, `__cxa_atexit` is [integrated with `atexit`](https://github.com/bminor/newlib/blob/master/newlib/libc/stdlib/__atexit.c) as is the case with most modern systems.
It tries to play tricks with weak symbols to prevent normal C++ code from pulling in the framework unless it's explicitly referenced using `atexit`.
In practice, I've found this to be rather unsuccessful.

It is suggested you provide your own stubs unless you require proper termination handling:

```c
int __cxa_atexit(void (*f)(void*), void *a, void *d) {
    (void)f;
    (void)a;
    (void)d;
    return 0;
}

#ifdef __ARM_EABI__
// Could probably alias to __cxa_exit to save a few bytes.
int __aeabi_atexit(void *a, void (*f)(void*), void *d) {
    (void)f;
    (void)a;
    (void)d;
    return 0;
}
#endif
```

> **Note:** LLVM's LTO can properly analyze these functions.
> It has been observed pruning destructors entirely during dead code elimination.
> The casts to `void` are to silence warnings about unused arguments.

The symbol `__dso_handle`, is provided by GCC's own `crtbegin.o`.
Newlib does not provide its own implementation of the C++ bookends.

## Freestanding Implementation

For people who like to do everything themselves (*cough*).

```c
#include <stddef.h>

typedef void (*init_func)(void);
extern init_func __preinit_array_start[];
extern init_func __preinit_array_end[];
extern init_func __init_array_start[];
extern init_func __init_array_end[];
extern void main();

// If not using GCC's crtbegin.o
void * const __dso_handle = NULL;

void _start(void) {
    // If not generating your own pre-initialization callbacks,
    // this code can be removed.
    size_t cnt = __preinit_array_end - __preinit_array_start;
    for (size_t n = 0; n < cnt; ++n) {
        __preinit_array_start[n]();
    }

    // If not using global C++ objects and there are no constructor functions,
    // this code can be removed.
    cnt = __init_array_end - __init_array_start;
    for (size_t n = 0; n < cnt; ++n) {
        __init_array_start[n]();
    }

    // In a typical firmware application, there are no arguments to provide
    // to main. Under U-Boot, we receive the arguments given to bootelf.
    // Under Angel semihosting, we can query the host for a set of arguments.
    // When sharing code with hosted systems, it may make sense to provide a
    // constant set of arguments.  Otherwise, we can just call main as a
    // void-argument function.
    main();
  
    // Depending on the application, we may wish to return to the bootloader,
    // reset the processor, notify the semihosting system, or any
    // other number of things.  Here, we just stick an empty loop to catch
    // any return from main().
    for (;;) {}
}

int __cxa_atexit(void (*f)(void*), void *a, void *d) {
    (void)f;
    (void)a;
    (void)d;
    return 0;
}

#ifdef __ARM_EABI__
int __aeabi_atexit(void *a, void (*f)(void*), void *d) {
    (void)f;
    (void)a;
    (void)d;
    return 0;
}
#endif
```

Here, we eliminate all initialization tasks not required by a firmware application.
Since most embedded applications don't have a concept of normal termination, we can also eliminate all cleanup code.
