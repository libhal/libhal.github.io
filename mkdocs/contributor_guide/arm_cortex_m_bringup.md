# 🧠 ARM Cortex-M Series Platform Bringup

To fully bring up an ARM Cortex-M series microcontroller for libhal, several
critical elements need to be implemented:

1. Conan profiles
2. Linker scripts
3. Continuous Integration & Deployment
4. Platform Constants
5. Core APIs

To ensure peripheral drivers operate without conflicts, such as clashing power
control implementations, the following APIs must be implemented:

1. Power control
2. Pin Multiplexing
3. Clock tree
4. Direct Memory Access (DMA)

While not all devices support these features, and many drivers can function
without them, implementing them ensures comprehensive peripheral support. For
instance, on the LPC40xx series, GPIOs are enabled by default, and simple tasks
like blinking an LED don't require knowledge of the system's clock speed or DMA.

However, accommodating all features enables support for all potential
peripheral drivers.

Keep in mind that, as with all libhal tutorials, adaptability is key. Some
chips may deviate from standard architectures; in such cases, a fundamental
understanding and sound judgment are essential to ensure your system functions
effectively.

## 🚀 Getting Started

libhal provides a template repository for ARM Cortex-M series platforms. Begin
by visiting
[`libhal-__platform__`](https://github.com/libhal/libhal-__platform__),
clicking "Use this template," and then "Create new repository."

Your project should be named `libhal-<insert platform name>`. This standard
naming triggers the GitHub action
[update_name.yml](https://github.com/libhal/libhal-__platform__/blob/main/.github/workflows/update_name.yml)
to create a pull request that updates names and files within the repo from
`__platform__` to your chosen name. Merge this pull request to proceed to the
next phase.

!!! note

    If there is demand for platform names without the `libhal-` prefix, we can
    modify `update_name.yml` to accommodate this. Currently, we support only
    prefixed package names.

## 🌐 Conan Profiles

Libhal leverages Conan's robust profile system to specify the architecture and
operating system for which an application is built. If you are new to libhal,
refer to the "Getting Started" guide for details on building applications using
compiler and platform profiles.

A microcontroller family consists of microcontrollers with nearly identical
designs but variations in memory, storage, and peripherals. Since these
variations share a common architecture, drivers can typically operate across
the family.

Creating a Conan profile begins with understanding the device family. This
determines the number of profiles needed. For example, the RP2040, which is a
single-device family, would have one profile simply named `rp2040`. However, a
chip family with 15 variations would require a distinct profile for each
variant.

### Components of a Typical Profile

Below is an example of a Conan profile for the `rp2040` microcontroller:

```plaintext
[settings]
build_type=MinSizeRel
os=baremetal
arch=cortex-m0plus
libc=custom

[options]
*:platform=rp2040
```

#### Explanation of Settings

- **`[settings]`**: This section configures the build environment for your code.
- **`build_type`**: Defaults to `MinSizeRel`, optimizing for the smallest
  binary size, which is crucial for embedded applications.
- **`os`**: Always set to `baremetal` for ARM Cortex-M processors, indicating a
  direct hardware operation without a traditional operating system.
- **`arch`**: Specifies the processor architecture. It is essential to consult
  the user manual to identify the correct architecture as variations within the
  same family may exist. For instance, the LPC4078 uses a Cortex-M4F (with
  floating point unit), unlike the LPC4072, which uses a Cortex-M4 (without
  floating point unit). Supported architectures include `cortex-m0`,
  `cortex-m0plus`, `cortex-m1`, `cortex-m3`, `cortex-m4`, `cortex-m4f`,
  `cortex-m7`, `cortex-m7f`, `cortex-m7d`, `cortex-m23`, `cortex-m33`,
  `cortex-m33f`, `cortex-m33p`, `cortex-m35p`, `cortex-m55`, and `cortex-m85`.
- **`libc`**: Should be set to `custom` to accommodate picolibc, which is
  preferable over the default newlib-nano used by the GNU ARM toolchain.

#### Options Section

- **`[options]`**: This section defines library options for the build process.
  It facilitates the selection of specific package options within
  `conanfile.py`.
- **`*:platform=rp2040`**: This setting universally applies the `rp2040`
  platform option across all packages, using `*` as a wildcard to ensure it
  affects all compiled packages.

#### Customizing Your Profile

To tailor this profile for different platforms, replace `rp2040` with the
relevant platform name and adjust `arch` to match the specific CPU architecture
of your device. This customized approach ensures that the build settings are
perfectly aligned with the hardware specifications of the microcontroller you
are working with.

### Using Profile Templates

Conan has the ability to use Jinja templates in its profiles allowing for the composition and expansion of profiles. So if you have a ton of devices in the same family with nearly identical bits of information, you can make a template for them. Check out the following examples:

=== "libhal-lpc40"

    Notice how the only thing that changes between these are the architecture
    and the platform.

    `libhal-lpc40/conan/v2/lpc40`:

    ```
    [settings]
    build_type=MinSizeRel
    os=baremetal
    arch={{ arch }}
    libc=custom

    [options]
    *:platform={{ platform }}
    ```

    `libhal-lpc40/conan/v2/lpc4078`:

    ```
    {% set platform = "lpc4078" %}
    {% set arch = "cortex-m4f" %}
    {% include "lpc40" %}
    ```

    `libhal-lpc40/conan/v2/lpc4072`:

    ```
    {% set platform = "lpc4072" %}
    {% set arch = "cortex-m4" %}
    {% include "lpc40" %}
    ```

=== "libhal-stm32f1"

    The only difference between the chips with respect to the settings and options is just the platform name so the template only needs to be used for the platform variable.

    `libhal-stm32f1/conan/v2/stm32f103`:
    ```
    [settings]
    build_type=MinSizeRel
    os=baremetal
    arch=cortex-m3
    libc=custom

    [options]
    *:platform={{ platform }}
    ```

    `libhal-stm32f1/conan/v2/stm32f103c8`:
    ```
    {% set platform = "stm32f103c8" %}
    {% include "stm32f1" %}
    ```

    `libhal-stm32f1/conan/v2/stm32f103vc`:
    ```
    {% set platform = "stm32f103vc" %}
    {% include "stm32f1" %}
    ```

---

### Directory structure

In order to allow changes into the future, it is advised to put your profiles
in a `v1` or `vN` directory. This way, if there is a significant change between
the profiles into the future, code can still use the original profiles they
used before.

## 🔗 Linker Scripts

Linker scripts play a crucial role in defining the memory layout of embedded
systems. They are used to organize different types of data within the binary,
such as code, initialized data, uninitialized data, read-only data, and thread
local storage. These scripts also outline the memory regions available for the
application.

The finer details about linker scripts and how they work can be found in the
resources below:

- [Mastering the GNU linker script by AllThingsEmbeddd](https://allthingsembedded.com/post/2020-04-11-mastering-the-gnu-linker-script/): Easy to learn 13 min read
- ["The most thoroughly commented linker script (probably)" by Thea "Stargirl" Flowers](https://blog.thea.codes/the-most-thoroughly-commented-linker-script/):
  A very thoroughly documented and easy read on linker scripts
- [GNU Linker Scripts](https://ftp.gnu.org/old-gnu/Manuals/ld-2.9.1/html_chapter/ld_3.html): Full user specification, if you need or want those details

This section will not go into detail about linker scripts but will provide you all of the steps to port your device to libhal platform library.

### Standard Linker Script Template

The `libhal-armcortex` library provides standardized linker script templates,
which can be easily adapted for specific platforms. An example template is
available at:
[`libhal-armcortex/linker_scripts/libhal-armcortex/standard.ld`](https://github.com/libhal/libhal-armcortex/blob/main/linker_scripts/libhal-armcortex/standard.ld).

To utilize these templates, include the following definitions in your linker
scripts directory:

```ld
__flash = 0x00000000;
__flash_size = 64K;
__ram = 0x10000000;
__ram_size = 16K;
__stack_size = 1K;

INCLUDE "libhal-armcortex/standard.ld"
```

The above configuration is an example from the
[`lpc4072`](https://github.com/libhal/libhal-lpc40/blob/main/linker_scripts/libhal-lpc40/lpc4072.ld)
script.

### Customizing Linker Scripts

You need to specify:

- The location and size of the flash memory within the device's address space.
- The location and size of the main RAM.
- The minimum stack size before the build should fail, typically set to `1K`
  for libhal. Adjust this based on available RAM.

Each variation within a chip family, such as those in the LPC40xx series,
requires its own linker script due to differences in flash and RAM sizes:

For example the chips in the LPC40xx series are:

- [lpc4072](https://github.com/libhal/libhal-lpc40/blob/main/linker_scripts/libhal-lpc40/lpc4072.ld)
- [lpc4074](https://github.com/libhal/libhal-lpc40/blob/main/linker_scripts/libhal-lpc40/lpc4074.ld)
- [lpc4076](https://github.com/libhal/libhal-lpc40/blob/main/linker_scripts/libhal-lpc40/lpc4076.ld)
- [lpc4078](https://github.com/libhal/libhal-lpc40/blob/main/linker_scripts/libhal-lpc40/lpc4078.ld)
- [lpc4088](https://github.com/libhal/libhal-lpc40/blob/main/linker_scripts/libhal-lpc40/lpc4088.ld)

Each has their own unique ram and flash amounts.

Similarly, the STM32F10x series has distinct linker scripts for each variant based on flash and RAM requirements, such as:

- [stm32f10xx4.ld](https://github.com/libhal/libhal-stm32f1/blob/main/linker_scripts/libhal-stm32f1/stm32f10xx4.ld)
- [stm32f10xx6.ld](https://github.com/libhal/libhal-stm32f1/blob/main/linker_scripts/libhal-stm32f1/stm32f10xx6.ld)
- [stm32f10xx8.ld](https://github.com/libhal/libhal-stm32f1/blob/main/linker_scripts/libhal-stm32f1/stm32f10xx8.ld)
- [stm32f10xxb.ld](https://github.com/libhal/libhal-stm32f1/blob/main/linker_scripts/libhal-stm32f1/stm32f10xxb.ld)
- [stm32f10xxc.ld](https://github.com/libhal/libhal-stm32f1/blob/main/linker_scripts/libhal-stm32f1/stm32f10xxc.ld)
- [stm32f10xxd.ld](https://github.com/libhal/libhal-stm32f1/blob/main/linker_scripts/libhal-stm32f1/stm32f10xxd.ld)
- [stm32f10xxe.ld](https://github.com/libhal/libhal-stm32f1/blob/main/linker_scripts/libhal-stm32f1/stm32f10xxe.ld)
- [stm32f10xxf.ld](https://github.com/libhal/libhal-stm32f1/blob/main/linker_scripts/libhal-stm32f1/stm32f10xxf.ld)
- [stm32f10xxg.ld](https://github.com/libhal/libhal-stm32f1/blob/main/linker_scripts/libhal-stm32f1/stm32f10xxg.ld)

The STM32F103C8 belongs to the STM32F1 series of microcontrollers, which are
part of the STM32 family of devices from STMicroelectronics. The naming scheme
for this series can be broken down as follows:

- **STM32**: Indicates the family of ARM Cortex-M microcontrollers.
- **F1**: Indicates the series within the STM32 family, specifically the
  STM32F1 series.
- **03**: Indicates the sub-family, which in this case is the STM32F103
  sub-family. The '1' before '03' generally represents the sub-category within
  the series.
- **C**: Indicates the package type and number of pins (e.g., 'C' typically
  indicates an LQFP48 package with 48 pins).
- **8**: Indicates the memory size, specifically the Flash memory size, in this
  case, 64 KB of Flash memory.

All devices in this family have just 20kB of RAM. Thus the only part of the
profile name that matters in terms of determining the appropriate flash size is
the last digit. That digits can be `4`, `6`, `8`, `b`, `c`, `d`, `e`, `f`, `g`,
which is why we have that many linker scripts above. The exact reason why each
number and letter is used is not known to the writer, but is also not
important. All that we need to do is map those profile names to the correct
`.ld` file.

### Handling Multiple Flash and RAM Configurations

Currently, `libhal-armcortex` supports MCUs with single flash and RAM
configurations. For support for multi-flash and multi-RAM devices, consider
contributing or following the development on this GitHub issue:
[Add multi flash & multi ram linker scripts](https://github.com/libhal/libhal-armcortex/issues/16).
In order to communicate to the build system what your linker scripts are and
where to find them, we must add to the conan package's `cpp_info.exelinkflags`
array. This property describes to conan what link flags should be added if a
package depends on this package. See the code below.

### Integrating Linker Scripts into Build Systems

To properly integrate your linker scripts with the Conan build system, add the appropriate link flags to the `cpp_info.exelinkflags` array in your package. This setup ensures that the linker scripts are correctly recognized and used during the build process.

```python
def package_info(self):
    self.cpp_info.set_property("cmake_target_name", "libhal::__platform__")
    self.cpp_info.libs = ["libhal-__platform__"]

    if self.settings.os == "baremetal" and self._use_linker_script:
        self.add_linker_scripts_to_link_flags()

def add_linker_scripts_to_link_flags(self):
    platform = str(self.options.platform)
    self.cpp_info.exelinkflags = [
        "-L" + os.path.join(self.package_folder, "linker_scripts"),
        "-T" + os.path.join("libhal-__platform__", platform + ".ld"),
    ]
```

### Implementing Linker Scripts for Your Platform

#### 1. Download and Review the User Manual

Begin by downloading and reviewing the user manual for your microcontroller.
The datasheet may provide some information, but the user manual will typically
contain a comprehensive memory map. Search for the section labeled "memory map"
to find detailed information about the sizes of the device's flash and RAM.

#### 2. Determine the Naming Scheme

Device naming schemes vary. Some, like the `lpc4078`, have straightforward
names, while others, like the `stm32f10x`, incorporate coded symbols. Establish
a clear naming strategy for your linker scripts. Each profile should correspond
to exactly one linker script, although a single linker script can apply to
multiple profiles if the hardware characteristics are identical.

#### 3. Populate the Linker Script

Fill out the linker script with the specific memory addresses and sizes for
your device:

```ld
__flash = ???;
__flash_size = ???;
__ram = ???;
__ram_size = ???;
__stack_size = 1K;

INCLUDE "libhal-armcortex/standard.ld"
```

#### 4. Repeat for All Variants

Continue this process for each device variant within the chip family, ensuring
that all have appropriate linker scripts reflecting their specific memory
configurations.

#### 5. Update `add_linker_scripts_to_link_flags()` in `conanfile.py`

Modify the `add_linker_scripts_to_link_flags()` function in your `conanfile.py`
to correctly link the appropriate scripts based on the platform:

For devices like the STM32 family, where multiple variants exist, implement a
dynamic approach to link the correct script:

```python
def add_linker_scripts_to_link_flags(self):
    linker_script_name = list(str(self.options.platform))
    # Replace unneeded characters with 'x' to denote a generic script
    linker_script_name[8] = 'x'
    linker_script_name[9] = 'x'
    linker_script_name = "".join(linker_script_name)

    self.cpp_info.exelinkflags = [
        "-L" + os.path.join(self.package_folder, "linker_scripts"),
        "-T" + os.path.join("libhal-stm32f1", linker_script_name + ".ld"),
    ]
```

This adjustment allows you to use a single script for similar variants by
replacing specific parts of the chip identifier with a 'don't care' symbol
('x'). Think of it like bit masking but for letters.

For some devices with XIP (eXecute In Place) external flash memory interfaces
packages can opt to conan's package "option" feature, allowing the user to
specify the size in the command line, their own profile, or set the option
directly in the final application `conanfile.py`.

#### 6. Testing

Once all scripts are in place, it's time to test:

To build the package, run:
```bash
conan create . -pr YOUR_PROFILE -pr arm-gcc-12.3 --version=latest
```

To build your demos, use:
```bash
VERBOSE=1 conan build demos -pr YOUR_PROFILE -pr arm-gcc-12.3
```

On Windows:
```bash
$env:VERBOSE=1 conan build demos -pr YOUR_PROFILE -pr arm-gcc-12.3
```

Ensure verbose output is enabled to check the `-Tyour_linker_script.ld` command
argument during the build process. Verify the binary fits the addresses
specified in the linker script with:

```bash
arm-none-eabi-readelf -S demos/build/YOUR_PROFILE/MinSizeRel/blinker.elf
```

Confirm the `.init` section aligns with the flash address and `.data` with the
RAM address. If these match, your implementation is successful.

!!! error "Troubleshooting"

    If commands do not execute as expected, particularly on Linux or macOS,
    source your environment variables with:

    ```bash
    source demos/build/YOUR_PROFILE/MinSizeRel/generators/conanbuild.sh
    ```

## 🔄 Continuous Integration & Deployment

Continuous Integration (CI) ensures that code in the main branch of any libhal
library—or code intended for the main branch—builds successfully and passes all
tests. This process is crucial for maintaining code quality and functionality
over time.

!!! warning

    The CI system is currently optimized for use within the libhal
    organization. Efforts are underway to enhance its usability for other
    organizations without requiring a fork or clone of the `libhal/ci`
    repository.

### Branch & Pull Request Checks

The `libhal-__platform__` includes a pre-configured
[`ci.yml`](https://github.com/libhal/libhal-__platform__/blob/main/.github/workflows/ci.yml)
GitHub Action script, which provides an overview of our automated testing
approach:

```yaml
on:
  workflow_dispatch:
  pull_request:
  push:
    branches:
      - main
  schedule:
    - cron: "0 12 * * 0"
```

Key Features:

- **Scheduled Tests:** The CI system automatically tests the main branch daily
  to ensure ongoing compatibility and to detect any issues caused by changes in
  other packages or the infrastructure.
- **Pull Request Tests:** All pull requests undergo CI tests to ensure that new
  contributions do not introduce bugs or compatibility issues.
- **Manual Trigger:** The `workflow_dispatch` event allows for manual CI runs
  without needing to push updates or create pull requests.

```yaml
jobs:
  library_checks:
    uses: libhal/ci/.github/workflows/library_check.yml@5.x.y
    secrets: inherit

  deploy_cortex-m4f_check:
    uses: libhal/ci/.github/workflows/deploy.yml@5.x.y
    with:
      arch: cortex-m4f
      os: baremetal
      compiler: gcc
      compiler_version: 12.3
      compiler_package: arm-gnu-toolchain
    secrets: inherit

  deploy_cortex-m4_check:
    uses: libhal/ci/.github/workflows/deploy.yml@5.x.y
    with:
      arch: cortex-m4
      os: baremetal
      compiler: gcc
      compiler_version: 12.3
      compiler_package: arm-gnu-toolchain
    secrets: inherit

  demo_check_profile1:
    uses: libhal/ci/.github/workflows/demo_builder.yml@5.x.y
    with:
      compiler_profile_url: https://github.com/libhal/arm-gnu-toolchain.git
      compiler_profile: v1/arm-gcc-12.3
      platform_profile_url: https://github.com/libhal/libhal-__platform__.git
      platform_profile: v1/profile1
    secrets: inherit

  demo_check_profile2:
    uses: libhal/ci/.github/workflows/demo_builder.yml@5.x.y
    with:
      compiler_profile_url: https://github.com/libhal/arm-gnu-toolchain.git
      compiler_profile: v1/arm-gcc-12.3
      platform_profile_url: https://github.com/libhal/libhal-__platform__.git
      platform_profile: v1/profile2
    secrets: inherit
```

Key Checks:

- **Library Checks:** Ensures packaging in host mode, conducts host side tests,
  verifies API documentation (Doxygen comments), and checks code formatting.
- **Deployment Checks:** Uses `deploy.yml` to simulate the deployment process
  for all `build_type`s such as `Debug`, `MinSizeRel`, and `Release`, without a
  specific `version` input for a dry run.
- **Demo Application Checks:** Ensures demo applications remain functional
  after changes using `demo_builder.yml`. This script should specify the paths
  to compiler and platform profiles, using these to download and build the
  applications.

Each `ci.yml` configuration should include these checks. If a package does not
include demos, the demo check can be omitted, though it is generally
recommended to include demos to demonstrate the library's capabilities.

## 📜 Platform Constants

Now we've reached the point where we can start modifying the C++ source code.
The first area to start with is defining the `peripheral` and `irq` enumeration
class constants. These outline the set of peripherals and interrupt requests
that can be used on the platform.

Here's a guide section for "Peripheral Constants" that you can use in your
documentation. This section explains how to map peripheral identifiers to their
respective power and clock control registers, tailored specifically for an API
like the one you're designing for libhal.

### Peripheral Constants

In the libhal ecosystem, peripheral constants play a crucial role in the power
and clock management APIs. These constants uniquely identify each peripheral
and correspond directly to control bits in the power and clock registers. This
design ensures efficient and straightforward management of peripheral power
states and clock frequencies.

#### Defining Peripheral Constants

Peripheral constants are defined in an enumeration where each constant
corresponds to a specific bit in a device's power or clock enable registers.
This method allows direct manipulation of these registers using bit operations,
which are both fast and memory-efficient.

```C++
namespace hal::your_platform {
  /// List of each peripheral and their power on id number for this platform
  enum class peripheral : std::uint8_t
  {
    // Examples
    gpio = 0,
    uart0 = 1,
    spi1 = 2,
    // More peripherals follow...
    max, // Placeholder for the count of peripherals
  };
}
```

#### Mapping to Power Registers

1. **Locate Power Registers:** First, consult the power management section of
   your microcontroller's user manual. Identify the registers responsible for
   powering peripherals. These are often labeled as power control registers or
   clock enable registers.

2. **Understand Register Layout:** Registers typically control multiple
   peripherals. Each bit in a register corresponds to the power state of one
   peripheral. For instance, bit 0 might control the power for the GPIO
   interface, bit 1 for the UART0, and so on.

3. **Designing the Enumeration:** Define each peripheral in the enum class such
   that the value of the enum matches the bit position in the power register.
   For a microcontroller with two 32-bit power registers:
   - Peripherals controlled by the first register will have IDs 0 to 31.
   - Peripherals controlled by the second register will have IDs 32 to 63.

4. **Bitwise Operations:** With each peripheral ID corresponding directly to a
   bit position, you can toggle power by applying bitwise operations. For
   example, to power on a peripheral, the operation would be:

   ```C++
   power_register |= (1 << static_cast<int>(peripheral::uart0));
   ```

   To power it off:

   ```C++
   power_register &= ~(1 << static_cast<int>(peripheral::uart0));
   ```

#### Example Usage

Consider a scenario where the ADC peripheral is mapped to bit 12 in the power
control register. By defining the `adc` constant as 12 in the enum, you enable
straightforward manipulation:

- **Power On:** `power_register |= (1 << static_cast<int>(peripheral::adc));`
- **Check Power State:** `bool isPowered = power_register & (1 << static_cast<int>(peripheral::adc));`
- **Power Off:** `power_register &= ~(1 << static_cast<int>(peripheral::adc));`

#### Benefits

This mapping strategy ensures that your power and clock management API is both
efficient and easy to use. It reduces the overhead of calculating bit masks and
positions dynamically, leading to faster execution and cleaner code.

This guide section aims to clarify the process of defining and using peripheral
constants within the libhal framework, providing a structured approach to
managing device resources effectively.

!!! note

    Your microcontroller may use multiple bits or have a more complicated
    scheme to power control. If that is the case, then it is up to you to
    determine what is the best scheme for powering on peripheral on the device
    that driver and potentially users can utilize.

### IRQ Constants

It may be useful to understand how ARM Cortex M exceptions work. To learn these
details, we'd highly recommend reading
[A Practical guide to ARM Cortex-M Exception Handling by Chris Coleman of Memfault](https://interrupt.memfault.com/blog/arm-cortex-m-exceptions-and-nvic).

The maximum number of interrupts for Cortex-M series CPUs varies depending on
the specific model within the Cortex-M family. Here is a breakdown of the
maximum interrupt numbers for different Cortex-M series processors:

1. **Cortex-M0/M0+**: Supports up to 32 external interrupts.
2. **Cortex-M3/M4/M7/M33/M35P**: Supports up to 240 external interrupts.
3. **Cortex-M23**: Supports up to 32 external interrupts.

The exact number of interrupts available in a specific microcontroller will
also depend on the chip and the specific features they have included. Consult
the technical reference manual or datasheet for the mcu to get the precise
number of interrupts supported and what they map to.

```C++
// The enum class type must always be `std::int16_t`, representing the
// maximum number of IRQs a Cortex-M processor can support. This type is also
// used for the input parameter that specifies the IRQ number.
enum class irq : std::int16_t
{
  watchdog_timer = 0, // The first IRQ must always be zero
  timer0 = 1,
  timer1 = 2,
  uart0 = 5,
  uart1 = 6,
  pwm1 = 9,
  i2c0 = 10,
  i2c1 = 11,
  i2c2 = 12,
  reserved0 = 13, // Fill gaps with reserved IRQs
  spi0 = 14,
  spi1 = 15,
  pll0 = 16,
  rtc = 17,
  // ... Add the rest...
  max, // The final entry must ALWAYS be "max"
};
```

When referencing your user manual, look for the term **NVIC**, which stands for
**Nested Vector Interrupt Controller**. This is a typical title in ARM MCU
data sheets for where the interrupts IRQs are defined. The NVIC section in the
manual typically includes IRQ numbers for each peripheral. Integrate these
numbers into the enum class, assigning them as corresponding values.
Additionally, you may encounter **ISER**, or **Interrupt Set-Enable Register**,
which is the ARM designation for the register controlling interrupt enabling.

## 🧩 Implementing the core APIs

To be written.

<!--
Here are documents that go over how to implement the following core APIs

- [Implementing Power Control]()
- [Implementing Direct Memory Access]()
- [Implementing a Clock Tree & Clock Configuration]()
- [Implementing Pin Multiplexing]()
-->
