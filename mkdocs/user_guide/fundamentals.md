# 🧱 Fundamentals of libhal

## What is libhal?

libhal is a C++ hardware abstraction library. It provides a consistent set of
interfaces for interacting with hardware devices, so your application code can
be written once and run on any supported platform without modification.

The ecosystem of library are built around three ideas:

- **Interfaces over implementations.** You write code that depends on the
  interface type `hal::i2c`, not the implementation `hal::lpc40::i2c`. Any
  implementation of that interface is a valid substitute.
- **Allocation you control.** Every driver that needs dynamic memory takes a
  `hal::allocator` (a `std::pmr::polymorphic_allocator<>`). You decide where
  memory comes from. The driver never calls the global allocator via `new` or
  `malloc`.
- **Async by default.** libhal v5 is built on `async_context` which uses C++20
  coroutines. Drivers that talk to hardware return `async::future<T>`, so
  waiting on a sensor read or a DMA transfer suspends only the current
  coroutine, not the whole system.

---

## Platforms

A platform is any execution environment that can run libhal code. This includes
bare-metal microcontrollers and hosted operating systems used for testing.

Currently supported microcontrollers:

- `lpc40xx`
- `stm32f10x`
- `stm32f411re`
- `rp2040` / `rp2350` (in progress)

Linux and macOS are supported as host platforms for unit testing, simulation,
and as usable platforms. Window support is expected in the future.

---

## Interfaces

Interfaces define the contract that every implementation of a hardware
abstraction must fulfill. They are pure virtual base classes with no hardware
dependencies.

```cpp
// hal/gpio.cppm
export module hal:gpio;

export import async_context;
export import :units;

namespace hal::inline v5 {

export class input_pin
{
public:
  struct settings
  {
    pin_resistor resistor = pin_resistor::pull_up;
    bool open_drain = false;
  };

  [[nodiscard]] async::future<void> configure(async::context& p_context,
                                              settings const& p_settings)
  {
    return driver_configure(p_context, p_settings);
  }

  [[nodiscard]] async::future<bool> level(async::context& p_context)
  {
    return driver_level(p_context);
  }

  virtual ~input_pin() = default;

protected:
  virtual async::future<void> driver_configure(async::context& p_context,
                                               settings const& p_settings) = 0;
  virtual async::future<bool> driver_level(async::context& p_context) = 0;
};
} // namespace hal::inline v5
```

Application code and device libraries depend only on the interface:

```cpp
async::future<void> wait_for_button_press(async::context& p_ctx,
                                          hal::input_pin& p_button)
{
  while (co_await p_button.level(p_ctx)) {
    co_await 100us; // debounce
  }
}

// Works with any platform's input_pin implementation
async::inplace_context<1024> ctx;
auto gpio = hal::lpc40::gpio::create(alloc, hal::port<0>);
hal::ptr<hal::input_pin> button = gpio->acquire_input_pin(7);
co_await wait_for_button_press(ctx, *button);
```

---

## Driver Types

libhal v5 organizes every driver into one of three architectural categories.
Understanding the distinction keeps drivers composable and prevents ownership
mistakes.

![Driver Types](assets/driver_types.svg)

| Type         | Owns hardware | Has vtable | Produced by         |
| ------------ | ------------- | ---------- | ------------------- |
| **Manager**  | ✅             | ❌          | `create()` factory  |
| **Resource** | ❌             | ✅          | Manager acquisition |
| **Adapter**  | ❌             | ✅          | `create()` factory  |

### Managers

A manager is the concrete class that owns and configures a single piece of
hardware. It is the authoritative object for that hardware for as long as it
lives.

Managers cover everything libhal touches:

- **SOC-integrated peripherals** — I2C bus controllers, SPI controllers, GPIO
  ports, UART controllers, timers
- **External devices** — sensors, displays, motor controllers, smart servos,
  anything connected over a protocol

In both cases the role is the same: initialize the hardware, hold its
configuration, and vend resource objects to the rest of the application.

