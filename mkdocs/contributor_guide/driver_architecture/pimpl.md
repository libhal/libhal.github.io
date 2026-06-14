# 🔒 Pimpl: ABI Protection with Private Implementations

The **Pimpl** (Pointer to Implementation) pattern is used throughout libhal to
hide platform-specific and implementation details from the public API. This
page explains the pattern, why libhal uses it, and how to implement it.

## The Pattern in Brief

A Pimpl class stores all implementation details in a private `impl` struct that
lives in the `.cpp` file. The public `.cppm` file never sees the implementation
size or structure:

Within the module interface file: `modules/my_driver.cppm`

```cpp
export module my_driver;

import hal;

export class my_driver : public hal::pimpl<my_driver> {
public:
  struct impl;  // Forward declaration only — no definition here

  static hal::ptr<my_driver> create(hal::allocator, hal::u8 p_port);
  my_driver(private_key, hal::allocator, hal::u8);
};
```

Within the implementation file: `src/my_driver.cpp`

```cpp
module my_driver;

struct my_driver::impl {
  volatile std::uint32_t* m_register_base;
  hal::u16 m_channel;
  // ... platform-specific state ...
};

my_driver::my_driver(private_key, hal::allocator p_alloc, hal::u8 p_channel) {
  initialize_pimpl(p_alloc, my_driver::impl{
    .m_register_base = 0x8000'4000,
    .m_channel = p_channel,
  });  // Allocates and constructs the impl struct
}
```

You are encouraged to add a destructor to `impl` if cleanup is needed at object
destruction. If no custom cleanup logic is needed, omit the destructor entirely.
This improves the chance that the object is trivially destructible which allows
the compiler to optimize away destructor calls.

## Why Pimpl?

### 1. ABI Stability

The public header never exposes implementation details, so changes to the
`impl` struct don't break binary compatibility:

```cpp
// Version 1.0
struct my_driver::impl {
  volatile std::uint32_t* m_register_base;
  hal::u16 m_channel;
};

// Version 1.1 — internal change, no API break
struct my_driver::impl {
  volatile std::uint32_t* m_register_base;
  hal::u16 m_channel;
  hal::u8 m_new_field;  // Added — existing binaries still work
};
```

Without Pimpl, adding a member would change `sizeof(my_driver)`, breaking every
program that allocated the object.

### 2. Compilation Decoupling

The public header doesn't include platform-specific headers. This means:

- Code using `hal::i2c` compiles the same way on all platforms
- The driver can include vendor headers and hardware-specific utilities without
  polluting the public API
- Clean separation between interface and platform

```cpp
module my_driver;

// OK to include platform-specific headers
#include <lpc40xx.h>
#include "lpc40_driver_utils.h"

// Implementation uses platform details
struct my_driver::impl {
  MCU_PERIPH_TypeDef* m_peripheral;
  // ...
};
```

## How `hal::pimpl<T>` Works

The `hal::pimpl<T>` base class provides:

### `impl()` accessors

```cpp
[[nodiscard]] auto& impl() noexcept {
  return *static_cast<typename Derived::impl*>(m_impl);
}

[[nodiscard]] auto const& impl() const noexcept {
  return *static_cast<typename Derived::impl const*>(m_impl);
}
```

These provide mutable and const access to the implementation struct from derived class methods.

### `initialize_pimpl()` function

```cpp
template<typename... Args>
void initialize_pimpl(allocator p_resource, Args&&... p_args) {
  using impl_type = typename Derived::impl;
  m_impl = p_resource.new_object<impl_type>(std::forward<Args>(p_args)...);
  m_destroy = [](void* p_address, allocator p_resource) noexcept {
    p_resource.delete_object(static_cast<impl_type*>(p_address));
  };
}
```

This allocates and constructs the impl struct with the given allocator.

### Automatic cleanup

The destructor automatically deletes the impl:

```cpp
~pimpl() noexcept {
  if (m_impl != nullptr && m_destroy != nullptr) {
    m_destroy(m_impl, this->strong_from_this().get_allocator());
  }
}
```

## Example Pimpl Implementation for MPU6050 sensor

### Step 1: Declare the impl struct

In the `.cppm` file, forward-declare only:

```cpp
// hal/sensors/mpu6050.cppm
export class mpu6050 : public hal::pimpl<mpu6050> {
public:
  struct impl;  // Forward declaration only

  static hal::future_ptr<mpu6050> create(
    async::context& p_context,
    hal::allocator p_resource,
    hal::ptr<hal::i2c> p_bus);

  mpu6050(private_key,
          hal::allocator,
          hal::ptr<hal::i2c>);

  // Public APIs
  void mpu6050::configure(hal::u8 p_sample_rate);
  hal::u8 mpu6050::address() const;
}

```

