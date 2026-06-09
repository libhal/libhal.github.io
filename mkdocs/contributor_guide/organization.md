# 🗃️ Organization

This section will explain the different parts/repos of libhal organization and
ecosystem and how they are organized.

## Target Libraries

Target libraries provide platform-specific implementations of the libhal
interfaces. Each target library directly depends on `libhal` and encapsulates
everything needed for a given hardware platform — processor startup, peripheral
drivers, and any board-level support — in a single package.

``` mermaid
flowchart LR
    libhal
    subgraph arm
      libhal-arm-mcu
    end
    subgraph riscv
      libhal-riscv-mcu
    end
    subgraph os
      libhal-linux
      libhal-mac
    end
    subgraph board
      libhal-micromod
      libhal-picosdk
    end

    libhal-->libhal-arm-mcu
    libhal-->libhal-riscv-mcu
    libhal-->libhal-linux
    libhal-->libhal-mac
    libhal-->libhal-micromod
    libhal-->libhal-picosdk
```

`libhal-arm-mcu` is a unified package that contains ARM Cortex-M core support
along with drivers for all supported ARM MCU families:

- **cortex_m** — Cortex-M core (SysTick, DWT, interrupts, startup)
- **lpc40** — NXP LPC40xx series
- **stm32f1** — STMicroelectronics STM32F1 series
- **stm32f40** — STMicroelectronics STM32F40x series
- **stm32f411** — STMicroelectronics STM32F411 series

`libhal-riscv-mcu` is planned as the RISC-V equivalent of `libhal-arm-mcu`.

`libhal-micromod` is a board abstraction library for the
[SparkFun MicroMod](https://www.sparkfun.com/micromod) pinout and protocol.
Applications only need to require `libhal-micromod`; the correct underlying
processor library is automatically brought in based on the target board profile.

## Device Libraries

Device driver libraries depend only on the libhal interfaces. The
implementations of those interfaces come from a target library in the
application. Device libraries are organized by category:

``` mermaid
flowchart TD
    libhal
    libhal-->libhal-sensor
    libhal-->libhal-actuator
    libhal-->libhal-display
    libhal-->libhal-expander
    libhal-->libhal-input
    libhal-->libhal-storage
    libhal-->libhal-iot
```

| Package           | Description                                   |
| ----------------- | --------------------------------------------- |
| `libhal-sensor`   | Sensors (IMUs, temperature, distance, etc.)   |
| `libhal-actuator` | Actuators (motors, servos, etc.)              |
| `libhal-display`  | Display drivers (SSD, TFT, LED matrix, etc.)  |
| `libhal-expander` | I/O expanders and multiplexers                |
| `libhal-input`    | Input devices (controllers, encoders, etc.)   |
| `libhal-storage`  | Storage peripherals (flash, EEPROM, SD cards) |
| `libhal-iot`      | IoT connectivity (WiFi modules, etc.)         |

## Typical Application

Lets consider an application such as "Pong". A game of pong where we use a
display and two controllers using the STM32F103 microcontroller.

``` mermaid
flowchart LR
    libhal-->libhal-display-->app
    libhal-->libhal-arm-mcu-->app
    libhal-->libhal-input-->app
```

The `conanfile.py` requirements would look something like this:

```python
def requirements(self):
    self.requires("libhal-arm-mcu/[^1.0.0]")
    self.requires("libhal-display/[^1.0.0]")
    self.requires("libhal-input/[^1.0.0]")
    self.requires("libhal-util/[^5.4.0]")
```

## Application Libraries

Application libraries are effectively applications with no specific dependency
on a particular target. The point of a Application library is to deploy a fully
fledged application, but with customizable drivers. For example, the pong game
mentioned earlier doesn't require a specific controller or display. You could
take a `hal::display` interface and some `pong::gamepad` interface defined by
the Application library that the developer can implement themselves. Then the
pong Application can take your display, gamepad and additional information like
"paddle size" and "font size" and use it to generate a game of pong. The
developer gets the opportunity to choose which parts they want for each. Maybe
they want a very large TFT display or they want to use an LED matrix. The
choices are endless.

## Build Infrastructure

The libhal ecosystem has several infrastructure packages that handle toolchain
selection, CMake integration, and Conan configuration.

### Toolchains

libhal supports two toolchain packages, both distributed as Conan tool
requirements:

- **`multiarch-gnu-toolchain`** — GCC toolchain providing both native
  compilation and ARM cross-compilation (`arm-none-eabi-gcc`). Support for
  additional architectures (RISC-V, AVR, Xtensa) is planned.
- **`llvm-toolchain`** — LLVM/Clang toolchain with full C++20 modules support,
  targeting ARM Cortex-M and native platforms.

Toolchain packages are referenced in Conan profiles rather than in application
`conanfile.py` files directly.

### Conan Configuration

**`conan-config2`** is the Conan 2.x configuration repository for libhal.
Install it once with:

```bash
conan config install https://github.com/libhal/conan-config2.git
```

It provides all libhal build profiles and the `conan hal` command extension,
which includes `conan hal setup` for configuring remotes and profiles, and
`conan hal docs` for generating API documentation.

### Build Helpers

- **`libhal-bootstrap`** — A Conan `python-require` package that provides base
  `ConanFile` classes (`demo`, `app`, `library`) shared across libhal projects.
  Handles platform detection, CMake setup, and tool requirements automatically.
- **`libhal-cmake-util`** — CMake helper functions and utilities for libhal
  projects (v5 current; v4 is deprecated). Provides `libhal_project_init()`,
  `libhal_add_library()`, and standard compiler option helpers.

## Foundation Libraries

Beyond the hardware interfaces, libhal ships several foundational C++23
libraries useful in embedded contexts:

- **`strong_ptr`** — A non-null, reference-counted smart pointer backed by
  `std::pmr::memory_resource`. A safer alternative to `std::shared_ptr` for
  memory-constrained systems.
- **`async_context`** — A lightweight C++23 coroutine library using stack-based
  allocation to avoid heap usage, designed for embedded schedulers.
- **`libhal-util`** — Utility functions and helpers that extend the core libhal
  interfaces (math, bit manipulation, timeout wrappers, etc.).
- **`libexcept`** — Exception handling support for embedded targets.
- **`libhal-freertos`** — FreeRTOS integration for libhal.

## 🔍 Finding Drivers

To find drivers you can look in these locations:

- [libhal](https://github.com/libhal/libhal) organization on GitHub
- [conan center](https://conan.io/center/) index
- [libhal driver index]() ❌

!!! example

    libhal driver index is not available currently and is key to finding
    drivers around the ecosystem.

Search for the name of the device or target you are interested in. For example,
the `stm32f103` microcontroller drivers are in `libhal-arm-mcu`. Sensor drivers
are in `libhal-sensor`.

## 📑 Reference Material

Reference material can be found in the `datasheets/` and `schematic/` folders
within target library repositories. These are updated with relevant documents
for easy access for developers and contributors.
