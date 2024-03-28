# Setting up VSCode w/ `clangd`

Most of our users use VSCode so we made a guide for them. These guidelines
should also work for non-vscode users as well.

!!! info

      The default "C/C++" extension by VSCode is nice that it can figure a ton
      of things out about your system automatically. But the way we write code
      for `libhal` using `conan` makes the extension difficult and slow to use.
      This is due to the fact that we need to point the extension to the
      `.conan2/p/` (conan 2 package directory). Because that directory could
      have a large number of files and multiple version of the same project, it
      tends to get confused, stop working, or get very slow. We recommend
      `clangd` because it is fast, helpful, and easy to use.

## Setup Steps

1. Install [VSCode](https://code.visualstudio.com/) if you don't already have
   it installed.
2. Go the the "Extensions" section on the left side bar. Hover over the icons
   to get their name.
3. Search for "C/C++" and disable the extension if it is already installed and
   enabled.
4. Search for the extension `clangd` and install the extension.

## How `clangd` works

You are almost done, but we need to discuss what is needed to make `clangd`
work. A workspace will need a `compile_commands.json` file to be present
in your root directory or to use a `.clangd` file at the root of the repo
that configures where to look for the `.json` file. `compile_commands.json`
tells `clangd` what commands you are using in order to determine exactly how
your files are built and what commands are used to build them, which provides
the following benefits:

1. More accurate warnings and error messages in the IDE
2. Faster response time because only the necessary includes for the specific
   version you are targeted will be used in the evaluation.

## Enabling `clangd`

### For a libhal library projects

If you are contributing to libhal project/repo, then those libraries and demos
will already be using `libhal-cmake-util/[^4.0.5]` which will automatically enable the
generation of a `compile_commands.json` file. To get this file, run:

```bash
conan build .
```

And it will be generated.

If you are attempting to do with is a demo or an application you will need to
specify the platform and compiler like usual.

```bash
conan build . -pr lpc4078 -pr arm-gcc-12.3
```

### For your own project

You can either add a `self.requires("libhal-cmake-util/[^4.0.5]")` to your
project or add the following lines to your `CMakeLists.txt`.

```cmake
# Generate compile commands for anyone using our libraries.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Always run this custom target by making it depend on ALL
add_custom_target(copy_compile_commands ALL
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    ${CMAKE_BINARY_DIR}/compile_commands.json
    ${CMAKE_SOURCE_DIR}/compile_commands.json
    DEPENDS ${CMAKE_BINARY_DIR}/compile_commands.json)
```

Now run `conan build .` (where `.` is the path to your project or library) and
it should generate the `compile_commands.json` file.

Ensure that you include the necessary profiles added to the build.

```bash
conan build . -pr stm32f103 -pr arm-gcc-12.3
```

### Refreshing the LSP

Now that you should have your `compile_commands.json` in the right location,
you just need to refresh your LSP.

1. In VSCode Press: `⌘+shift+P` on Mac or `Ctrl+Shift+P` on everything else.
2. Select the following command: `clangd: restart language server`

Now your LSP should be active and your C++ files should be able to find your
includes as well as infer the types of your objects.
