# ✍️ Writing a Driver

This page is a practical guide for implementing a libhal driver from scratch. It
covers where your driver lives, how to structure its modules, how to wire up
construction and memory safely, and how to hand out resources. For a conceptual
overview of the three driver types, see [Fundamentals](../user_guide/fundamentals.md).

---

## Naming and Placement

The namespace and class name of a driver communicate what it is and where it
belongs at a glance.

**SOC-integrated peripheral managers** live in a namespace named after the MCU
family. The class name should match the peripheral name in the datasheet as
closely as reasonable.

```plaintext
hal::lpc40::i2c              - LPC40xx I2C controller
hal::lpc40::spi              - LPC40xx SPI controller
hal::stm32f1::usart          - STM32F1 USART controller
hal::stm32f1::advanced_timer - STM32F1 advanced timer
hal::rp2040::pwm             - RP2040 PWM block
```

**External device managers** live in a namespace named after the device
category. The class name is the part number or well-known name of the device.

```plaintext
hal::sensors::mpu6050        - InvenSense MPU-6050 IMU
hal::displays::ssd1306       - Solomon SSD1306 OLED controller
hal::actuators::dynamixel    - Robotis Dynamixel smart servo
hal::expanders::pca9685      - NXP PCA9685 PWM expander
```

**Adapters** live in the `hal` namespace and are named after the interface they
produce, prefixed with the construction strategy or protocol where it adds
clarity.

```plaintext
hal::soft_i2c      - software bit-bang I2C from two output pins
hal::soft_spi      - software bit-bang SPI
```

---

## Deciding What Your Manager Owns

A manager should own a single, logically cohesive hardware block. The hardware
itself is usually the best guide: an I2C controller and an SPI controller are
categorically different peripherals and belong in separate managers.

GPIO is a common source of confusion. You could write a manager per pin, but
most MCUs group pins into ports, each port shares a set of registers, and the
grouping is meaningful to the hardware. A GPIO manager therefore owns a port,
not a pin. The pins themselves are handed out as resources.

Occasionally two peripherals share a hardware resource and cannot be used
simultaneously. The STM32F1 CAN and USB controllers share the same RAM block,
for example. That coupling might seem to argue for a combined manager, but both
are complex enough that keeping them separate is cleaner. Each driver checks at
initialization whether the other peripheral is active and throws if it is. The
coupling is handled at the boundary, not by merging the implementations.

The rule of thumb: if you would not describe the two things as the same
peripheral in a datasheet, they belong in separate managers.

---

## Module Structure

Every manager spans two files:

- **Interface module** (`.cppm`) - the public API; forward-declares `struct impl` only
- **Implementation file** (`.cpp`) - defines `struct impl` and all method bodies

```plaintext
modules/lpc40/i2c.cppm   ← application code sees only this
src/lpc40/i2c.cpp        ← platform details live here, never visible to callers
```

Platform-specific headers, register addresses, and vendor types all belong in
the implementation file.

---

## The Pimpl Pattern

Every manager inherits from `hal::pimpl<T>`. This gives the manager a hidden
`impl` struct that holds all platform-specific state. The interface module
forward-declares `struct impl` but never defines it:

```cpp
// modules/lpc40/i2c.cppm - interface module
export module hal.arm_mcu:lpc40.i2c;
import hal;

namespace hal::lpc40 {

export class i2c : public hal::pimpl<i2c> {
public:
  struct impl;  // forward declaration only - no definition here

  [[nodiscard]] static hal::ptr<i2c> create(
    hal::allocator p_resource,
    hal::u8 p_bus,
    hal::i2c::settings const& p_settings = {});

  [[nodiscard]] hal::ptr<hal::i2c> acquire_i2c();

  i2c(private_key,
      hal::allocator p_resource,
      hal::u8 p_bus,
      hal::i2c::settings const& p_settings);
};

} // namespace hal::lpc40
```

This example is an I2C peripheral manager. `hal::lpc40::i2c` owns the LPC40xx
I2C hardware block and hands out `hal::i2c` resources. The `settings` type
comes from the `hal::i2c` interface and is shared across all I2C
implementations. If a platform driver needs additional configuration beyond what
the interface defines, extend the interface's settings struct rather than
replacing it:

```cpp
struct settings : public hal::i2c::settings {
  bool use_dma = false;  // platform-specific addition
};
```

The implementation file defines the struct and accesses it through `inner()` in
every method body:

```cpp
// src/lpc40/i2c.cpp - implementation file
module hal.arm_mcu:lpc40.i2c;

namespace {
// Register map for the LPC40xx I2C peripheral - stays in this TU only
struct i2c_registers {
  uint32_t conset;
  uint32_t stat;
  uint32_t dat;
  uint32_t adr0;
  // ...
};
} // namespace

struct hal::lpc40::i2c::impl {
  i2c_registers* m_regs;
  hal::u8 m_bus;
};

hal::ptr<hal::i2c> hal::lpc40::i2c::acquire_i2c() {
  auto& self = inner();  // access the impl struct
  // ... construct and return the resource
}
```

