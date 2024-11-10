# 🔗 Interfaces in libhal

## What are Interfaces?

An interface is like a contract between different parts of your program. It
defines what methods a class must implement, without specifying how they should
work. This is powerful because it lets you:

- Write code that works with any hardware that follows the interface
- Switch hardware without changing your application code
- Test your code more easily

For example, if you write code using the `hal::input_pin` interface, it will
work with any microcontroller that provides an implementation of that interface.

## Available Interfaces

### Digital I/O

=== "Input Pin"
    See API:
    [`hal::input_pin`](https://libhal.github.io/4.1/api/libhal/input_pin.html)

    Reads the state of a digital pin (HIGH or LOW). Used for:

    - Reading button presses
    - Detecting digital signals
    - Reading logic levels

=== "Output Pin"
    See API:
    [`hal::output_pin`](https://libhal.github.io/4.1/api/libhal/output_pin.html)

    Controls digital outputs (HIGH or LOW). Used for:

    - Controlling LEDs
    - Sending digital signals
    - Setting logic levels

=== "Interrupt Pin"
    See API:
    [`hal::interrupt_pin`](https://libhal.github.io/4.1/api/libhal/interrupt_pin.html)

    Calls a function when a pin's state changes. Used for:

    - Detecting button presses
    - Responding to external signals
    - Event-driven programming

### Analog Interfaces

=== "ADC (Analog-to-Digital Converter)"
    See API:
    [`hal::adc`](https://libhal.github.io/4.1/api/libhal/adc.html)

    Converts analog signals to digital values. Used for:

    - Reading sensor values
    - Measuring voltages
    - Processing analog inputs

=== "DAC (Digital-to-Analog Converter)"
    See API:
    [`hal::dac`](https://libhal.github.io/4.1/api/libhal/dac.html)

    Converts digital values to analog signals. Used for:

    - Generating analog voltages
    - Controlling analog devices

=== "Stream DAC"
    See API:
    [`hal::dac`](https://libhal.github.io/4.1/api/libhal/dac.html)

    Converts digital values to analog signals. Used for:

    - Generating analog voltages based on a PCM waveform data
    - Generating audio output

=== "PWM (Pulse Width Modulation)"
    See API:
    [`hal::pwm`](https://libhal.github.io/4.1/api/libhal/pwm.html)

    Generates square waves with controllable duty cycle. Used for:

    - Motor speed control
    - LED brightness control
    - Signal generation

### Time Management

=== "Timer"
    See API:
    [`hal::timer`](https://libhal.github.io/4.1/api/libhal/timer.html)

    Schedules future events. Used for:

    - Delayed operations
    - Periodic tasks
    - Timeout management

=== "Steady Clock"
    See API:
    [`hal::steady_clock`](https://libhal.github.io/4.1/api/libhal/steady_clock.html)

    Provides consistent time measurements. Used for:

    - Measuring durations
    - Timing operations
    - Creating delays

### Communication Protocols

=== "SPI"
    See API:
    [`hal::spi`](https://libhal.github.io/4.1/api/libhal/spi.html)

    Fast, synchronous communication protocol. Used for:

    - Communicating with displays
    - Reading memory chips
    - High-speed sensor data

=== "I2C"
    See API:
    [`hal::i2c`](https://libhal.github.io/4.1/api/libhal/i2c.html)

    Two-wire communication protocol. Used for:

    - Connecting multiple sensors
    - Reading small devices
    - Low-speed communication

=== "Serial"
    See API:
    [`hal::serial`](https://libhal.github.io/4.1/api/libhal/serial.html)

    Basic serial communication. Used for:

    - Bi-direction asynchronous communication with a single device
    - Communication with computers

=== "CAN"
    See API:
    [`hal::can`](https://libhal.github.io/4.1/api/libhal/can.html)

    Robust communication bus. Used for:

    - Automotive systems
    - Industrial networks
    - Multi-device communication

### Motion Control

=== "Motor"
    See API:
    [`hal::motor`](https://libhal.github.io/4.1/api/libhal/motor.html)

    Controls open-loop motors. Used for:

    - Basic motor control
    - Fan control
    - Simple actuators

=== "Servo"
    See API:
    [`hal::servo`](https://libhal.github.io/4.1/api/libhal/servo.html)

    Controls position-based motors. Used for:

    - Precise positioning
    - Robotic arms
    - Camera mounts

### Sensors

=== "Temperature Sensor"
    See API:
    [`hal::temperature_sensor`](https://libhal.github.io/4.1/api/libhal/temperature_sensor.html)

    Measures temperature. Used for:

    - Environmental monitoring
    - System protection
    - Process control

=== "Accelerometer"
    See API:
    [`hal::accelerometer`](https://libhal.github.io/4.1/api/libhal/accelerometer.html)

    Measures acceleration in X, Y, Z axes. Used for:

    - Motion detection
    - Orientation sensing
    - Vibration monitoring

=== "Gyroscope"
    See API:
    [`hal::gyroscope`](https://libhal.github.io/4.1/api/libhal/gyroscope.html)

    Measures rotation rates. Used for:

    - Navigation
    - Stabilization
    - Motion tracking

=== "Magnetometer"
    See API:
    [`hal::magnetometer`](https://libhal.github.io/4.1/api/libhal/magnetometer.html)

    Measures magnetic fields. Used for:

    - Compass heading
    - Position detection
    - Metal detection

=== "Distance Sensor"
    See API:
    [`hal::distance_sensor`](https://libhal.github.io/4.1/api/libhal/distance_sensor.html)

    Measures linear distance. Used for:

    - Object detection
    - Range finding
    - Proximity sensing

=== "Rotation Sensor"
    See API:
    [`hal::rotation_sensor`](https://libhal.github.io/4.1/api/libhal/rotation_sensor.html)

    Measures angular position. Used for:

    - Motor position feedback
    - Device orientation tracking
    - Angle measurement

### ⏳ Coming Soon

=== "Current Sensor"
    **API not available yet**

    Measure electrical current flow in circuits. Used for:

    - Calculating battery state of charge
    - Measuring system power consumption
    - Measure motor torque/force

=== "Voltage Sensor"
    **API not available yet**

    Will measure voltage differences in circuits.

=== "GPS"
    **API not available yet**

    Will provide location, time, and velocity data from GPS signals.

## Understanding Virtual Functions in C++

A quick note about virtual functions (which libhal uses extensively):

1. **They don't require heap memory**: Virtual functions work fine with
   stack-allocated objects.
2. **Performance impact is minimal**: The overhead is usually just one pointer
   lookup.
3. **Memory overhead is small**: Each class with virtual functions needs only
   one vtable (shared between all instances).

Example of using virtual functions efficiently:

```cpp
// This works fine - no heap allocation needed
hal::lpc4078::i2c i2c2(2);  // Stack allocated
initialize_display(i2c2);   // Uses virtual functions, but still efficient
```
