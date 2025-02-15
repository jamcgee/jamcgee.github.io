---
date: 2020-12-30T17:30:00-08:00
title: Inline Functions in C and C++
slug: inline-functions-c-cpp
tags:
  - C
  - C++
  - ELF
  - inline
  - programming
---

Inline functions are a notable feature of both C and C++.
By exposing the source file to the implementation of a function, they allow a variety of optimization techniques that wouldn't be possible if it had to call out to a subroutine in a different file (at least without link-time optimization).

However, despite the common syntax, the C and C++ languages implement them in very different ways.
While C++ takes a "user friendly" approach and automatically manages the manipulation of multiple implementations, C requires a more manual approach.
As a result, inline functions are less common in C and mixed language code, generally using the nuclear option of declaring them `static`.

```c
/* test.h */
inline int test1(void) {
  return 12;
}

/* test.c or test.cpp */
int test2(void) {
  return test1();
}
```

Sometimes, the easiest way to understand a rule is to see it in action.
Let's analyze how modern compilers deal with C and C++ inline functions in different situations.

## Inline Functions in C

C99 introduced inline functions to the language and it has the simplest implementation.
It's best to think of an inline function not as being the actual implementation, but alternate implementation the compiler may *choose* to use.

When compiled under C, our example program produces the following assembly output (stripped of anything related to debugging):

```gas
        .text

# inline int test1(void)

# int test2(void)
        .globl  test2
test2:
        call    test1@PLT
        ret
```

Our inline function is *gone*.
As described by C99, the `inline` keyword by itself does not result in the actual generation of a function.
If we tried to link this object, we would face an unresolved symbol error unless the function was exported by another translation unit.
Only should the compiler choose to inline the function will the function exist and it only exists within that translation unit.

If we want the compiler to generate the code for the function, we need to use `extern inline` (or remove the `inline` keyword entirely).

```gas
        .text

# extern inline int test1(void)
        .globl  test1
test1:
        movl    $12, %eax
        ret

# int test2(void)
        .globl  test2
test2:
        call    test1
        ret
```

Under `extern inline`, it behaves like a completely normal function.
The `inline` keyword merely serves as an optimization hint and has no impact on the implementation of the function.
In fact, it's often completely *ignored* while the optimizer makes its own decisions.

However, by virtue of being a normal function, it means that should multiple source files try to implement the function, the linker will generate duplicate symbol errors.
Unlike C++, C99 requires the programmer to ensure only a single copy is realized.

The opposite linkage specifier from `extern` is `static` and it, too, can be used with `inline`.

```gas
        .text

# static inline int test1(void)
test1:
        movl    $12, %eax
        ret

# int test2(void)
        .globl  test2
test2:
        call    test1
        ret
```

The output is very similar to that of `extern inline` with the notable difference being the lack of a `.globl` for the function symbol.
This means that even though the function implementation exists, it won't be visible outside this object file.

In a way, `static inline` acts like an intermediate step between `inline` and `extern inline`.
Like `extern inline`, it doesn't require an external implementation and like `inline`, it won't interfere with implementations in other modules.
However, this flexibility leads to code duplication as each source file will be using its own, private, implementation.

## Inline Functions in C++

The `inline` keyword first showed up in C++ and, as a result, it sets the precedent for how the average person understands inline functions.
One of the guarantees is not only do the multiple compilations of an inline function not conflict with each other, each module will share the same implication.
Take the function pointer in source file A and you'll get the exact same result as taking the function pointer in source file B.

Compiling our test program in gcc as a C++ program, we get the following output:

```gas
# inline int test1(void)
        .section .text._Z5test1v,"axG",@progbits,_Z5test1v,comdat
        .weak   _Z5test1v
_Z5test1v:
        movl    $12, %eax
        ret

# int test2(void)
        .text
        .globl  _Z5test2v
_Z5test2v:
        call    _Z5test1v
        ret
```

The output is similar to what we see for `extern inline` in C99.
Sure, the function names are mangled, but there are two significant differences.
First, the inline function is marked *weak*.
After all, this object file could have its implementation replaced by that in another object files, which is the very reason for marking a weak symbol.

Second, while our normal function is placed in the `.text` section, something interesting is happening with our inline function.
Frankly, I'm going to need to consult the [GNU Assembler documentation](https://sourceware.org/binutils/docs/as/Section.html#ELF-Version) to make sense of it.

We can extract a few pertinent details from the section declaration:
- The section is named `.text._Z5test1v`.
  Since we are creating a section with unique characteristics, it's going to need a unique name.
  Here, GCC just appends the mangled function name but a random name would be just as acceptable.
- The section is allocatable ("a"), executable ("x"), and a member of a section group ("G").
  Executable is obvious and allocatable just means it gets loaded into the program's memory space.
  The group membership is clearly where the magic is starting to happen.
- `@progbits` means that the section contains data that gets stored in the binary.
  This applies not just to code and data, but things like symbol tables and debugging information.
  This is in contrast to uninitialized sections like `.bss` which don't need to be stored on disk.
- The second appearance of `_Z5test1v` is the *group name*, which is how the linker will identify the multiple realizations.
  Here, it is set the managed function name.
- Finally, `comdat` instructs the linker to discard all but one copy of this section.
  The linker will need the group membership to determine the duplicate copies.

If we want to understand how the resulting object file is put together, we can run `readelf` to see how the various file structures have changed.

