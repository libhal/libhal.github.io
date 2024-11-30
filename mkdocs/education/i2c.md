# I2C: Inter-Integrated Circuit

Welcome to the libhal i2c tutorial. This article will go over:

- What i2c is
- libhal's i2c interface & basic usage
- Utility functions for i2c
- How to use drivers that use i2c
- How to write an i2c device driver
- High level steps to write an i2c peripheral driver

This tutorial only works with i2c controllers (also known as masters). Target (or slave) i2c will not be discussed here.

## What is i2c?

In order to proceed to the rest of this article, you must understand the
fundamentals of i2c and how it works. Rather than rehash what is already out
there, please read one of the following:

- [🎥 Understanding I2C by Rohde Schwarz](https://www.youtube.com/watch?v=CAvawEcxoPU): 10min 57sec A great video describing how I2C works.
- [📄 Sparkfun I2C](https://learn.sparkfun.com/tutorials/i2c/all): A quick and
  concise article that provides enough information to be ready for the rest of
  this tutorial.
- [🌐 i2c-bus.org](https://www.i2c-bus.org/): Website dedicated to documenting
  how i2c works. If you want to get into the depths of I2C, this website does a
  great job of going into how the I2C protocol works as well as some of its
  other less known features such as multi-controller and clock stretching.
- [📄 TI's A Basic Guide to I2C](https://www.ti.com/lit/an/sbaa565/sbaa565.pdf):
  Detailed and contains examples of how an i2c transaction works with concrete
  examples with actual i2c device register maps.

## `hal::i2c` interface and how to use it

The interface that provides APIs for i2c communication is
[`hal::i2c`](https://github.com/libhal/libhal/blob/main/include/libhal/i2c.hpp).
It provides two APIs `configure` and `transaction`.

### Creating an i2c object

Each platform that supports i2c will have their own i2c driver. Typically the name goes like: `hal::<platform_name>::i2c` or `hal::<platform_name>::dma_i2c`.

```C++
// LPC40xx i2c driver for i2c bus 2
hal::lpc40::i2c i2c(2);
// stm32f1xx i2c driver for i2c bus 1
hal::stm32f1::i2c i2c(1);
```

To know what your platform has available you'll need to look at the API docs and search for `i2c` or look at what inherits `hal::i2c`.

!!! warning
    The API docs are not available currently. Consider looking at the source code of the libraries for files with the name `i2c.hpp` or `dma_i2c.hpp` to find your platform's i2c drivers.

### Using `hal::i2c::configure`

This API takes a const reference to the `hal::i2c::settings` structure as an input. It currently only contains a single field which is the `clock_rate`. This field allows the application developer or drivers to change the frequency that the i2c peripheral communicates at.

```C++
struct settings
{
  /**
   * @brief The serial clock rate in hertz.
   *
   */
  hertz clock_rate = 100.0_kHz;
};
```

The `clock_rate` field defaults to 100kHz which is the standard frequency for
i2c. The majority of i2c devices will support 100kHz which makes it a decent
default. Fast mode i2c can operate at 400kHz. Fast mode plus can operate at
1MHz. High speed mode can go up to 3.4MHz. 100kHz to 1MHz are the most common
frequency ranges.

**What value should you set this to?** In general, you want your communication
to be as fast as possible so your code isn't stuck waiting for the transfer to
happen. The higher the frequency the less time it takes to transmit or receive
data. But if your bus has multiple devices with different max frequencies, you
MUST choose the frequency of the device with the lowest frequency. This is due
to how all devices must look at the same i2c bus lines to determine if they
have been selected for a transaction, and if the frequency is too fast for them
to sample, then they will either not respond or potentially respond
incorrectly, leading to errors such as "device not found" or I/O errors.

### Using `hal::i2c::transaction`

In order to communicate with an i2c you must perform an i2c transaction where you specify the device you want to talk to, the data you want to send to it and the amount of data you want back from it. There are 3 types of transactions:

1. `Write`: Where the controller writes to the device and get nothing back in return.
2. `Read`: Where the controller reads from a device.
3. `Write-then-Read`: Where the controller performs a write operation then performs a read operation.

!!! info
    Most i2c devices will use `Write` and `Write-then-Read` operations. A lone `Read` operation is very rare. Typically write operations are used to write data or configuration settings to a device. `Write-then-read` operations are used for reading data from most devices. The write phase of the operation `Write-then-read` is used to tell the device "what" data you want to read, then performing a read operation to read the data back out. The "what" for most devices is usually an address of a register you want to read. Most i2c devices are memory mapped in this way.

    Some devices cannot support `Write-then-Read` and thus they need the `Write` and `Read` operations to be separate.

    An example of a device with a `Read` operation without a `Write` would be the i2c mux [tca9548a](https://cdn-shop.adafruit.com/datasheets/tca9548a.pdf). In this case, there is only 1 register you can write to or read from, thus the "what" for each transaction is just that register.

```C++
void transaction(hal::byte p_address,
                 std::span<hal::byte const> p_data_out,
                 std::span<hal::byte> p_data_in,
                 hal::function_ref<hal::timeout_function> p_timeout)
```

Lets break down each of the input parameters:

- **p_address**: is a byte sized parameter that represents the 7-bit i2c
  address of the device you want to communicate with. To perform a transaction
  with a 10-bit address, this parameter must be the address upper byte of the
  10-bit address OR'd with `0b1111'0000` (the 10-bit address indicator). The
  lower byte of the address must be contained in the first byte of the
  `p_data_out` span buffer.
- **p_data_out**: data to be written to the addressed device. Set this to a
  span with `size() == 0` in order to skip writing.
- **p_data_in**: buffer to store read data from the addressed device. Set
  this to a span with `size() == 0` in order to skip reading.
- **p_timeout**: A function that must throw the type `hal::timed_out` or a
  derivation of `hal::timed_out` when the deadline for this operation has
  exceeded its time. The i2c driver implementation must poll this function to
  ensure it is within the function's deadline.

!!! question
    Unfamiliar with C++'s `std::span` standard library? Read the article
    [How to use std::span from C++20](https://www.cppstories.com/2023/span-cpp20/) to learn!

Here is what a `Write-then-Read` transaction looks like:

```C++
#include <array>
#include <libhal/i2c.hpp>

void write_then_read(hal::i2c& i2c) {
  std::array<hal::byte, 1> status_register_address = { 0x01 };
  std::array<hal::byte, 1> status_register_contents{};
  i2c.transaction(0x14,
                  status_register_address,
                  status_register_contents,
                  hal::never_timeout());
}
```

In this scenario we want to talk to the device with address `0x14`, the first
parameter. We pass the array `status_register_address` which implicitly
converts into a `std::span` as the second parameter. In this case the value of
`0x01` is the address of the register we want to read from. Next is the
`status_register_contents` array which has size 1. This will cause the i2c read
to read back a single byte from this register. If multiple bytes are needed for
the read operation, then the size of the array can be increased to read
additional bytes. Finally, the last argument for the timeout function is
`hal::never_timeout()` which returns a timeout function that never throws
`hal::timed_out`. This is useful for devices that do not perform clock
stretching. For `Write-then-Read` transactions, the i2c implementation must handle automatically performing the write operation first, then performing a restart-read operation.

The purpose of `p_timeout` is to be used when a target device supports clock
stretching. In these situations, it may not be well defined how long the device
will hold the clock lines down for, which can stall a controller if its waiting
for the i2c bus to come back online before the code can proceed. This argument
function allows an escape hatch to return control from the i2c implementation
back to the application or driver code.

!!! Warning
    NOTE from Khalil: The `p_timeout` approach is silly. Yes, its helpful for clock stretching case, but its very rare to find devices that use clock stretching. If most devices supported clock stretching, then having the API take a timeout callback would be acceptable. But its so rare that most code is just passing `hal::never_timeout()`. `p_timeout` is also problematic for i2c devices that use DMA. Because this has to be polled, when should the DMA code be running? It could just spin while it waits for DMA to finish processing, but we loose out on the capability to put the device to sleep or switch tasks by using the polling option. Overall, it is likely in the future that we will either make `hal::i2c_v2` with an `hal::io_waiter` in place of the `p_timeout` or eliminate the parameter all together and recommend that i2c implementations accept an `io_waiter` as an input parameter. The outcome has yet to be decided.

Here is what a `Write` transaction looks like:

```C++
#include <array>
#include <libhal/i2c.hpp>

void write_then_read(hal::i2c& i2c) {
  std::array<hal::byte, 2> config_register_payload = { 0x02, 0xA2 };
  i2c.transaction(0x14,
                  config_register_payload,
                  {},
                  hal::never_timeout());
}
```

You can replace the span with just `{}` and C++ will deduce and brace
initialize the span using its default constructor, which is a span of size 0
and pointer addressed to `nullptr`. By setting the `p_data_in` to an empty span, the transaction will only perform a write operation.

Here is what a `Read` transaction looks like:

```C++
#include <array>
#include <libhal/i2c.hpp>

void write_then_read(hal::i2c& i2c) {
  std::array<hal::byte, 4> buffer{};
  i2c.transaction(0x14,
                  {},
                  buffer,
                  hal::never_timeout());
}
```

By setting the `p_data_out` with an empty span, the transaction will only perform a write operation.

## Using `libhal-util`

Writing `i2c.transaction(0x14, {}, buffer, hal::never_timeout());` can be long.
A shorter option is to use the utilities from `libhal-util/i2c.hpp`. Take a look at the following code:

```C++
#include <array>
#include <libhal/i2c.hpp>
#include <libhal-util/i2c.hpp>

void testing_libhal_util(hal::i2c& i2c) {
  // These are stand ins
  std::array<hal::byte, 1> payload = { 0xA2 };
  std::array<hal::byte, 2> buffer{};

  // Write `payload` to [the device with the] address 0x23
  hal::write(i2c, 0x23, payload);

  // Fill `buffer` with data read from address 0x33
  hal::read(i2c, 0x33, buffer);

  // Return a buffer of 4 bytes with 4 bytes of data read from address 0x33
  std::array<hal::byte, 4> response0 = hal::read<4>(i2c, 0x33);

  // You can also use the "auto" keyword to shorten the line. The type will be a
  // hal::array<hal::byte, N> where N is the integral template (the <4>)
  // argument.
  auto response0 = hal::read<4>(i2c, 0x33);

  // Two ways to write `payload` to address 0x23 and fill `buffer` with the
  // response.
  hal::write_then_read(i2c, 0x23, payload, buffer);
  auto response1 = hal::write_then_read<4>(i2c, 0x33, payload);

  // Check if the device responds on the bus. Returns true if the device
  // acknowledges the address 0x10.
  if (hal::probe(i2c, 0x10)) {
    // Device did acknowledge
  } else {
    // Device did NOT acknowledge
  }
}
```

## Using libraries that use i2c

### How do I know if a library needs i2c?

If the library's constructor requires a `hal::i2c&`, then that library needs i2c to operate. This goes for any other libhal interface as well.

### Constructing a driver that needs i2c

In this example, we will be creating a driver for the very popular, albeit
obsolete, MPU6050 inertial measurement unit (IMU) and the PWM generator
pca9685. IMUs have the capability to measure acceleration and rotational
velocity. The pca9685 can be instructed via the i2c to generate PWM signals.

```C++
#include <libhal-sensor/mpu6050.hpp>
#include <libhal-extender/pca9685.hpp>

void application() {
  hal::i2c& i2c = /* ... */;
  // Use default address
  hal::sensor::mpu6050 mpu0(i2c);
  // Provide your own address if your MPU6050 model has a different address
  hal::sensor::mpu6050 mpu1(i2c, 0x69);
  // Use default address for the pca9685
  hal::extender::pca9685 pca(i2c);
}
```

!!! Note
    Many i2c devices will have multiple optional address that you can configure
    them to use. Address configuration can come in many ways. Some devices use
    a digital lines to set the bits of the i2c address. Some use a single pin
    that can sense the voltage on the line and depending on where it is between
    0V and the device's VCC, will change its address. There probably exists i2c
    devices with addresses that can be configured using i2c transactions. I2c
    has only 112 address. 26 of the 128 address in the 7-bit address space are
    reserved. Having so few addresses means that its not uncommon to have to
    deal with address conflicts.

In the example application, there are two MPU6050 IMUs used. Each needs access
to the i2c driver to operate. References to i2c objects can be shared between
multiple device drivers but there are rules.

### Ensuring the correct clock rate

Drivers that use i2c are mandated to configure i2c to the highest possible
clock rate that their device can support. But what if devices sharing the i2c resource have different max clock rates? In that case, a solution would be to use the `hal::soft::minimum_speed_i2c` wrapper provided by `libhal-soft`:

```C++
#include <libhal-soft/i2c_minimum_speed.hpp>

hal::i2c& i2c = /* ... */;
hal::soft::minimum_speed_i2c min_speed_i2c(i2c);

hal::sensor::mpu6050 mpu0(min_speed_i2c);
hal::sensor::mpu6050 mpu1(min_speed_i2c, 0x69);
hal::extender::pca9685 pca(min_speed_i2c);

// This will set the
min_speed_i2c.set_clock_rate_to_max_common();
```

`hal::soft::minimum_speed_i2c` requires an `hal::i2c` to construct. After
creating the `minimum_speed_i2c`, use it instead of the original
driver for all of your i2c needs. `minimum_speed_i2c` will set the clock rate
of the i2c driver to `100kHz`, which is a safe default for i2c. When
`configure` is called on `minimum_speed_i2c`, it caches the lowest frequency
its seen and returns. It will NOT reconfigure the passed in i2c driver. To set
the i2c driver to the max common rate across all of the drivers that use the
shared i2c object, call `set_clock_rate_to_max_common()`.

!!! critical
    The current `hal::soft::minimum_speed_i2c` does not behave is this way. It
    reconfigures to the lowest speed its seen after each `configure` call. This
    is problematic because it won't work on an I2C bus unless the i2c objects
    are constructed in a particular order. To show the issue consider passing
    an i2c to drivers A, B, and C. A has a max clock rate of 1MHz, B 400kHz and
    C 100kHz. If A's constructor sets the clock rate to 1MHz and attempts talk
    to the device, this could result in device B or C responding because they
    misinterpreted the information in the bus.

### Thread safety

!!! critical
    Thread safe i2c is not currently supported. When it is added, the following
    will become relevant. Its still a good read if you want to see how we
    handle thread safety for i2c.

I2c drivers implementations do not need to consider thread safety. The
rationale for this is that thread safety is not always needed for an i2c
driver. If the application is written as a super-loop application or only one
thread uses the i2c driver, then there is no thread safety issue and thus no
need to support thread safety.

What happens when an application does need to use an i2c driver between threads?
One option is to use wrap anything that may use the i2c driver between threads with a mutex/lock guard:

```C++
auto thread_safe_mpu_read(mpu6050& p_mpu) {
  std::lock_guard guard(my_os_mutex);
  return p_mpu.read();
}

// my_display also has the shared i2c with the mpu6050 driver
auto thread_safe_clear_display(my_display& p_display) {
  std::lock_guard guard(my_os_mutex);
  p_display.clear_screen();
}
```

This can be very error prone, especially if its not obvious that a particular
driver uses the shared i2c. What we really want is access to the i2c driver to
be thread safe so drivers and application writers can focus on writing code
that works.

`libhal-soft` provides the `hal::soft::thread_safe_i2c` wrapper which does what
it says on the tin. This is how it works:

```C++
hal::i2c& i2c = /* ... */;
hal::basic_lock& i2c_lock = /* ... */;
hal::soft::thread_safe_i2c thread_safe_i2c(i2c, i2c_lock);

hal::sensor::mpu6050 mpu0(thread_safe_i2c);
hal::sensor::mpu6050 mpu1(thread_safe_i2c, 0x69);
hal::extender::pca9685 pca(thread_safe_i2c);
```

`hal::soft::thread_safe_i2c` requires an `hal::i2c` and a `hal::basic_lock` to
construct. After creating the `thread_safe_i2c`, use it instead of the original
driver for all of your i2c needs. When `configure` or `transaction` is called
on `thread_safe_i2c`, it will first acquires the lock for `i2c_lock`, and after
it has acquired the lock, it dispatches the call to the original i2c driver.
Using the thread_safe_i2c ensures that all accesses to that resource are thread
safe.

There is one some safety issues with the code above. You can still access the original `i2c`. One could accidentally use that rather than the appropriate `thread_safe_i2c` causing a race condition. A way to get around this, is to pass the i2c and basic lock to the driver as a temporary:

```C++
hal::soft::thread_safe_i2c thread_safe_i2c(
  hal::lpc40::i2c(2),
  hal::freertos::basic_lock()
);

hal::sensor::mpu6050 mpu0(thread_safe_i2c);
hal::sensor::mpu6050 mpu1(thread_safe_i2c, 0x69);
hal::extender::pca9685 pca(thread_safe_i2c);
```

As you can see above, there is no longer an i2c instance that is accessible by
the code to call, preventing accidental use and making race conditions
impossible.

!!! note
    This usage of `hal::soft::thread_safe_i2c` also devirtualizes calls to
    `hal::lpc40::i2c` and `hal::freertos::basic_lock`. This comes from the way
    that `hal::soft::thread_safe_i2c` works. `hal::soft::thread_safe_i2c` is a
    template and it captures the concrete type of the i2c and basic locks
    passed to it. By knowing the concrete type, the compiler can skip the
    indirection of a virtual call and call the underlying functions for the i2c
    driver. Same goes for the basic_lock. This provides a slight performance
    improvement. If your application has multiple `thread_safe_i2c` objects
    where the input types are not all the same type, then for each unique type
    combinations you get a new instance of `thread_safe_i2c`. This is typical
    of class templates. Read this article to learn more:
    [C++ Core Guidelines T.5: Combine generic and OO techniques to amplify their strengths, not their cost](shttps://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#t5-combine-generic-and-oo-techniques-to-amplify-their-strengths-not-their-costs)

### Dealing with multi controllers on the bus

!!! critical
    The wrappers explained here are not currently supported but will in the
    future. When it is added, the following will become relevant. Its still a
    good read if you want to see how we handle multiple controllers on the bus
    for i2c.

In general, it is bad practice to have multiple controllers on the i2c bus. I2c
supports this architecture, but only one device can communicate at a time. If
another controller is using the bus, then all other controllers must wait until
that transaction is over before any other controller can use the bus.

But if you are in a position where you have to share an i2c bus with multiple
devices, this is how you manage that.

TBD

## Writing an i2c device driver

I2c device drivers are drivers that require i2c to communicate with a chip or
system.

TBD

## Implementing an i2c driver on bare metal

Implementing i2c can be a bit of a process. Implementing i2c is a platform
specific bit of work, but many i2c peripherals have similar implementations.
Modern microcontrollers and system-on-chips will implement i2c in the form of a
state machine, using interrupts to notify the system that the i2c peripheral
has moved from one state to another. If the i2c implementation you are working
with does not follow the patterns described in the guide below, then you will
need to figure out how to implement the `hal::i2c` based on the data sheet
you've been provided.

Coming soon...