Managers are constructed exclusively through a static `create()` factory that
returns `hal::ptr<ManagerType>`. If initialization requires hardware
communication (e.g., reading a sensor ID over I2C), `create()` is an
coroutine and returns `hal::deferred_ptr<ManagerType>` instead.
Constructors are not directly accessible. Constructors require a `private_key`
parameter that only the `create()` factory can provide.

```cpp
// SOC peripheral manager — synchronous construction
auto gpio = hal::lpc40::gpio::create(alloc, hal::port<0>);

// Device manager — asynchronous construction
auto imu = co_await hal::sensors::mpu6050::create(ctx, alloc, i2c_bus);
```

!!! NOTE
    Managers carry no vtable. All platform-specific state lives in a nested
    `impl` struct defined only in the module implementation (`.cpp`) file. The
    public interface file forward-declares `struct impl` and derives from
    `hal::pimpl<T>`, keeping the ABI stable and the implementation hidden. This allows drivers to be changed without resulting in an ABI break that causes build failures or worse, undefined behavior.

### Resources

A resource is the object a manager hands out. It implements a hal interface and
is the canonical way application code interacts with the hardware the manager
owns.

Resources are always returned as `hal::ptr<hal::interface>`. The concrete type
is an implementation detail which is usually hidden in the manager's `.cpp`
file.

```cpp
hal::ptr<hal::i2c>         bus   = i2c_manager->acquire_i2c();
hal::ptr<hal::output_pin>  led   = gpio_manager->acquire_output_pin(2);
hal::ptr<hal::accelerometer> accel = imu->acquire_accelerometer();
```

Every resource co-owns its manager through reference counting. The manager
cannot be destroyed while any resource it vended is still live.

### Adapters

An adapter takes one or more existing hal interfaces and presents a different
hal interface. It shares ownership of the hardware and all hardware access
flows through the interfaces it holds.

Common uses:

- Software (bit-bang) implementations built from simpler primitives such as
  `hal::output_pin`.
- Decorating or scoping a resource before passing it further down the
  dependency chain
- Protocol translation (e.g., RS-485 half-duplex framing over `hal::uart`)
- Making an driver thread safe by locking a mutex prior to usage.

```cpp
// Bit-bang I2C from two output pins
auto soft_i2c = hal::soft_i2c::create(alloc, sda_pin, scl_pin, {
  .clock_rate = 100_kHz
});

// soft_i2c is a hal::ptr<hal::i2c> — anything expecting hal::i2c accepts it
auto display = co_await hal::displays::ssd1306::create(ctx, alloc, soft_i2c);
```

Adapters are constructed via `create()` like managers, but some also inherit
from a hal interface directly rather than using the pimpl pattern.

---

## Async and Coroutines

libhal v5 uses C++20 coroutines via `async_context` for all operations that
block waiting on hardware. A driver method that reads a sensor, waits for a DMA
transfer, or performs I2C communication is an `async::future<T>` coroutine.

```cpp
// A sensor driver that reads over I2C
async::future<hal::celsius> temperature_sensor::read(async::context& p_ctx)
{
  // Returns array of 2 bytes
  auto raw_bytes = co_await hal::write_then_read<2>(p_ctx, *m_i2c, m_address);
  co_return to_celsius(raw_bytes[0], raw_bytes[1]);
}
```

Calling code `co_await`s the result:

```cpp
async::future<void> my_task(async::context& p_ctx)
{
  while (true) {
    auto temp = co_await sensor.read(p_ctx);
    log_temperature(temp);
    co_await 500ms;
  }
}
```

This model has several properties that matter for embedded systems:

- **No threads required.** Each coroutines gets it own stack where it can
  allocate it coroutine frames. These stacks can be scheduled cooperatively
  scheduled by `async_context`. There is no RTOS needed.
- **No heap allocation during normal operation.** Coroutine frames are
  allocated from the provided allocator at construction time, not at each
  `co_await`.
