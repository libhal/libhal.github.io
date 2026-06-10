# 💾 Memory Model

libhal's memory model is built on **reference-counted smart pointers**, **polymorphic allocators**, and **explicit ownership semantics**. This design ensures memory safety on embedded systems with limited resources while preventing the subtle bugs that plague `std::shared_ptr`.

## Overview

Every driver and adapter in libhal manages memory through three core principles:

1. **Allocation is always explicit** — Application code provides the allocator; drivers never call `new` or `malloc`
2. **Ownership is always clear** — Smart pointers prevent use-after-free and resource leaks
3. **Lifetime is always safe** — Reference counting prevents dangling pointers

## Core Types from `strong_ptr`

libhal uses the [`strong_ptr`](https://github.com/libhal/strong_ptr) library for safe, memory-constrained smart pointers. Key types:

### `hal::ptr<T>` (non-null reference-counted pointer)

```cpp
// hal::ptr is an alias for mem::strong_ptr<T>
template<typename T>
using ptr = mem::strong_ptr<T>;
```

**Properties:**

- **Never null** — Cannot be default-constructed or assigned `nullptr`
- **Reference-counted** — Tracks shared ownership; object lives as long as any `ptr` references it
- **Move acts as copy** — Moving a `ptr` doesn't invalidate the source, preventing use-after-move bugs
- **Explicit allocator** — Requires a `hal::allocator` (alias of `std::pmr::polymorphic_allocate<>`) at construction

**Usage:**

```cpp
// Create via make_strong_ptr
auto allocator = mem::make_monotonic_allocator<4096>();
auto sensor = hal::sensor::mpu6050::create(allocator, bus);

// Share ownership
hal::ptr<mpu6050> copy = sensor;  // increments reference count
assert(sensor.use_count() == 2);   // both pointers share the object

// Move acts as copy (not the typical move semantics)
auto another = std::move(sensor);  // source remains valid
assert(sensor.use_count() == 3);   // there are now 3 references to this object
```

### `hal::deferred_ptr<T>` (async factory result)

```cpp
// hal::deferred_ptr is an alias for async::future<hal::ptr<T>>
template<typename T>
using deferred_ptr = async::future<hal::ptr<T>>;
```

Used by factory functions that perform async initialization:

```cpp
// Factory that performs async work
[[nodiscard]] static hal::deferred_ptr<my_driver> my_driver::create(
  async::context& p_context,
  hal::allocator p_resource,
  hal::ptr<hal::i2c> p_bus);

// Usage
async::inplace_context<1024> ctx;
auto alloc = mem::make_monotonic_allocator<4096>();
auto driver = co_await my_driver::create(ctx, alloc, bus);
```

### `mem::weak_ptr<T>` (non-owning reference)

```cpp
mem::weak_ptr<sensor> weak = my_sensor;  // doesn't extend lifetime

// Try to lock - returns optional_ptr
mem::optional_ptr<sensor> maybe = weak.lock();
if (maybe) {
  maybe->read_data();
}
```

Useful in situations where the manager would like to have a registry of
children that it has access to. Holding a strong_ptr to a child object will
result in a cycle which will result in a memory leak.

### `mem::optional_ptr<T>` (nullable smart pointer)

The **only** way to represent "no value" in this library. Implicitly converts
to `ptr<T>` and throws `mem::nullptr_access` if empty.

```cpp
mem::optional_ptr<sensor> maybe = weak.lock();  // valid or empty

if (maybe) {
  maybe->read();  // safe - converts to ptr<sensor>
}

// Throws if empty
auto ref = mem::optional_ptr<sensor>{};
auto danger = static_cast<hal::ptr<sensor>>(ref);  // throws nullptr_access
```

### `mem::enable_strong_from_this<T>` (self-referencing)

Allows an object to safely obtain pointers to itself:

```cpp
class my_driver : public mem::enable_strong_from_this<my_driver> {
public:
  void register_callback(hal::ptr<event_queue> queue) {
    auto self = strong_from_this();
    queue->on_interrupt([self]() {
      self->handle_interrupt();
    });
  }
};
```

## Allocation: PMR (Polymorphic Memory Resource)

All heap allocation in libhal goes through `hal::allocator`. The caller provides the memory resource, giving applications full control over where memory comes from.

**Why PMR?**

- Works on systems with no heap (embedded)
- Enables custom allocators for specific memory regions (DMA-safe RAM)
- Makes allocation explicit and auditable
- Supports both heap and stack-allocated regions
- Objects with type erased allocators play well with each other.
- Additional types are created when

### Common Allocators

```cpp
// Stack-allocated monotonic bump allocator (calls std::terminate on leaks)
auto stack_alloc = mem::make_monotonic_allocator<4096>();

// Polymorphic allocator wrapping a memory resource
hal::allocator alloc(&my_resource);

// Use in driver creation
auto driver = hal::lpc40::i2c::create(alloc, port, settings);
```

### Memory Management Rules

| Pattern                 | ❌ Don't                              | ✅ Do                                      |
| ----------------------- | ------------------------------------ | ----------------------------------------- |
| **Heap allocation**     | `new`/`delete`, `malloc`/`free`      | `hal::allocator`                          |
| **Stored dependencies** | Raw pointers `T*` or references `T&` | `hal::ptr<T>`                             |
| **Return "no value"**   | `nullptr` or `std::optional`         | `mem::optional_ptr<T>`                    |
| **Self-references**     | Manual lifetime tracking             | `mem::enable_strong_from_this<T>`         |
| **Buffers**             | `std::vector` or `std::pmr::vector`  | `hal::allocated_buffer<T>` for fixed-size |

## Memory Management by Driver Type

### 🏗️ Managers: Own Hardware

Managers hold hardware state in an implementation struct and hand out resources to users.

**Constructor example:**

```cpp
// hal/lpc40/i2c.cppm
namespace hal::lpc40 {

export class i2c : public hal::pimpl<i2c> {
public:
  struct impl;  // defined in i2c.cpp only - hides memory details

  [[nodiscard]] static hal::ptr<i2c> create(
    hal::allocator p_resource,
    hal::u8 p_bus,
    settings const& p_settings = {});

  i2c(pimpl::private_key,
      hal::allocator p_resource,
      hal::u8 p_bus,
      settings const& p_settings);
};

} // namespace hal::lpc40
```

**Lifetime:**

- Manager owns memory for hardware state
- Memory is allocated via `p_resource` passed to constructor
- Memory lives as long as the manager pointer exists
- Pimpl pattern hides implementation size from public headers

### 📦 Resources: Implement Interfaces

Resources are returned by managers and implement hal interfaces. The concrete resource type is hidden.

```cpp
// Manager returns type-erased interface
auto manager = hal::lpc40::i2c::create(alloc, 2, {});
hal::ptr<hal::i2c> bus = manager->acquire_i2c();

// Application only knows it's a hal::i2c
// The concrete type is an implementation detail in the manager's .cpp
```

**Lifetime and co-ownership:**

Every resource co-owns its manager through a reference count. The manager cannot be destroyed while any resources are live.

```cpp
auto manager = hal::lpc40::i2c::create(alloc, 2, {});
assert(manager.use_count() == 1);

auto resource = manager->acquire_i2c();
assert(manager.use_count() == 2);  // manager and resource both hold a ptr

// If we drop the original manager pointer, the object stays alive
manager = nullptr;
resource->write(data);  // still works - manager is kept alive by resource
```

This co-ownership pattern ensures **resources outlive their manager pointers** in application code.

### 🔌 Adapters: Transform Interfaces

Adapters take hal interfaces and present different ones. They store their dependencies as `hal::ptr<T>` members.

```cpp
namespace hal {

export class soft_i2c : public hal::i2c {
public:
  [[nodiscard]] static hal::ptr<soft_i2c> create(
    hal::allocator p_resource,
    hal::ptr<hal::output_pin> p_sda,
    hal::ptr<hal::output_pin> p_scl,
    settings const& p_settings = {});

  soft_i2c(private_key,
           hal::allocator p_resource,
           hal::ptr<hal::output_pin> p_sda,
           hal::ptr<hal::output_pin> p_scl,
           settings const& p_settings);

private:
  hal::ptr<hal::output_pin> m_sda;  // dependencies stored as ptr
  hal::ptr<hal::output_pin> m_scl;
};

} // namespace hal
```

**Memory ownership:**

- Adapter does not own hardware directly
- Adapter owns its dependencies through `hal::ptr` members
- If all external references are dropped, the adapter can be destroyed
- Dependencies remain alive as long as the adapter holds them

## Allocation Patterns

### Fixed-Size Buffers

For buffers of known size at construction time, use `hal::allocated_buffer<T>`:

```cpp
// ❌ Vector allows runtime resizing during operation
class my_driver {
  std::pmr::vector<uint8_t> m_buffer;  // can allocate during reads!
};

// ✅ Allocated buffer - fixed size, allocates only at construction
class my_driver {
  my_driver(hal::allocator alloc, std::size_t size)
    : m_buffer(alloc, size) {}

  hal::allocated_buffer<uint8_t> m_buffer;  // no allocation during operation
};
```

### Storing Hal Interface Dependencies

Always use `hal::ptr<T>` for stored dependencies:

```cpp
// ❌ Raw pointer - no ownership or lifetime guarantee
class mpu6050 {
  hal::i2c* m_i2c;  // dangling if bus is deleted
};

// ❌ Reference member - deletes copy constructor
class mpu6050 {
  hal::i2c& m_i2c;  // can't copy, can't move
};

// ✅ hal::ptr - safe ownership and lifetime
class mpu6050 {
  hal::ptr<hal::i2c> m_i2c;  // lives as long as this object
};
```

Parameters that are **not stored** can be raw references:

```cpp
// ✅ Reference OK - consumed within the call, not retained
void configure(hal::i2c& p_bus, settings const& p_settings);

// ✅ ptr required - the i2c is stored
my_sensor(private_key, hal::ptr<hal::i2c> p_bus)
  : m_i2c(p_bus) {}
```

## Unsafe Patterns and Alternatives

### Breaking Reference Cycles

When objects hold pointers to each other, use `mem::weak_ptr` to avoid cycles:

```cpp
// ❌ Cycle: event_queue holds ptr to handler, handler holds ptr to queue
struct handler {
  hal::ptr<event_queue> m_queue;  // cycle!
};

// ✅ Break the cycle with weak_ptr
struct handler : mem::enable_strong_from_this<handler> {
  mem::weak_ptr<event_queue> m_queue;  // doesn't extend lifetime

  void on_event() {
    if (auto queue = m_queue.lock()) {
      queue->process();
    }
  }
};
```

### Self-References in Callbacks

When an object needs to reference itself in a callback or async operation:

```cpp
// ✅ Use enable_strong_from_this
class sensor : public mem::enable_strong_from_this<sensor> {
public:
  async::future<void> start_reading(async::context& ctx) {
    auto self = strong_from_this();
    timer->on_interrupt([self, ctx]() mutable {
      co_await self->read_sample(ctx);
    });
    co_return;
  }
};
```

## Design Guidelines

### ✅ Good Practices

- **Allocate at construction time** — Never allocate during operations
- **Use type erasure** — Return `hal::ptr<hal::interface>`, not concrete types
- **Share interfaces, not implementations** — Depend on `hal::i2c`, not `lpc40::i2c`
- **Let reference counting work** — Simplifies lifetime management automatically
- **Document allocator requirements** — State buffer sizes, DMA requirements, etc.

### ❌ Anti-Patterns

- **Raw pointers as members** — Doesn't express ownership or lifetime
- **Mixing `ptr` and raw pointers** — Breaks safety guarantees
- **Reference members** — Deletes copy/move, limits flexibility
- **Allocating during operation** — Incompatible with real-time guarantees
- **Circular ownership via `ptr`** — Use `weak_ptr` to break cycles

## Comparing with `std::shared_ptr`

`hal::ptr` (via `strong_ptr`) fixes issues with `std::shared_ptr`:

| Problem                  | `std::shared_ptr`                                       | `hal::ptr`                               |
| ------------------------ | ------------------------------------------------------- | ---------------------------------------- |
| **Can be null**          | Yes - dereferencing null is UB                          | Never - type system prevents it          |
| **Implicit allocator**   | Uses global heap                                        | Explicit `std::pmr::memory_resource`     |
| **Use-after-move**       | Source becomes null (UB if used)                        | Move acts as copy - source stays valid   |
| **Aliasing constructor** | Accepts arbitrary `void*` — UB if lifetimes don't match | Safe aliasing via pointer-to-member only |
| **Allocation overhead**  | Dual allocations (object + control block)               | Single efficient allocation              |

---

## See Also

- [Driver Types](driver_types.md) — How managers, resources, and adapters use memory
- [Pimpl Pattern](pimpl.md) — Hiding implementation details
- [Construction Pattern](construction_pattern.md) — Factory pattern for safe creation
- [Style Guide: S.6.2](../style.md#s62-storing-dependencies) — Storing dependencies as `hal::ptr<T>`
- [Style Guide: S.7.3](../style.md#s73-use-pmr-for-allocation) — PMR allocation rules
- [`strong_ptr` API Docs](https://libhal.github.io/api/strong_ptr/main/)
