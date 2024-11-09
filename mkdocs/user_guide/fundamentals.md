# 🧱 Fundamentals of libhal

## What is libhal?

libhal (Hardware Abstraction Layer Library) is a C++ library that provides clean interfaces for working with hardware devices. Think of it as a translator between your code and the actual hardware - you write simple commands, and libhal handles all the complex hardware-specific details.

For example, to control an LED, you just need to:

```cpp
// Create an output pin and control it
hal::output_pin led_pin = /* ... */;
led_pin.level(true);  // Turn LED on
led_pin.level(false); // Turn LED off
```

You don't need to worry about:

- Power management
- Timer configurations
- Register settings
- Platform-specific initialization

## 💡 Core Concepts

### Platforms

Platforms are devices that can execute code on. This can be a microcontrollers or operating system such as Linux. Some microcontrollers we currently support would be:

- lpc40xx
- stm32f10x
- stm32f411re
- RP2040/rp2350 (coming soon)

### Interfaces

Interfaces are the foundation of libhal. They define a set of functions that any implementing class must provide. Think of them as a contract - if a class implements an interface, it promises to provide all the functionality specified by that interface.

Here's a simple example of an input pin interface:

```cpp
class input_pin
{
public:
  struct settings
  {
    pin_resistor resistor = pin_resistor::none;
  };

  void configure(settings const& p_settings) { driver_configure(p_settings); }
  [[nodiscard]] bool level() { return driver_level(); }

  virtual ~input_pin() = default;
private:
  virtual void driver_configure(settings const& p_settings) = 0;
  virtual bool driver_level() = 0;
};
```

This interface can be used like this:

```cpp
void use_input_pin(input_pin& pin)
{
  if (pin.level()) {
    // Do something when the pin is HIGH
  } else {
    // Do something when the pin is LOW
  }
}

// Use it with any input pin implementation
hal::stm32f103::input_pin my_pin('B', 2);
use_input_pin(my_pin);
```

### Driver Types

libhal has three main types of drivers:

1. **Peripheral Drivers**
    - Built into the microcontroller
    - Examples: pins, I2C, SPI, UART, ADC
    - Form the foundation for communicating with external devices
    - Fixed in number (you can't add more than what's built into the chip)

2. **Device Drivers**
    - Control external hardware
    - Examples: sensors, motor controllers, displays
    - Require peripheral drivers to communicate
    - Example usage:

    ```cpp
    // Using an I2C peripheral to communicate with an MPU6050 sensor
    hal::stm32f103::i2c i2c_bus(1);
    hal::sensor::mpu6050 imu(i2c_bus);
    auto data = imu.read_accelerometer();
    ```

3. **Soft Drivers**
    - Pure software implementations that emulate interfaces
    - Examples:
        - Creating I2C using GPIO pins
        - Input/output pin inverters
        - Thread-safe wrapper drivers

### Device Managers

Some complex devices need special handling. Device managers are classes that can provide multiple types of functionality:

```cpp
// Example: RMD smart servo that provides multiple capabilities
hal::rmd::drc smart_servo(/* ... */);

// Get different interface implementations from the same device
auto position_control = smart_servo.servo();
auto temperature_sensor = smart_servo.temperature_sensor();
auto voltage_sensor = smart_servo.voltage_sensor();
```

## 📚 Library Categories

libhal provides several types of libraries:

1. **Platform Libraries**
    - Provide drivers for specific microcontrollers
    - Handle hardware-specific details
    - Example: STM32F1 library with its pin, I2C, and UART implementations

2. **Device Libraries**
    - Drivers for external hardware
    - Platform-independent
    - Example: Temperature sensor library that works on any platform with I2C

3. **Utility Libraries**
    - Pure software utilities
    - Platform-independent helpers
    - Examples: Buffer implementations, algorithms, data structures

4. **RTOS Libraries**
    - Enable multi-tasking capabilities
    - Provide threading and synchronization
    - Help manage shared resources

5. **Process Libraries**
    - Implement specific functionality using drivers
    - Example: Sensor fusion combining accelerometer and gyroscope data

## ⭐️ Best Practices

1. **Use Interfaces**: Write code that works with interfaces rather than
   specific implementations when possible. This makes your code more portable.
2. **Resource Management**: Make sure device manager objects outlive any
   drivers created from them.
3. **Driver Selection**: Use the simplest driver type that meets your needs.
   Start with peripheral drivers and build up to more complex solutions only
   when needed.