### Why Pimpl?

Without pimpl, the `impl` fields would be direct members of the manager class.
Any change to those fields, which includes adding one, removing one, or
reordering them, changes the size and layout of the object. If any translation
unit was compiled against the old layout while another sees the new one, you
have an ODR violation. In the best case this is a linker error. More often it
is silent UB where code reads a field from the wrong memory offset:

```cpp
// ❌ Without pimpl - layout changes silently break callers

// v1.0 - u16 first; requires 2 bytes of padding before the pointer
struct i2c {
  hal::u16 m_baud_div;          // offset 0
                                // 2 bytes padding
  volatile hal::u32* m_base;    // offset 4
};

// v1.1 - reordered for better packing: pointer, u16, then new u8; 1 byte of padding
struct i2c {
  volatile hal::u32* m_base;    // offset 0  (was offset 4!)
  hal::u16 m_baud_div;          // offset 4  (was offset 0!)
  hal::u8 m_bus_index;          // offset 6  (NEW)
                                // 1 byte padding
};
// Code compiled against v1.0 reads m_baud_div from offset 0 - now part of the pointer.
```

With pimpl, the manager's own layout never changes. It is always one pointer
plus the `enable_strong_from_this<T>` control block. The `impl` struct can
change freely without touching the manager's ABI.

### `initialize_pimpl()`

Call `initialize_pimpl()` in the constructor body to allocate and construct the
`impl` struct. Pass the allocator first, then the `impl` initializer:

```cpp
hal::lpc40::i2c::i2c(private_key,
                      hal::allocator p_resource,
                      hal::u8 p_bus,
                      settings const& p_settings)
{
  initialize_pimpl(p_resource, impl{
    .m_regs = reinterpret_cast<i2c_registers*>(get_i2c_base(p_bus)),
    .m_bus  = p_bus,
  });
}
```

`hal::pimpl<T>` handles destruction automatically. You do not need a destructor
unless `impl` itself owns a resource that needs explicit cleanup. If `impl` is
trivially destructible the compiler can optimize away the destructor call
entirely, so keep it trivial when possible.

### Memory footprint

`hal::pimpl<T>` adds exactly one pointer (the `impl` pointer) on top of what
`mem::enable_strong_from_this<T>` already costs. Since managers are always held
via `hal::ptr<T>`, which requires the `enable_strong_from_this` control block
regardless, the true overhead of the pimpl pattern is a single extra pointer.

---

## The Construction Pattern

Every driver is constructed exclusively through a static `create()` factory. The
constructor is not accessible to callers directly.

### The `private_key` Guard

The first parameter of every constructor is `private_key`, a type defined inside
`hal::pimpl<T>`. Only code inside the class definition can name `private_key`,
so only `create()` can construct the object:

```cpp
// ❌ Not allowed - constructor requires private_key
auto driver = my_driver(alloc, bus);

// ✅ Correct - go through the factory
auto driver = my_driver::create(alloc, bus);
```

### Synchronous Factories

When construction does not perform any async operations, `create()` returns
`hal::ptr<T>` directly and is a normal function:

```cpp
[[nodiscard]] static hal::ptr<gpio_port> create(
  hal::allocator p_resource,
  hal::u8 p_port_number);
```

### Asynchronous Factories

When construction requires hardware communication, such as reading a device ID
over a serial bus or performing an initial handshake, the `create()` API becomes
is a coroutine and returns `hal::future_ptr<T>`:

```cpp
[[nodiscard]] static hal::future_ptr<mpu6050> create(
  async::context& p_context,
  hal::allocator p_resource,
  hal::ptr<hal::i2c> p_bus,
  hal::u8 p_address = 0x68);
```

Callers await it like any other coroutine:

```cpp
// Within a coroutine
auto imu = co_await mpu6050::create(ctx, alloc, bus);

// Outside a coroutine
auto imu = mpu6050::create(ctx, alloc, bus).sync_wait(
  [](async::sleep_duration p_dur) {
    std::this_thread::sleep_for(p_dur);
  });
```

### Parameter Ordering

Factory parameters always follow this order:

1. `async::context&` - only present for async factories
2. `hal::allocator` - always present
3. Hardware dependencies (`hal::ptr<hal::i2c>`, etc.)
4. `settings const&` - always last, always defaulted where sensible

```cpp
// ✅ Sync
static hal::ptr<my_driver> create(
  hal::allocator p_resource,
  hal::ptr<hal::i2c> p_bus,
  settings const& p_settings = {});

// ✅ Async
static hal::future_ptr<my_driver> create(
  async::context& p_context,
  hal::allocator p_resource,
  hal::ptr<hal::i2c> p_bus,
  settings const& p_settings = {});
```

