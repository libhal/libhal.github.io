<div align="center">
<img style="height:200px" src="https://raw.githubusercontent.com/libhal/.github/main/profile/logo.png">
<h1>Welcome to libhal</h1>
</div>

## Abstract

libhal exists to make hardware drivers **🚚 portable**, **🦾 flexible**,
**📦 accessible**, and **🍰 easy to use**. libhal seeks to provide a foundation
for embedded drivers, allowing those drivers to be used across different
processors, microcontrollers, systems, and devices.

The design philosophy of libhal is to be:

1. Portable & Cross Platform
2. General
3. Fast & Compact
4. Minimalist
5. Safe, Reliable, Tested & Testable
6. Build Time Conscious
7. OS Agnostic

## The Basics

libhal, at its core, is simply a set of interfaces that correspond to hardware
devices and peripherals. These interfaces use runtime polymorphism in order to
decouple application logic from driver implementation details. This decoupling
enables applications to run on any platform device that has the necessary
components available.

A quick example is a blinker program. You want to turn on and off an LED at a
fixed interval. This would require something along the lines of a GPIO and a
timer to tell time. In libhal we can use drivers that implement the
`hal::output_pin` and `hal::steady_clock` interfaces. Such code would look like
the following and would support the `lpc4078`, `stm32f103c8`, and devices
supported by the `libhal-micromod` project.

=== "include/resource_list.hpp"

    ```C++
    #pragma once

    #include <libhal/functional.hpp>
    #include <libhal/output_pin.hpp>
    #include <libhal/serial.hpp>
    #include <libhal/steady_clock.hpp>

    struct resource_list
    {
      hal::callback<void()> reset;
      hal::output_pin* status_led;
      hal::serial* console;
      hal::steady_clock* clock;
    };

    resource_list initialize_platform();
    ```

=== "main.cpp"

    ```C++
    #include <libhal-util/steady_clock.hpp>

    #include <resource_list.hpp>

    resource_list resources{};

    int main()
    {
      try {
        resources = initialize_platform();
      } catch (...) {
        while (true) {
          // halt here and wait for a debugger to connect
          continue;
        }
      }

      hal::output_pin& led = resources.led;
      hal::steady_clock& clock = resources.clock;

      for (int i = 0; i < 10; i++) {
        // Turn on LED
        led.level(true);
        hal::delay(clock, 500ms);
        // Turn off LED
        led.level(false);
        hal::delay(clock, 500ms);
      }
    }
    ```

=== "platform/stm32f103c8.hpp"

    ```C++
    #include <libhal-arm-mcu/dwt_counter.hpp>
    #include <libhal-arm-mcu/stm32f1/clock.hpp>
    #include <libhal-arm-mcu/stm32f1/constants.hpp>
    #include <libhal-arm-mcu/stm32f1/output_pin.hpp>
    #include <libhal-arm-mcu/stm32f1/uart.hpp>
    #include <libhal-arm-mcu/system_control.hpp>

    #include <resource_list.hpp>

    resource_list initialize_platform()
    {
      using namespace hal::literals;

      // Set the MCU to the maximum clock speed
      hal::stm32f1::maximum_speed_using_internal_oscillator();

      static hal::cortex_m::dwt_counter counter(
        hal::stm32f1::frequency(hal::stm32f1::peripheral::cpu));

      static hal::stm32f1::uart uart1(hal::port<1>,
                                      hal::buffer<128>,
                                      hal::serial::settings{
                                        .baud_rate = 115200,
                                      });

      static hal::stm32f1::output_pin led('C', 13);

      return {
        .reset = +[]() { hal::cortex_m::reset(); },
        .status_led = &led,
        .console = &uart1,
        .clock = &counter,
      };
    }
    ```

=== "platform/micromod.hpp"

    ```C++
    #include <libhal-micromod/micromod.hpp>

    #include <resource_list.hpp>

    resource_list initialize_platform()
    {
      using namespace hal::literals;

      hal::micromod::v1::initialize_platform();

      return {
        .reset = +[]() { hal::micromod::v1::reset(); },
        .status_led = &hal::micromod::v1::led(),
        .console = &hal::micromod::v1::console(hal::buffer<128>),
        .clock = &hal::micromod::v1::uptime_clock(),
      };
    }
    ```

=== "platform/lpc4078.hpp"

    ```C++
    #include <libhal-arm-mcu/dwt_counter.hpp>
    #include <libhal-arm-mcu/lpc40/clock.hpp>
    #include <libhal-arm-mcu/lpc40/constants.hpp>
    #include <libhal-arm-mcu/lpc40/output_pin.hpp>
    #include <libhal-arm-mcu/lpc40/uart.hpp>
    #include <libhal-arm-mcu/startup.hpp>
    #include <libhal-arm-mcu/system_control.hpp>

    #include <resource_list.hpp>

    resource_list initialize_platform()
    {
      using namespace hal::literals;

      // Set the MCU to the maximum clock speed
      hal::lpc40::maximum(12.0_MHz);

      auto cpu_frequency = hal::lpc40::get_frequency(hal::lpc40::peripheral::cpu);
      static hal::cortex_m::dwt_counter counter(cpu_frequency);

      static std::array<hal::byte, 64> receive_buffer{};
      static hal::lpc40::uart uart0(0,
                                    receive_buffer,
                                    hal::serial::settings{
                                      .baud_rate = 115200,
                                    });

      static hal::lpc40::output_pin led(1, 10);

      return {
        .reset = +[]() { hal::cortex_m::reset(); },
        .status_led = &led,
        .console = &uart0,
        .clock = &counter,
      };
    }
    ```

## Support

- [libhal discord](https://discord.gg/p5A6vzv8tm) server (preferred)
- [GitHub issues](https://github.com/libhal/libhal/issues)
- [Cpplang Slack](https://cpplang.slack.com/) #embedded channel

## Distribution

- [Conan](https://conan.io/center/libhal) package manager
- Source code is hosted on [GitHub](https://github.com/libhal/libahl)

# Sponsorships

---

![JFrog
Logo](https://speedmedia.jfrog.com/08612fe1-9391-4cf3-ac1a-6dd49c36b276/https://media.jfrog.com/wp-content/uploads/2021/10/27101222/jfrog-logo_cmm.svg){ align=left }

We are proud to be sponsored by [JFrog](https://jfrog.com/). JFrog generously
provides us with free artifact management, security, and CI/CD tools, allowing
us to focus on the success of our project.

We are grateful for their support and contribution to the open source community.
Thank you, JFrog!

For more information about JFrog's community initiatives, visit their [Giving
Back](https://jfrog.com/community/giving-back/) page.

---
