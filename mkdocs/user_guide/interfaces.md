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
    `hal::input_pin`

    Reads the state of a digital pin (HIGH or LOW). Used for:

    - Reading button presses
    - Detecting digital signals
    - Reading logic levels

=== "Output Pin"
    `hal::output_pin`

    Controls digital outputs (HIGH or LOW). Used for:

    - Controlling LEDs
    - Sending digital signals
    - Setting logic levels

=== "Awaitable Pin"
    `hal::awaitable_pin`

    Waits for a pin's state to transition. Used for:

    - Detecting button presses
    - Responding to external signals
    - Event-driven programming

### Analog Interfaces

=== "ADC 16-bit"
    `hal::adc16`

    Converts analog signals to 16-bit digital values. Used for:

    - Reading sensor values
    - Measuring voltages
    - Processing analog inputs

=== "ADC 24-bit"
    `hal::adc24`

    Converts analog signals to 24-bit digital values. Used for:

    - High-precision sensor readings
    - Precise voltage measurement
    - Processing high-resolution analog inputs

=== "DAC 16-bit"
    `hal::dac16`

    Converts 16-bit digital values to analog signals. Used for:

    - Generating analog voltages
    - Controlling analog devices
    - Audio output

=== "PWM Channel"
    `hal::pwm16_channel`

    Generates square waves with controllable duty cycle. Used for:

    - Motor speed control
    - LED brightness control
    - Signal generation

=== "PWM Group Manager"
    `hal::pwm_group_manager`

    Manages frequency for multiple PWM channels. Used for:

    - Controlling frequency of PWM groups
    - Synchronizing multiple channels

### Time Management

=== "Steady Clock"
    `hal::steady_clock`

    Provides consistent time measurements. Used for:

    - Measuring durations
    - Timing operations
    - Creating delays

### Communication Protocols

=== "SPI Channel"
    `hal::spi_channel`

    Fast, synchronous communication protocol with manual chip select. Used for:

    - Communicating with displays
    - Reading memory chips
    - High-speed sensor data

=== "I2C"
    `hal::i2c`

    Two-wire communication protocol. Used for:

    - Connecting multiple sensors
    - Reading small devices
    - Low-speed communication

=== "Serial"
    `hal::serial`

    Asynchronous serial communication with buffering. Used for:

    - Bi-directional communication with a single device
    - Communication with computers
    - UART, RS232, RS485 protocols

=== "Awaitable Serial"
    `hal::awaitable_serial`

    Serial communication with RX event notifications. Used for:

    - Awaiting receive events
    - Idle detection on RX line
    - Coroutine-based serial handling

=== "CAN"
    `hal::can` with `hal::can_message`

    Robust communication bus protocol. Used for:

    - Automotive systems
    - Industrial networks
    - Multi-device communication

### Motion Control

=== "Motor"
    `hal::motor`

    Controls open-loop rotational actuators. Used for:

    - Basic motor control
    - Fan control
    - Simple actuators

=== "Basic Servo"
    `hal::basic_servo`

    Controls servo position without feedback. Used for:

    - Simple positional control
    - Basic servo applications

=== "Feedback Servo"
    `hal::feedback_servo`

    Controls servo with position and motion feedback. Used for:

    - Precise positioning with feedback
    - Detecting motion status
    - Position-aware servo control

=== "Velocity Servo"
    `hal::velocity_servo`

    Controls servo with variable velocity. Used for:

    - Speed-controlled positioning
    - Velocity-based servo applications

=== "Torque Servo"
    `hal::torque_servo`

    Controls servo with torque feedback. Used for:

    - Force-sensitive applications
    - Load-aware servo control

=== "Veltor Servo"
    `hal::veltor_servo`

    Controls servo with velocity and torque feedback. Used for:

    - Advanced servo control
    - Force and speed-aware applications

### Sensors

=== "Temperature Sensor"
    `hal::temperature_sensor`

    Measures temperature. Used for:

    - Environmental monitoring
    - System protection
    - Process control

=== "Accelerometer"
    `hal::accelerometer`

    Measures acceleration in X, Y, Z axes. Used for:

    - Motion detection
    - Orientation sensing
    - Vibration monitoring

=== "Gyroscope"
    `hal::gyroscope`

    Measures angular velocity in X, Y, Z axes. Used for:

    - Navigation
    - Stabilization
    - Motion tracking

=== "Magnetometer"
    `hal::magnetometer`

    Measures magnetic field strength in X, Y, Z axes. Used for:

    - Compass heading
    - Position detection
    - Metal detection

=== "Distance Sensor"
    `hal::distance_sensor`

    Measures linear distance. Used for:

    - Object detection
    - Range finding
    - Proximity sensing

=== "Rotation Sensor"
    `hal::rotation_sensor`

    Measures angular position (revolutions). Used for:

    - Motor position feedback
    - Device orientation tracking
    - Angle measurement

=== "Current Sensor"
    `hal::current_sensor`

    Measures electrical current flow in circuits. Used for:

    - Calculating battery state of charge
    - Measuring system power consumption
    - Motor force/torque estimation

=== "Voltage Sensor"
    `hal::volt_sensor`

    Measures voltage differences in circuits. Used for:

    - Battery voltage monitoring
    - Supply voltage measurement
    - Power supply diagnostics

=== "Angular Velocity Sensor"
    `hal::angular_velocity_sensor`

    Measures angular velocity (degrees per second). Used for:

    - Rotational speed measurement
    - Rotation rate sensing

### ⏳ Coming Soon

=== "GPS"
    **Interface not yet available**

    Will provide location, time, and velocity data from GPS signals.