---

## Memory Ownership

### Stored dependencies

Any hal interface dependency kept as a member must be `hal::ptr<T>`. Raw
pointers and references both fail to express ownership and can dangle:

```cpp
// ❌ Raw pointer - no ownership guarantee
class my_driver { hal::i2c* m_i2c; };

// ❌ Reference member - prevents move and copy
class my_driver { hal::i2c& m_i2c; };

// ✅ hal::ptr - co-owns the resource, cannot dangle
class my_driver { hal::ptr<hal::i2c> m_i2c; };
```

Passing by reference is fine for parameters consumed within the call and not
retained:

```cpp
// ✅ OK - reference not stored beyond the call
void configure(hal::i2c& p_bus, settings const& p_settings);

// ✅ Must be ptr - stored as a member
my_driver(private_key, hal::allocator p_resource, hal::ptr<hal::i2c> p_bus);
```

### Fixed-size buffers

For buffers whose size is known at construction time, use
`hal::allocated_buffer<T>` rather than `std::pmr::vector<T>`. A vector can
reallocate during operation; an allocated buffer cannot:

```cpp
// ❌ pmr::vector - push_back can trigger allocation at runtime
class my_driver { std::pmr::vector<hal::byte> m_rx_buffer; };

// ✅ allocated_buffer - fixed at construction, no reallocation ever
class my_driver {
  my_driver(hal::allocator p_alloc, std::size_t p_buf_size)
    : m_rx_buffer(p_alloc, p_buf_size) {}

  hal::allocated_buffer<hal::byte> m_rx_buffer;
};
```

### Reference cycles

In general, managers should avoid keeping registries of their live resources
entirely. Prefer designs where the manager does not need to track what it has
handed out. When a registry is genuinely necessary, use `mem::weak_ptr<T>` for
those references. A `hal::ptr<T>` to a child that itself holds a `hal::ptr`
back to the manager creates a cycle that prevents either object from ever being
destroyed:

```cpp
// ❌ Cycle - manager and pins keep each other alive indefinitely
struct gpio_port {
  std::vector<hal::ptr<gpio_pin>> m_pins;
};

// ✅ Weak registry - manager is destroyed normally when callers release it
struct gpio_port : mem::enable_strong_from_this<gpio_port> {
  std::vector<mem::weak_ptr<gpio_pin>> m_pin_registry;
};
```

### Quick reference

| Situation                   | ❌ Don't                              | ✅ Do                       |
| --------------------------- | ------------------------------------ | -------------------------- |
| Stored hal dependency       | `T*` or `T&` member                  | `hal::ptr<T>`              |
| Optional / nullable pointer | `nullptr` or `std::optional<ptr<T>>` | `hal::opt_ptr<T>`          |
| Self-reference in callback  | Manual lifetime tracking             | `strong_from_this()`       |
| Fixed-size buffer           | `std::pmr::vector<T>`                | `hal::allocated_buffer<T>` |
| Child registry in manager   | `hal::ptr<T>` (creates a cycle)      | `mem::weak_ptr<T>`         |
| Raw allocation              | `new` / `malloc`                     | `hal::allocator`           |

---

## Handing Out Resources

Managers hand out resources through `acquire_*()` methods. The default return
type is `hal::ptr<hal::interface>`, which is type-erased. The concrete resource
type is defined only in the `.cpp` file and is never named by callers:

```cpp
// Interface module - callers see only the hal interface
[[nodiscard]] hal::ptr<hal::i2c> acquire_i2c();
[[nodiscard]] hal::ptr<hal::output_pin> acquire_output_pin(hal::u8 p_pin);
```

Every resource co-owns its manager. Releasing the original manager pointer does
not destroy the manager while any resource remains live:

```cpp
hal::opt_ptr<hal::lpc40::i2c> manager = hal::lpc40::i2c::create(alloc, 2);
hal::ptr<hal::i2c> bus = manager->acquire_i2c();

manager = nullptr;    // original manager pointer released
bus->write(data);     // safe - bus holds the last reference to the manager
```

See [Driver Types](../user_guide/fundamentals.md) in Fundamentals for when it is
appropriate to expose a named concrete resource type instead of a type-erased
interface.

---

## Examples

Two reference implementations show the full pattern end to end:

- **Peripheral driver** (SOC-integrated manager + resources): _link TBD_
- **Device driver** (external device manager over a bus protocol): _link TBD_

---

## See Also

- [Async Policy](async_policy.md) - when and how to use coroutines in driver methods
- [Fundamentals](../user_guide/fundamentals.md) - conceptual overview of driver types
- [`hal::pimpl<T>` API](https://libhal.github.io/api/libhal/main/class_hal_1_1pimpl.html)
- [`strong_ptr` API](https://libhal.github.io/api/strong_ptr/main/)