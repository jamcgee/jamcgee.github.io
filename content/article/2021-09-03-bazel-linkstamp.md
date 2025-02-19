---
date: 2021-09-03T19:45:00-07:00
title: Bazel Linkstamp
slug: bazel-linkstamp
tags:
  - Bazel
  - C++
  - programming
---

[Bazel](https://bazel.build/) is one of the *least terrible* build systems out there.
It can handle large codebases, mixed languages, and cross-platform builds like a champ.
Unfortunately, it suffers from rather poor documentation with an enterprise Java codebase that is a nightmare to decipher.

One of the features I've been trying to make use of are *linkstamps*.
The idea behind linkstamps is to embed information such as the Git commit identifier into the resulting binary, providing direct traceability for deployed binaries.
Unfortunately, regarding this feature, Bazel suffers from the common documentation anti-pattern where they describe what an option *is*, not what it *does*.

> **Note:** These instructions were written at the time of Bazel 4.2.1.

## Workspace Status

The primary mechanism for getting VCS information into Bazel, is the [`--workspace_status_command`](https://docs.bazel.build/versions/4.2.0/user-manual.html#workspace_status) option.
This takes a *path* to a script or executable that is invoked at the beginning of each build.
The `stdout` of this script is captured and parsed as a set of name-value pairs, with the name and value separated *by a single space character* (ASCII 32).
Additional whitespace is captured as part of the value.

Once parsed, the variables are separated into two groups: stable and volatile.
Volatile variables are the default and are assumed to change frequently with little consequence on the binary itself, so these variables are ignored when making decisions regarding stale build artifacts.
Stable variables are expected to change rarely or have greater consequence on the binary (e.g. version numbers), triggering a rebuild each time they change, and are marked by prefixing the name with with `STABLE_`.

**Note:** The `STABLE_` prefix is actually part of the name and is retained in the status metadata files.
Some of the built-in variables (namely `BUILD_EMBED_LABEL`, `BUILD_HOST`, `BUILD_USER`) are considered stable despite lacking this prefix.

Relevant source file: [BazelWorkspaceStatusModule.java](https://github.com/bazelbuild/bazel/blob/4.2.0/src/main/java/com/google/devtools/build/lib/bazel/BazelWorkspaceStatusModule.java)

## Access to Status

Access to the status information can be made through three mechanisms:

1. The `stamp` attribute on many of the built-in rules, which interacts with the `--[no]stamp` command line setting to support redacting the variables for faster builds.
   Unfortunately, access is generally limited to the built-in variables (`BUILD_*`).
   The use of this option with the C++ rules is described below.
2. The *undocumented* `stamp` attribute on [`genrule`](https://docs.bazel.build/versions/4.2.0/be/general.html#genrule).
   This places a dependency on the files `bazel-out/stable-status.txt` and `bazel-out/volatile-status.txt`, which contain both the built-in variables and those generated by `--workspace_status_command`.
3. The *undocumented* `version_file` and `info_file` attributes on the [`ctx`](https://docs.bazel.build/versions/4.2.0/skylark/lib/ctx.html) object, which are references to [`File`](https://docs.bazel.build/versions/4.2.0/skylark/lib/File.html) objects.

It should be pointed out that the only mechanisms by which the full set of workspace status variables can be accessed are *undocumented*.
And as they only give you access to the file, not its contents, they cannot be combined with the [`expand_template`](https://docs.bazel.build/versions/4.2.0/skylark/lib/actions.html#expand_template) or [`write`](https://docs.bazel.build/versions/4.2.0/skylark/lib/actions.html#write) actions.

Relevant source file: [StarlarkRuleContextApi.java](https://github.com/bazelbuild/bazel/blob/4.2.0/src/main/java/com/google/devtools/build/lib/starlarkbuildapi/StarlarkRuleContextApi.java)

## C++ Rules

The built-in C++ rules interact with the linkstamping system in a counter-intuitive manner that involves an unusual interaction between `cc_binary` (or `cc_test`) and `cc_library`.
The `cc_binary` rule has a tri-state [`stamp`](https://docs.bazel.build/versions/4.2.0/be/c-cpp.html#cc_binary.stamp) argument that enables or disables the use of linkstamping while the encoding of the linkstamp is defined by the [`linkstamp`](https://docs.bazel.build/versions/4.2.0/be/c-cpp.html#cc_library.linkstamp) argument on `cc_library`.
This means that use of linkstamping *requires* a library to provide the encoding (presumably a library that *only* deals with linkstamping).

First, the C++ rules only expose the following workspace status variables:

- `BUILD_EMBED_LABEL` (string) - `""` unless overridden by the `--embed_label` option.
- `BUILD_HOST` (string) - Automatically populated by Bazel.
- `BUILD_SCM_REVISION` (string) - `"0"` unless overridden by the `--workspace_status_command` script.
- `BUILD_SCM_STATUS` (string) - `""` unless overridden by the  `--workspace_status_command` script.
- `BUILD_TIMESTAMP` (integer) - Automatically populated by Bazel.
- `BUILD_USER` (string) - Automatically populated by Bazel.

Any other variables set by your `--workspace_status_command` script are simply not available.
Worse, `BUILD_SCM_REVISION` and `BUILD_SCM_STATUS` are considered *volatile* parameters (they're populated by the status script and don't start with `STABLE_`), so there's no guarantee your binaries will be updated if these values change.

The source file provided to `cc_library.linkstamp` is not compiled with the library but, instead, with the binary that eventually depends on it.
Unlike normal source files, it has no access to the library's headers and must be entirely self-contained, which can be a problem if you're embedding this information into a data structure.
Bazel's C++ rules will *inject* the status variables into the preprocessor using the `-include` argument to gcc.

As a demonstration, we can see how this is executed using `bazel aquery` (after simplifying the output):

```
action 'Compiling linkstamp.cc'
  Mnemonic: CppLinkstampCompile
  Inputs: [bazel-out/k8-fastbuild/include/build-info-redacted.h, linkstamp.cc]
  Outputs: [bazel-out/k8-fastbuild/bin/_objs/linkstamp/linkstamp.o]
  Command Line: (exec /usr/bin/gcc \
    '-DG3_BUILD_TARGET="bazel-out/k8-fastbuild/bin/linkstamp"' \
    '-DG3_TARGET_NAME="//:linkstamp"' \
    '-DBUILD_COVERAGE_ENABLED=0' \
    '-DGPLATFORM="local"' \
    -include \
    bazel-out/k8-fastbuild/include/build-info-redacted.h \
    -c \
    linkstamp.cc \
    -o \
    bazel-out/k8-fastbuild/bin/_objs/linkstamp/linkstamp.o)
```

The specific files injected are dependent on the interaction between the `cc_binary.stamp` argument and the `--[no]stamp` option to Bazel.
When stamping is disabled, either because `--nostamp` is selected or the binary forces it off (e.g. tests), the file `build-info-redacted.h` is included, which renders all strings to `"redacted"` and the timestamp to zero.

Relevant Source File: [WriteBuildInfoHeaderAction.java](https://github.com/bazelbuild/bazel/blob/4.2.0/src/main/java/com/google/devtools/build/lib/rules/cpp/WriteBuildInfoHeaderAction.java)

## Limitations

The workspace status system suffers from some glaring limitations:
- The lifetime of a variable (stable vs volatile) is embedded into the *name* of the variable (i.e. the `STABLE_` prefix), meaning that any change to the lifetime ripples through all references to said variable.
- The invoked script is identified by a command line option, not the `WORKSPACE`, making it impossible to select out different scripts by OS (e.g. Windows vs Unix) or providing reliable operation when referenced by dependent workspaces.
- The invoked script is identified by *path*, not by label.
  This means the script cannot be a build artifact from the workspace.
- There is no *documented* mechanism by which a C++ build can access additional variables from the status set or integrate the data in more complicate data structures described by headers.
  The later is very common for firmware builds, which need to place the stamp in a specific location for discovery purposes.

Some of these can be mitigated, either by using undocumented features (e.g. `genrule.stamp` or the attributes on `ctx`) or using `genrule` to execute programs that extract information from outside the sandbox.

## Intended Usage Example

For simple linkstamping needs, one can simply rely on the built-in rules and get the intended `--stamp`/`--nostamp` behavior.

### .bazelrc

```shell
build --workspace_status_command=tools/workspace-status.sh
build:release -c opt --stamp
```

### tools/BUILD

```python
cc_library(
    name = "linkstamp",
    linkstamp = "linkstamp.c",
)
```

### tools/linkstamp.h

```c++
#ifndef TOOLS_LINKSTAMP_H_
#define TOOLS_LINKSTAMP_H_
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

extern const time_t build_timestamp;
extern const char build_revision[];
extern const char build_status[];

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // TOOLS_LINKSTAMP_H_
```

### tools/linkstamp.c

```c
#include <time.h>
const time_t build_timestamp = BUILD_TIMESTAMP;
const char build_revision[] = BUILD_SCM_REVISION;
const char build_status[] = BUILD_SCM_STATUS;
```

### tools/workspace-status.sh

```shell
#!/bin/sh -
echo "BUILD_SCM_REVISION $(git rev-parse HEAD)"
if git diff --quiet; then
  echo "BUILD_SCM_STATUS clean"
else
  echo "BUILD_SCM_STATUS dirty"
fi
```

## genrule Example

If its necessary to access other status variables, the `genrule.stamp` option can be used to gain access to the intended data.

### tools/BUILD

```python
cc_library(
    name = "linkstamp",
    hdrs = [":linkstamp-gen"],
)

genrule(
    name = "linkstamp-gen",
    outs = ["linkstamp.h"],
    cmd = "$(location linkstamp.sh) > $@",
    exec_tools = ["linkstamp.sh"],
    stamp = True,
    visibility = ["//visibility:private"],
)
```

### tools/linkstamp.sh

```sh
#!/bin/sh -
echo "#ifndef TOOLS_LINKSTAMP_H_"
echo "#define TOOLS_LINKSTAMP_H_"
cat bazel-out/stable-status.txt bazel-out/volatile-status.txt | sed -Ee's/^(\w+) (.*)/#define \1 "\2"/'
echo "#endif"
```

### bazel-bin/tools/linkstamp.h (Example Output)

```c
#ifndef TOOLS_LINKSTAMP_H_
#define TOOLS_LINKSTAMP_H_
#define BUILD_EMBED_LABEL ""
#define BUILD_HOST "redacted"
#define BUILD_USER "redacted"
#define BUILD_SCM_REVISION "8e8b18a"
#define BUILD_SCM_STATUS "dirty"
#define BUILD_TIMESTAMP "1630722892"
#define GIT_BRANCH "test"
#define STABLE_GIT_TAG "v0.1.2+18-dirty"
#endif
```
