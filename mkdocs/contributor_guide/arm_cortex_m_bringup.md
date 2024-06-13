# 🧠 ARM Cortex-M Series Platform Bringup

To fully bring up any ARM Cortex-M series micro-controller for libhal, the
following list of things need to be implemented:

1. Linker scripts
1. Conan profiles
1. CI & Deployment setup

To make drivers possible to be implemented for the various peripherals within the micro-controller, then APIs for the following are required.

1. Power control
2. Pin Multiplexing
3. Clock tree
4. Direct Memory Access (DMA)

Understand that, like all libhal tutorials, everything is relative and some company may have made a chip that is not very reasonable and doesn't fit the typical scheme laid out here. In such cases, you'll need to understand the basics and use good judgement to make your system work.

## Getting Started

libhal provides a template repo for ARM Cortex M series platforms. To get
started, simply go to the
[`libhal-__platform__`](https://github.com/libhal/libhal-__platform__) and press the button "Use this template" and then "Create new repository".

The name of the project should be `libhal-<insert platform name>`. This allows
the github action
[update_name.yml](https://github.com/libhal/libhal-__platform__/blob/main/.github/workflows/update_name.yml), create a pull request that updates the names
and files within the repo from `__platform__` to the name that you choose.
Merge this pull request and continue on to the next phase.

!!! note

    If there is demand for platform names that do not have `libhal-` as a
    prefix, we can update `update_name.yml` to allow it. But for now, we just
    support prefixed package names.

## Conan profiles

TBD

## Linker Scripts

Linker scripts define the memory layout of an embedded system. They specify how
different types of data are organized within the binary. This includes code,
initialized data, uninitialized data, read-only data, and thread local storage.
Additionally, they delineate the memory regions available for the application,
ensuring optimal memory usage and system stability.

The processor library `libhal-armcortex` provides standard linker script
templates that can be used in your platform labeled
[`libhal-armcortex/linker_scripts/libhal-armcortex/standard.ld`](https://github.com/libhal/libhal-armcortex/blob/main/linker_scripts/libhal-armcortex/standard.ld).

To use this you only need to provide the following within your linker scripts
directory:

```ld
__flash = 0x00000000;
__flash_size = 64K;
__ram = 0x10000000;
__ram_size = 16K;
__stack_size = 1K;

INCLUDE "libhal-armcortex/standard.ld"
```

The above is the linker script file for the [`lpc4072`](https://github.com/libhal/libhal-lpc40/blob/main/linker_scripts/libhal-lpc40/lpc4072.ld) as an example.

You simply need to specify:

- Where the flash memory is located in the device's address space
- How large the flash is
- Where the main ram is located in the device's address space
- How large the ram is
- The minimum stack size before the build should fail

The minimum stack size is kind of arbitrary so use `1k` as the standard for
libhal. If the ram is really small choose what seems reasonable for the device.
At some point we may determine that a better value is necessary here. The
minimum stack size is relative to the ram size. For example, if you have 15.5kB
of static memory, that only leaves 500 bytes available for the program's stack.

You'll need a linker script for every variation of the chip available in the chip's family that has a different flash and ram size.

For example the chips in the LPC40xx series are:

- [lpc4072](https://github.com/libhal/libhal-lpc40/blob/main/linker_scripts/libhal-lpc40/lpc4072.ld)
- [lpc4074](https://github.com/libhal/libhal-lpc40/blob/main/linker_scripts/libhal-lpc40/lpc4074.ld)
- [lpc4076](https://github.com/libhal/libhal-lpc40/blob/main/linker_scripts/libhal-lpc40/lpc4076.ld)
- [lpc4078](https://github.com/libhal/libhal-lpc40/blob/main/linker_scripts/libhal-lpc40/lpc4078.ld)
- [lpc4088](https://github.com/libhal/libhal-lpc40/blob/main/linker_scripts/libhal-lpc40/lpc4088.ld)

And each of them requires their own linker script because the flash and ram
is different for each.

The stm32f10x series has:

- [stm32f10xx4.ld](https://github.com/libhal/libhal-stm32f1/blob/main/linker_scripts/libhal-stm32f1/stm32f10xx4.ld)
- [stm32f10xx6.ld](https://github.com/libhal/libhal-stm32f1/blob/main/linker_scripts/libhal-stm32f1/stm32f10xx6.ld)
- [stm32f10xx8.ld](https://github.com/libhal/libhal-stm32f1/blob/main/linker_scripts/libhal-stm32f1/stm32f10xx8.ld)
- [stm32f10xxb.ld](https://github.com/libhal/libhal-stm32f1/blob/main/linker_scripts/libhal-stm32f1/stm32f10xxb.ld)
- [stm32f10xxc.ld](https://github.com/libhal/libhal-stm32f1/blob/main/linker_scripts/libhal-stm32f1/stm32f10xxc.ld)
- [stm32f10xxd.ld](https://github.com/libhal/libhal-stm32f1/blob/main/linker_scripts/libhal-stm32f1/stm32f10xxd.ld)
- [stm32f10xxe.ld](https://github.com/libhal/libhal-stm32f1/blob/main/linker_scripts/libhal-stm32f1/stm32f10xxe.ld)
- [stm32f10xxf.ld](https://github.com/libhal/libhal-stm32f1/blob/main/linker_scripts/libhal-stm32f1/stm32f10xxf.ld)
- [stm32f10xxg.ld](https://github.com/libhal/libhal-stm32f1/blob/main/linker_scripts/libhal-stm32f1/stm32f10xxg.ld)

The last digit of the chip name defines its flash and ram requirements and thus, each is given its own linker script.

!!! note "Supporting multi flash multi ram MCUs"

    libhal-armcortex's linker script only supports single flash, single ram
    MCUs. We are still deciding how we want to handle devices with these memory
    layouts into the future. If this is a necessary feature for your platform then add a thumbs up emoji reaction to this GitHub issue: [Add multi flash & multi ram linker scripts](https://github.com/libhal/libhal-armcortex/issues/16)

In order to communicate to the build system what your linker scripts are and where to find them, we must add to the conan package's `cpp_info.exelinkflags` array. This property describes to conan what link flags should be added if a package depends on this package. See the code below.

```python
def add_linker_scripts_to_link_flags(self):
    platform = str(self.options.platform)
    # This attribute defines the list of linker flags for this package
    self.cpp_info.exelinkflags = [
        # -L is the linker script equivalent of -I in GCC and it tells GCC
        # flag where to find linker scripts.
        "-L" + os.path.join(self.package_folder, "linker_scripts"),
        # -T provides a path to the a linker script. GCC will search all -L
        # directories passed to it and its own internal linker paths.
        "-T" + os.path.join("libhal-__platform__", platform + ".ld"),
    ]

def package_info(self):
    self.cpp_info.set_property("cmake_target_name", "libhal::__platform__")
    self.cpp_info.libs = ["libhal-__platform__"]

    # We only want to apply the linker scripts when the OS is baremetal.
    # Otherwise the linker script flags will be injected into the host test
    # build causing them to fail.
    if self.settings.os == "baremetal" and self._use_linker_script:
        self.add_linker_scripts_to_link_flags()
```

### Implementing linker scripts for your platform

#### 1. Download and open user manual

The data sheet may also have the information as well, but the user manual will likely have the whole memory map as well. Search for the area labelled "memory map" and you should find the sizes for all of the different device's flash and
ram sizes are.

#### 2. Determine the naming scheme

Some devices have clear cut names for each device without any sort of pattern or coded symbols, like lpc4078. Some are like stm32f10x where a few of the numbers are not necessary it would require less files to just use a few files and ignore the characters are not needed. Every profile needs to map to exactly one linker script, but a linker script can map to many profiles.

#### 3. Fill out the information in this file

```ld
__flash = ???;
__flash_size = ???;
__ram = ???;
__ram_size = ???;
__stack_size = 1K;

INCLUDE "libhal-armcortex/standard.ld"
```

#### 4. Repeat #3

Until all files are written.

#### 5. Update `add_linker_scripts_to_link_flags()` in `conanfile.py`

In order for your package to be able to tell the

If there is just one profile for each linker script and they are named the same (ignoring the .ld extension) then you can keep the default `add_linker_scripts_to_link_flags()` function and change nothing. You may skip this step.

If you are from the st family or some other MCU that likes to have a lot of family members see below:

```python
def add_linker_scripts_to_link_flags(self):
    linker_script_name = list(str(self.options.platform))
    # Replace the MCU number and pin count number with 'x' (don't care)
    # to map to the linker script
    linker_script_name[8] = 'x'
    linker_script_name[9] = 'x'
    linker_script_name = "".join(linker_script_name)

    self.cpp_info.exelinkflags = [
        "-L" + os.path.join(self.package_folder, "linker_scripts"),
        "-T" + os.path.join("libhal-stm32f1", linker_script_name + ".ld"),
    ]
```

The pattern with stm32f10x is that there are two additional letters that define
the chip size and feature set. These are not important to the linker script
so we replace those with the typical hardware "x" denoting it as a "don't care"
symbol. We can simply take the full `stm32f103c8` and transform it to
`stm32f10xx8` and use that to construct the path to the linker script. If your
names do not map so easily, then its advisable to use a python `dict` to map
each profile to its linker script path and pass that to the
`cpp_info.exelinkflags`.

### 6. Done! Now to test

Remember to replace `YOUR_PROFILE` with your actual profile name in each
command.

To test, try to build your package using:

```bash
conan create . -pr YOUR_PROFILE -pr arm-gcc-12.3 --version=latest
```

!!! Note

    We use `--version=latest` because the demos will either use the latest
    compatible and cached version of the library or they will use `latest`.
    They use the semver pattern `[^1.0.0 || latest]`.

Then try and build your demos:

```bash
VERBOSE=1 conan build demos -pr YOUR_PROFILE -pr arm-gcc-12.3
```

On Windows:

```bash
$env:VERBOSE=1 conan build demos -pr YOUR_PROFILE -pr arm-gcc-12.3
```

The `VERBOSE=1` environment variable is needed to get CMake to print the full
command string to stdout. If you are on Windows or using a terminal that cannot
handle CMake's multi-thread output add this to the end of the command
`tools.build:jobs=1` to make the build single threaded.

Take the output and search for your `-Tyour_linker_script.ld` command argument. If it is there then you were successful. To ensure that the binary also fits the linker scripts's addresses use the following command:

```bash
arm-none-eabi-readelf -S demos/build/YOUR_PROFILE/MinSizeRel/blinker.elf
```

!!! note "if the above command fails"

    If the above command does not work, on linux and mac, run this command:

    ```bash
    source demos/build/YOUR_PROFILE/MinSizeRel/generators/conanbuild.sh
    ```

    This will add all of the conan build environment variables to your shell.

Confirm that:

1. `.init` address is equal the flash address
2. `.data` address is equal to the ram ram.

If so, then you are finished.

## CI & Deployment setup

TBD

## Peripheral Constants

TBD

## Power control

The library should provide APIs for powering on and off peripherals on the
device.

The typical libhal APIs for power are:

```C++
#pragma once

#include "constants.hpp"

namespace hal::your_platform {
/**
 * @brief Power on the peripheral
 *
 */
void power_on(peripheral p_peripheral);

/**
 * @brief Check if the peripheral is powered on
 *
 * @return true - peripheral is on
 * @return false - peripheral is off
 */
[[nodiscard]] bool is_on(peripheral p_peripheral);

/**
 * @brief Power off peripheral
 *
 */
void power_off(peripheral p_peripheral);
}  // namespace hal::your_platform
```

The `peripheral` type is an `enum class` with each peripheral represented. Here is an example from `libhal-lpc40`.

```C++
enum class peripheral : std::uint8_t
{
  lcd = 0,
  timer0 = 1,
  timer1 = 2,
  uart0 = 3,
  uart1 = 4,
  pwm0 = 5,
  pwm1 = 6,
  i2c0 = 7,
  uart4 = 8,
  rtc = 9,
  ssp1 = 10,
  emc = 11,
  adc = 12,
  can1 = 13,
  can2 = 14,
  gpio = 15,
  spifi = 16,
  motor_control_pwm = 17,
  quadrature_encoder = 18,
  i2c1 = 19,
  ssp2 = 20,
  ssp0 = 21,
  timer2 = 22,
  timer3 = 23,
  uart2 = 24,
  uart3 = 25,
  i2c2 = 26,
  i2s = 27,
  sdcard = 28,
  gpdma = 29,
  ethernet = 30,
  usb = 31,
  cpu,  // always on
  dac,  // always on
};
```

Some devices will always be powered on and do not require power controls. The  `peripheral` type can be used in other parts of the code for example
the clock tree, so always powered peripherals can also show up here in the list.

The behavior for always powered peripherals is to simply do nothing when passed their peripheral id.

The API should do what is described in the comments.
The peripheral enumeration should exist in a `constants.hpp` header.
The header should
