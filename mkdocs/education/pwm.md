# PWM: Pulse Width Modulation

!!! warning
    This document describes the PWM for libhal 5.0.0 which is not out yet.

Welcome to the libhal pwm tutorial. PWM stands for pulse width modulation, a
method of generating a square wave at a particular frequency where the ratio of
time between the signal being ON (HIGH) or OFF (LOW) is determined by a
duty-cycle. The duty cycle can be changed to change that ratio. That ratio can
be used to approximate analog voltages on average and can be used for power
control or transmitting information.

## Learning about PWM

To learn more about PWM, why it exists, and what it can be used for check out
this video by Rohde Schwarz
[Understanding Pulse Width Modulation](https://www.youtube.com/watch?v=nXFoVSN3u-E).
Video time is 13min and goes over much of theory and use cases for PWM.

Here's the improved version of the tutorial on PWM using markdown:

## PWM Interfaces and How to Use Them

The `hal::pwm16` interface in libhal provides a 16-bit PWM (Pulse Width
Modulation) solution, allowing you to control the duty cycle and frequency of a
PWM signal.

The `hal::pwm16` class has the following interface:

```C++
namespace hal {
class pwm16 {
    void frequency(hal::u32 p_frequency_hertz);
    void duty_cycle(hal::u16 p_duty_cycle);
};
}
```

### `hal::pwm16::frequency`

The `frequency` method allows you to set the frequency, in Hertz, of the PWM
waveform. If the requested frequency is outside the supported range of the PWM
hardware, an `hal::argument_out_of_domain` exception will be raised. In
practice, most PWM hardware can support a frequency range between 100 Hz and
100 kHz.

### `hal::pwm16::duty_cycle`

The `duty_cycle` method takes a `hal::u16` value representing the duty cycle of
the PWM signal. The duty cycle is divided into 65,535 (2^16 - 1) parts, where:

- A value of 0 represents a 0% duty cycle (always off)
- A value of 65,535 represents a 100% duty cycle (always on)
- A value of 32,767 represents a 50% duty cycle (equal on and off time)

Other values between 0 and 65,535 will set the duty cycle proportionally.

## PWM Utilities

### `hal::scale_to_u16(range, value)`

Maps the value from the range1 to the range2 to a proportional `hal::u16`.
Here are multiple ways to set the duty cycle to 50%:

```C++
pwm.duty_cycle(hal::scale_to_u16({0, 100}, 50));
pwm.duty_cycle(hal::scale_to_u16({100, 0}, 50));
pwm.duty_cycle(hal::scale_to_u16({.a = 100, .b = 0}, 50));
pwm.duty_cycle(hal::scale_to_u16<0, 100>(50));
pwm.duty_cycle(hal::scale_to_u16<100, 0>(50));
```

If the ranges are known at compile time, use the template version
`hal::scale_to_u16<100, 0>()` of this API as it is more optimal.

The min and max range can be in any order.

```C++
// Increment duty cycle from 0% to 100% in 1% increments
for (int i = 0; i < 100; i++) {
  pwm.duty_cycle(hal::scale_to_u16<0, 100>(i));
  hal::delay(clock, 100ms);
}
```

Generically, there is `scale_to` which can take a type to scale up to.

```C++
// Increment duty cycle from 0% to 100% in 1% increments
for (int i = 0; i < 100; i++) {
  pwm.duty_cycle(hal::scale_to<hal::u16, 0, 100>(i));
  hal::delay(clock, 100ms);
}
```

### `hal::pulse_width(frequency, std::chrono::microseconds)`

Lets consider a situation where a user needs to generate a waveform with a
specific pulse width based on time. RC servos are the classical example of this use case. The API takes a frequency and a duration in microseconds and returns the duty cycle value that will generate that pulse width.

```C++
pwm.duty_cycle(hal::pulse_width(50, 1500us)); // middle position
pwm.duty_cycle(hal::pulse_width(50, 1000us)); // starting position
pwm.duty_cycle(hal::pulse_width(50, 2000us)); // end position
```
