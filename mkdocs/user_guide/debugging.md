# 🎯 Debugging Firmware with PyOCD - A Beginner's Guide

## What is PyOCD?

PyOCD is a Python-based debugging tool specifically designed for ARM Cortex-M microcontrollers. Think of it as a bridge between your computer and your microcontroller that lets you inspect and control your program while it's running. While it only works with ARM processors, it's much more user-friendly than alternatives like OpenOCD.

## Setting Up Your Environment

### 1. Install PyOCD

```bash
pipx install pyocd
```

### 2. Connect Your Hardware

1. You'll need:
    - Your development board
    - A debugger (like STLinkV2)
    - Appropriate connecting cables

2. Make the physical connections:
    - For SWD (most common):
        - Connect GND (Ground)
        - Connect SWDIO (Data line)
        - Connect SWDCLK (Clock line)
    - If your board uses JTAG:
        - Connect GND, TDI, TMS, TCK, and TDO pins
    - If you have a JTAG device that supports SWD
        - Connect GND
        - Connect JTAG TMS to MCU SWDIO
        - Connect JTAG TCK to MCU SWDCLCK

!!! important
    Double-check all connections! Incorrect wiring can damage your board,
    debugger, or computer.

## Starting a Debug Session

### 1. Launch PyOCD Server

First, start the PyOCD server for your specific device:

```bash
# For LPC40xx boards:
pyocd gdbserver --semihost -Osemihost_console_type=True --target=lpc4088 --persist

# For STM32F103xx boards:
pyocd gdbserver --semihost -Osemihost_console_type=True --target=stm32f103rc --persist
```

Not sure about your target? Run `pyocd list --targets` to see all options.

!!! important
    The `--semihost -Osemihost_console_type=True` arguments are required for
    builds that use semihosting. Otherwise you will get an error like this when
    the application attempts to use a semihost API like `puts`, or `printf`:

    ```text
    Program received signal SIGTRAP, Trace/breakpoint trap.
    sys_semihost (p_reason=p_reason@entry=21, p_arg=p_arg@entry=0x20000599 <sys_semihost_get_cmdline::cmdline>)
        at /Users/kammce/.conan2/p/b/libha4b6f251bd59f1/b/src/system_controller.cpp:96
    96            asm volatile("bkpt 0xAB" : "=r"(r0) : "r"(r0), "r"(r1) : "memory");
    ```

    Enabling this does not disrupt applications built without semihost support
    so it is always acceptable enable this in your `pyocd` just in case.

### 2. Connect GDB

Open a new terminal and launch GDB:

```bash
arm-none-eabi-gdb -ex "target remote :3333" -tui your_program.elf
```

This command:

- Opens GDB with a text-based UI (`-tui`)
- Connects to PyOCD (`target remote :3333`)
- Loads your program (`your_program.elf`)

!!! tip
    `arm-none-eabi-gdb` command not found? No worries, build an project for an
    arm based device like so `conan build . -pr stm32f103c8 -pr arm-gcc-12.3`.
    There is a file called `generators/conanbuild.sh` which provides your
    command line access to the paths to the ARM compiler toolchain where GDB
    resides. Sourcing those environment variables would look like this, but
    replace `stm32f103c8` with your platform and `MinSizeRel` with your build
    type:

    ```bash
    source build/stm32f103c8/MinSizeRel/generators/conanbuild.sh
    ```

## Basic Debugging Commands

### Essential GDB Commands

```gdb
# Start your debug session
b main                   # Set breakpoint at main()
monitor reset halt       # Reset the CPU and stop at the beginning
c                        # Continue execution

# Navigate through code
n (or next)              # Execute next line (skip function details)
s (or step)              # Step into functions
finish                   # Run until current function returns
c (or continue)          # Run until next breakpoint

# Inspect values
p variable_name          # Print variable value
info registers           # View all CPU registers
```

!!! tip
    If you are familiar with GDB, you notice that the command "run" was not
    used. In this context, there is no program, just the CPU. The debugger is
    controlling and stopping the CPU from executing. So there is no need to
    "run" the program, its already running. You simply have to continue.

### Viewing Memory and Registers

To access hardware registers and memory:

```gdb
# Enable access to all memory
set mem inaccessible-by-default off

# View register values
p gpio_reg->CTRL         # View specific register
```

### Managing Breakpoints

```gdb
b function_name         # Break at function start
b filename.cpp:123      # Break at specific line
info breakpoints        # List all breakpoints
delete 1                # Remove breakpoint #1
delete                  # Remove all breakpoints
```

### Updating Your Program

If you make changes to your code:

1. Build your program in another terminal
2. In GDB:

   ```gdb
   monitor erase         # Erase current firmware image
   load                  # Flash the new program
   monitor reset halt    # Reset to start and halt CPU
   ```

## Tips for Beginners

- Start with simple programs to get comfortable with the debugging process
- Use frequent breakpoints to understand program flow
- `-s build_type=Debug` builds are easy to debug with a debugger than
  `-s build_type=MinSizeRel` or `-s build_type=Release` builds
- Remember that embedded debugging is different from regular program debugging
  because your code is running on actual hardware and you are controlling the
  cpu
- If you can't see source code lines initially, don't worry - this is normal
  with bootloaders (like on LPC40xx boards), proceed with the `continue`
  command and you should end up at your first breakpoint whenever it is reached

For a complete reference of GDB commands, check out this
[GDB Cheat Sheet](http://darkdust.net/files/GDB%20Cheat%20Sheet.pdf).
