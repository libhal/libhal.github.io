# 🧱 Fundamentals of libhal

libhal stands for "Hardware Abstraction Layer Library". The libhal library just
contains a set of C++ interfaces for the various common hardware devices. If a
developer wants to turn off and on an LED, then the user can simply construct a
`hal::output_pin` and use the `level(bool)` API to turn the pin's voltage from
high to low. The developer using that output pin does not need to know:

1. How to power-on/enable the pin for the platform or device it comes from
2. How to enable timing for the peripheral (if relevant)
3. Which registers need to be modified to change the pin direction
4. Which registers need to be modified to change the pin state

All of the above in the list be taken care of by the driver implementation.
This allows applications and driver implementations to be decoupled from each
other, allowing them to follow the semantics of the interface. The application
and drivers can simply use it as specified by the output pin API documentation.

## Interfaces

Interfaces are the basic building blocks of libhal and enable the flexibility
needed to be portable. An interface is a set of required functions that an
implementing class must adhere to. Any software that implements (inherits) an
interface must provide implementations for each function in the interface,
otherwise the compiler will generate a compiler error. The implementation must
follow the rules of the interface as specified in the interface's API
documentation. These API documentation represents the semantics and behavior of
the driver.

Lets consider an input pin, which is a pin on the controller that can be read
by software. The state of the pin can be TRUE or FALSE, which corresponds to a
HIGH or LOW voltage.

```C++
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

As you can see there are two APIs, `configure` which is used to configure the
pin and `level` which is used to read back the voltage level state of the pin.

!!! note "Why the private virtual functions?"

    libhal uses the private virtual, public class function design pattern for
    inferfaces, because it allows us the capability to add supporting code
    before and after the virtual call. This can be used to fix bugs, issues, or
    remove undefined behavior for the virtual calls, for all callers without
    having to request that application or library developers update their code.

One of the key advantages of using interfaces is the ability to write functions
that can work with any implementation of an interface. This is done by writing
functions that accept pointers or references to the base interface class.

For example, you can pass a specific driver implementation to a function that
takes a pointer or reference to the base class `input_pin`:

```C++
void process_pin(input_pin& pin)
{
  pin.configure({ .resistor pin_resistor::pull_up });

  if (pin.level()) {
    // Do something when the pin is HIGH
  } else {
    // Do something when the pin is LOW
  }
}