- **Cancellation is destruction.** Destroying a suspended coroutine runs all
  destructors in the frame, so RAII cleanup works exactly as in synchronous
  code.

See the `async_context` documentation for the full scheduler model and
synchronization primitives.

---

## Memory Management

libhal forbids raw heap allocation (`new`, `delete`, `malloc`, `free`) in all
library code. Instead, every driver that needs dynamic memory accepts a
`hal::allocator` parameter:

```cpp
// ✅ Caller controls where memory comes from
auto i2c = hal::lpc40::i2c::create(alloc, hal::port<2>, {.clock_rate = 400_kHz});
```

`hal::allocator` is `std::pmr::polymorphic_allocator<>`. You can back it with a
stack-resident monotonic buffer, a pool allocator, or any other PMR resource.

```cpp
// Fixed-size arena on the stack — no heap involvement
auto alloc = make_monotonic_allocator<4096>();
auto gpio = hal::lpc40::gpio::create(alloc, hal::port<0>);
```

All allocation happens at construction time. A well-behaved driver never
allocates or frees memory.

---

## Library Categories

- **Platform** - Drivers for a specific MCU family; owns hardware registers and
  peripherals
  - Examples: `libhal-lpc40`, `libhal-stm32f1`
- **Device**   - Drivers for external hardware; platform-independent; depends
  on hal interfaces
  - Examples: `libhal-sensor`, `libhal-display`
- **Utility**  - Pure software helpers; no hardware dependencies
  - Examples: `libhal-util`
- **Board**  - Pure software helpers; no hardware dependencies
  - Examples: `libhal-picosdk`, `libhal-micromod`, (future) `libhal-arduino`
- **Process**  - Higher-level functionality composed from multiple drivers
  - Examples: Sensor fusion, motor control loops

Platform libraries are the only category that may include RTOS APIs, compiler
intrinsics, inline assembly, or other architecture-specific code. Device
libraries and utility libraries must compile correctly on every supported
target, including Linux and macOS.

---

## Module Structure

libhal v5 uses C++20 modules. Every library is a named module split into
partitions. The primary interface file re-exports all partitions so you only
need one `import` statement:

```cpp
import hal;         // pulls in all hal interfaces, types, and containers
import hal.util;    // pulls in hal utilities
import hal.arm_mcu; // pulls in the entirety of the ARM MCU library
```

All libhal symbols live in `namespace hal::inline v5`. The `inline` version
suffix is transparent. You always write `hal::output_pin`, never
`hal::v5::output_pin`.

---

## Understanding Virtual Functions in C++

A quick note about virtual functions (which libhal uses extensively):

1. **They don't require heap memory**: Virtual functions work fine with
   stack-allocated objects. Our choice to allocate our drivers is for memory
   safety and NOT to enable virtual APIs.
2. **Performance impact is minimal**: The overhead is usually just one extra
   pointer dereference.
3. **Memory overhead is small**: Each class with virtual functions needs only
   one vtable (shared between all instances).

## Key Policies

A few rules apply uniformly across all libhal driver code:

**Depend on interfaces, not implementations.** Device libraries must never take
a `hal::ptr<hal::lpc40::i2c>` where a `hal::ptr<hal::i2c>` will do.
Implementation types belong only in the platform library that defines them and
in application entrypoints that assemble the dependency graph.

**Store dependencies as `hal::ptr<T>`.**  Any hal interface dependency kept as
a member variable must be `hal::ptr<T>`, never a raw pointer or reference. This
keeps the referenced object alive and expresses co-ownership clearly.

**No logging from drivers.** Drivers do not call `printf`, `std::cout`, or any
other output facility. Logging is the application's responsibility.

**Managers always live as long as their resources.** Resource objects co-own
their manager via reference counting, meaning manager objects stay allocated
until the last resource is destroyed.

**Construction order reflects dependencies.** Assemble the dependency graph
bottom-up: platform managers first, then device managers that depend on them,
then process objects that depend on device managers.