### Step 2: Define the impl struct

In the `.cpp` file, define the full struct:

```cpp
// hal/sensors/mpu6050.cpp
module hal:mpu6050;

struct mpu6050::impl {
  hal::ptr<hal::i2c> i2c_bus;
  hal::u8 address;
};
```

### Step 3: Call `initialize_pimpl()` in the constructor

```cpp
mpu6050::mpu6050(private_key,
                 hal::allocator p_allocator,
                 hal::ptr<hal::i2c> p_bus)
{
  initialize_pimpl(
    impl{
      .i2c_bus = p_bus,
      .address = 0x68,
    });
}
```

### Step 4: Access the impl from methods

```cpp
// In the .cpp file
void mpu6050::configure(hal::u8 p_sample_rate) {
  auto& self = inner();  // Access the impl struct
  constexpr u8 reg_addr = 0x11;
  hal::write(*self.i2c_bus, self.address, {reg_addr, p_sample_rate});
}

// Or in the class for inline methods (if needed)
hal::u8 mpu6050::address() const {
  return inner().address;  // Const access
}
```

## Pimpl and Managers

Managers in libhal are required to inherits from `hal::pimpl<T>` for the
following reasons:

- Managers own hardware state (register pointers, peripheral bases, etc.)
- That state is device or platform specific (LPC40 vs STM32 vs RP2040)
- The public API must be platform-agnostic

```cpp
// This manager works identically across platforms
export class i2c : public hal::pimpl<i2c> {
public:
  // Public API is the same everywhere
  static hal::ptr<i2c> create(hal::allocator, hal::u8 port);
  hal::ptr<hal::i2c> acquire_i2c();
};

// But the implementation is entirely platform-specific
// (hidden in the .cpp file for each target)
```

## Pimpl and Resources

Resources (objects handed out by managers) **do not** use Pimpl. Instead their
type erasure comes from implementing a libhal interface.

## Pimpl and Adapters

Managers in libhal are required to inherits from `hal::pimpl<T>` for the
following reasons:

- Managers own hardware state (register pointers, peripheral bases, etc.)
- The public API must be platform-agnostic

## Pimpl memory footprint

The cost of `hal::pimpl<T>` is:

1. A single pointer to the `impl` class.
2. Inherits `mem::enable_strong_from_this<T>` which has a cost of 4 words of
   data.

The cost of `mem::enable_strong_from_this<T>` is the same as if you used
`make_strong_ptr` which is a requirement anyway, thus the total amount of
additional memory beyond whats needed for a `strong_ptr` is just 1 extra
pointer.

## Example: Pimpl Implementation

**Header file** (`modules/gpio.cppm`):

```cpp
export module hal:gpio;

export class output_pin : public hal::pimpl<output_pin> {
public:
  struct impl;  // Forward declaration

  [[nodiscard]] static hal::ptr<output_pin> create(
    hal::allocator p_resource,
    hal::u8 p_port,
    hal::u8 p_pin);

  void level(bool p_high);

  output_pin(private_key,
             hal::allocator,
             hal::u8,
             hal::u8);
};
```

**Implementation file** (`src/gpio.cpp`):

```cpp
module hal:gpio;

struct output_pin::impl {
  volatile std::uint32_t* m_port_register;
  hal::u8 m_pin_mask;
  bool m_inverted;
};

output_pin::output_pin(private_key,
                       hal::allocator p_alloc,
                       hal::u8 p_port,
                       hal::u8 p_pin)
{
  auto const port_base = get_port_register(p_port);
  auto const pin_mask = 1U << p_pin;

  initialize_pimpl(p_alloc,
                   impl{
                     .m_port_register = port_base,
                     .m_pin_mask = pin_mask,
                     .m_inverted = false,
                   });
}

void output_pin::level(bool p_high) {
  auto& self = inner();

  if (p_high) {
    *(self.m_port_register) |= self.m_pin_mask;
  } else {
    *(self.m_port_register) &= ~(self.m_pin_mask);
  }
}
```

## See Also

- [Construction Pattern](construction_pattern.md) — How factories work with Pimpl
- [Driver Types](driver_types.md) — Managers and resources
- [Memory Model](memory_model.md) — How `initialize_pimpl()` uses allocators
- [Style Guide: S.8.2](../style.md#s82-keep-the-hal-namespace-clean) — Namespace hygiene
- [`hal::pimpl<T>` API](https://libhal.github.io/api/libhal/main/class_hal_1_1pimpl.html)