// Somewhere else in your code
concrete_input_pin my_pin; // This is your specific driver implementation
// This works because concrete_input_pin inherits from input_pin
process_pin(my_pin);
```

This is possible because `concrete_input_pin` inherits from `input_pin`, and C++
allows passing derived class objects to functions that accept base class
pointers or references. This concept is known as **polymorphism**, and it allows
your code to be more flexible and reusable.

## Driver Types

### Peripheral Drivers

Drivers for a platform that is embedded within the platform, system,
development board, or operating system. For micro-controllers these
peripherals  therefore cannot be removed from the chip and is generally fixed
in number.

- output pin
- i2c
- can
- serial/uart

### Device Drivers

Drivers for devices external to a platform. Device drivers have constructors
accepting libhal interface implementations. In order to construct the device
driver all of the interface requirements of the driver must be met, either by a
peripheral driver or a device driver that is capable of generating additional
drivers.

- temperature sensor
- motor controller
- smart servo
- gps

### Soft Drivers

Drivers that do not have any specific underlying hardware associated with them.
They are used to emulate, give context to, or alter the behavior of a driver or
interface implementation.

- bit bang i2c using two output pins (that are open drain capable)
- input pin inverter
- output pin inverter
- minimum speed i2c (a wrapper for i2c that ensures the i2c configuration
  speed is the minimum required to work for all devices using it.)

## libhal libraries/package categories

libhal has many types of libraries. This is due to the wide range of useful
types of libraries in embedded systems.

### Compiler Package

A compiler package downloads and setups up a compiler for general use by an
application. libhal's provides a compiler package for the ARM GNU toolchain
which provides all of the GNU GCC compiler commands for building application,
binaries and library files.

### Platform Library

Contain the drivers and APIs specific to a processor. For example, ARM Cortex M
processors have a common way to manage interrupts, so that code should be put
into the processor library. Almost all Cortex M processors have a SysTick
Timer, so such a driver should exist in the processor library.

Platform libraries also contain peripheral driver implementations as well as
target specific APIs for operations such as DMA transfers, pin configuration
and function selection, clock control, etc, for a specific family of devices.

Peripherals are devices within a microcontroller or computer system that allows
the controller:

1. To interact with the world in a particular way such as:
    1. output pin
    2. input pin
    3. i2c
    4. serial
    5. can
    6. usb
2. Interrupt the CPU when an event has occurred
    1. timers
    2. interrupt pin
    3. watchdog
3. Perform work for the CPU/application
    1. real time clocks
    2. crc generators
    3. random number generator
    4. display graphics accelerator

The hardware implementations of a peripheral in a controller is typically
unique to that controller's device family. The peripheral drivers provide an
abstraction to the peripheral hardware and allows easy control of the driver in
code. Peripheral drivers are developed for peripheral devices that are
expectation to be in all or a subset of devices within a device family.

Platform drivers are the foundation of all libhal applications. These drivers
provide a direct means to access hardware. They are used either directly by an
application OR passed to another driver to perform some work. If you want to
turn on an LED, you'll need to utilize an output pin. If you wanted to interact
with a temperature sensor that communicates over i2c, then you'd need a
peripheral driver that supports i2c. From the peripheral drivers, all other
drivers can be constructed. The question then becomes, does the chip you want,
have the peripherals you'd like to use for your application.

Peripheral drivers typically do not take libhal interfaces as inputs.

### Device Library

Device libraries containing drivers for specific hardware devices or modules,
such as a sensors, displays, or a motor controllers. Device libraries require
resources from the platform, typically peripheral drivers, memory (ram), and/or
drivers that come from other device libraries. Device drivers are generally
platform agnostic and should be usable on any system that can support their
driver, memory, and performance requirements. You can generally tell something
is a device driver if its constructor takes one or more libhal interfaces.

#### Soft Device Library

Soft drivers are drivers that do not have any specific underlying hardware
associated with them. They are used to emulate, give context to, or alter the
behavior of interfaces. For a driver to be a soft driver it must implement or
have a way to generate, construct or create implementations of hardware
interfaces.

For example, one could emulate i2c by using two output_pins set to the open
drain configuration to enable bi-directional communication.

Another example would be an input_pin inverter that takes a `hal::input_pin`
and simply inverts the logic of the values read from the input pin to suite the
needs of another library that expects the values to be a certain logic level.

And finally, thread-safe variants of `hal::i2c` can be made by passing a
`hal::i2c` and a lock to the thread safe i2c implementation and allowing that
implementation to lock the i2c resource while a thread is using it.

### Utility Library

These libraries are purely software-based and do not directly interact with
hardware. They provide useful utilities, data structures, algorithms, and other
software components that can be used across different parts of an application.
Examples might include an efficient circular buffer implementation, a data
structure for facilitating cross-driver communication, or a driver that
performs a specific algorithm on data. These libraries are platform-agnostic
and can be used in any application that meets their requirements.

### 3rd Party library

3rd party libraries that make a compiled library available for libhal targets
processors. Examples of this would be:

- freertos
- lwip
- Elm Chan's FatFS

These are different from what is usually provided on the conan center which are
header only libraries which can work anywhere so long as the APIs and
constructs are also supported by the architecture and compiler. For example
if a header only library uses the C++ `<thread>` APIs and the compiler and
architecture doesn't have support for that, then a compiler or linker error
will occur.

### RTOS Library

RTOS stands for Real Time Operating System and using these libraries will
enable multi-tasking and multi-threading capability to the application. libhal
specific RTOS libraries typically provide helper objects and classes that
support libhal interfaces and systems.

### Process Libraries

Code that performs some work using a set of resources provided by the
application. These aren't driver in that they use drivers to achieve a goal.
Typically implemented as a function but could be an object as well.

Some ideas for what this could be:

- Sensor fusion process that produces orientation information when supplied N
  number of accelerometer, gyroscope, and produces accurate orientation
  information.
- A servo process that takes a motor, a rotational sensor, and function that
  can be called by the process to get its current rotational orientation.

## Concrete Drivers

In libhal, not all drivers are designed to implement an interface. These
drivers, referred to as "Concrete Drivers", are unique in that they typically do
not contain virtual functions and cannot be passed in a generic form. Despite
this, they play a crucial role in the library due to their specific
functionality and support for certain hardware components.

Concrete Drivers are fully realized classes that provide direct, specific
functionality. They are designed to interact with a particular piece of hardware
or perform a specific task, and their methods provide a direct interface to that
hardware or task. Because they do not implement an interface, they cannot be
used polymorphically like other drivers in libhal. However, their specificity
allows them to provide robust, efficient, and direct control over their
associated hardware.

These drivers are particularly useful in scenarios where a specific piece of
hardware or a specific task does not neatly fit into one of the existing libhal
interfaces, or when the overhead of virtual functions is not desirable. Despite
not conforming to a specific interface, Concrete Drivers adhere to the same
design principles as other components of libhal, ensuring consistency and
reliability across the library.

In libhal, not all drivers are designed to implement an interface. These
drivers, referred to as "Concrete Drivers", are unique in that they typically do
not contain virtual functions and cannot be passed in a generic form. Despite
this, they play a crucial role in the library due to their specific
functionality and support for certain hardware components.

Note that this isn't a distinct type outside of the list of Driver types
mentioned above. Concrete drivers can be a peripheral, device and soft driver.
They simply do not implement an interface.

### Multi-Interface Support

Many concrete drivers have the capability to support multiple interfaces at
once. For example, a driver for the RMD-X6 smart motor can act as a servo, a
motor, a temperature sensor (for itself), a voltage sensor (for the bus it is
connected to), a current sensor (for how much current it's consuming), and a
rotation sensor (for its output shaft's position). To create these drivers from
the concrete driver, an adaptor class must be used. These adaptor classes take
a reference to the concrete class and use its methods in order to implement the
interface APIs.

Multi-inheritance MUST NEVER BE USED TO ACHIEVE THIS. This has to do with how
multi-inheritance of polymorphic types effects the vtable of a type and how the
interfaces put additional requirements on the exposed APIs of a clas.

#### Adaptor Factory Functions

In libhal, there is a common language policy for adaptors. To create them you
must call a factory function called `make_<name of interface>()` and it will
return an `adaptor_object`. There is an overload for every driver
that implements a particular interface. For example, in order to generate a
servo from the RMD X6 smart actuator, it would look like this:

```C++
hal::rmd::drc my_smart_actuator(/* ... */);
auto smart_servo_driver = make_servo(my_smart_servo);
```

This approach allows for a consistent and efficient way to create adaptors for
various interfaces from a single concrete driver. It ensures that the concrete
driver can be utilized to its full potential, providing access to all its
capabilities through the appropriate interfaces.