```plain
Section Headers:
  [Nr] Name              Type             Address           Offset
       Size              EntSize          Flags  Link  Info  Align
  [ 1] .group            GROUP            0000000000000000  00000040
       0000000000000008  0000000000000004          12    11     4
  [ 6] .text._Z5test1v   PROGBITS         0000000000000000  00000057
       000000000000000f  0000000000000000 AXG       0     0     1
  [12] .symtab           SYMTAB           0000000000000000  00000110
       0000000000000138  0000000000000018          13    11     8

COMDAT group section [    1] `.group' [_Z5test1v] contains 1 sections:
   [Index]    Name
   [    6]   .text._Z5test1v

Symbol table '.symtab' contains 13 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
    11: 0000000000000000    15 FUNC    WEAK   DEFAULT    6 _Z5test1v
    12: 0000000000000000    15 FUNC    GLOBAL DEFAULT    2 _Z5test2v
```

The `.text._Z5test1v` section is marked as being a member of a group, which was clearly called out on the `.section` line, but we also have a new `.group` section with non-zero "link" and "info" fields.
Inside the group, we see it has a name (which comes from the "info" field) and lists the sections that are members of the group.
Finally, the "link" field references the symbol table section containing the names it will be using.

What happens if we have more than one inline function?

```plain
Section Headers:
  [Nr] Name              Type             Address           Offset
       Size              EntSize          Flags  Link  Info  Align
  [ 1] .group            GROUP            0000000000000000  00000040
       0000000000000008  0000000000000004          14    13     4
  [ 2] .group            GROUP            0000000000000000  00000048
       0000000000000008  0000000000000004          14    14     4
  [ 7] .text._Z5test1v   PROGBITS         0000000000000000  00000064
       000000000000000f  0000000000000000 AXG       0     0     1
  [ 8] .text._Z5test3v   PROGBITS         0000000000000000  00000073
       000000000000000f  0000000000000000 AXG       0     0     1
  [14] .symtab           SYMTAB           0000000000000000  00000148
       0000000000000180  0000000000000018          15    13     8

COMDAT group section [    1] `.group' [_Z5test1v] contains 1 sections:
   [Index]    Name
   [    7]   .text._Z5test1v

COMDAT group section [    2] `.group' [_Z5test3v] contains 1 sections:
   [Index]    Name
   [    8]   .text._Z5test3v

Symbol table '.symtab' contains 16 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
    13: 0000000000000000    15 FUNC    WEAK   DEFAULT    7 _Z5test1v
    14: 0000000000000000    15 FUNC    WEAK   DEFAULT    8 _Z5test3v
    15: 0000000000000000    20 FUNC    GLOBAL DEFAULT    3 _Z5test2v
```

Each is placed in its own separate individual section and group.

If the inline function makes use of its own static variables they, too, end up in individual sections and groups.

## Mixing C and C++

What happens if we use the same header file in both C and C++?
Well, without any additional changes...nothing.
By default, C++ will mangle the name, making the two languages fully independent.

So, what happens if we use `extern "C"` to force them to share an implementation?
Officially, I think we're getting into undefined behavior.
In effect, the two separate languages are violating the one implementation rule.
Setting that aside, what happens in practice?

```c++
/* common.h */
#ifdef __cplusplus
extern "C" {
#endif
inline const char *common(void) {
#ifdef __cplusplus
  return "C++";
#else
  return "C";
#endif
}

const char *test_c(void);
const char *test_cpp(void);

#ifdef __cplusplus
}
#endif
```

```c
/* common.c */
#include <stdio.h>
#include "common.h"

int main() {
  printf("test_c = %s\n", test_c());
  printf("test_cpp = %s\n", test_cpp());
}
```

```c
/* inline.c */
#include "common.h"
const char *test_c() {
  return common();
}
```

```c++
/* inline.cpp */
#include "common.h"
const char *test_cpp() {
  return common();
}
```

```plain
~/source/test$ cc -o test -Wall -Wextra -Werror \
  -fsanitize=undefined common.c inline.c inline.cpp

~/source/test$ ./test
test_c = C++
test_cpp = C++
```

Since we never declared an `extern` version of the function in C, it needs to pull an implementation from somewhere and it's clearly pulling it from the shared copy created by the C++ file.
While this works, it's very brittle.
If there isn't a C++ source file referencing the symbol, nothing will be emitted and the C file will fail to link.
We need to force an implementation to allow the C code to function reliably.

So, what happens to C++ if we force the implementation in C?

```c
/* inline2.c */
#include "common.h"
const char *common(void);

const char *test_c() {
  return common();
}
```

```plain
~/source/test$ cc -o test -Wall -Wextra -Werror \
  -fsanitize=undefined common.c inline2.c inline.cpp

~/source/test$ ./test
test_c = C
test_cpp = C
```

In this case, the *weak* symbol emitted by the C++ implementation is being overridden by the C implementation.
So, while I'm sure it's a gross violation of the standards, it seems to work.

And yes, it even works with MSVC (or, in this case, [clang-cl](https://clang.llvm.org/docs/MSVCCompatibility.html) on top of WSL2):

```plain
~/source/test$ cl -o test.exe -Wall -Wextra -Werror \
  common.c inline.c inline.cpp

~/source/test$ ./test.exe
test_c = C
test_cpp = C

~/source/test$ file test.exe
test.exe: PE32+ executable (console) x86-64, for MS Windows
```
