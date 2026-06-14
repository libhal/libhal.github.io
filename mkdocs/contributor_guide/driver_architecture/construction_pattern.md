# 🏗️ Construction Pattern

libhal uses a **factory pattern** combined with a **private key** type to
ensure safe, controlled construction of drivers. This page explains the
pattern, why it exists, and how to implement it.

## The Pattern in Brief

Every driver is constructed through a static `create()` factory, never through direct constructor calls:

```cpp
// ❌ Not allowed - constructor is private
auto driver = my_driver(...);

// ✅ Correct - use the factory
auto driver = my_driver::create(allocator, dependencies...);
```

The constructor is protected by a `private_key` that only the factory can access:

```cpp
export class my_driver : public hal::pimpl<my_driver> {
public:
  struct impl;

  [[nodiscard]] static hal::ptr<my_driver> create(
    hal::allocator p_resource,
    hal::ptr<hal::i2c> p_bus);

  // Constructor is not public; only create() can call it
  my_driver(private_key,
            hal::allocator,
            hal::ptr<hal::i2c>);

private:
  // ...
};
```

## Why This Pattern?

### 1. Allocation Control

The factory ensures the driver is always allocated through `hal::allocator`, giving the application control over memory:

```cpp
// Application chooses where memory comes from
auto alloc = mem::make_monotonic_allocator<4096>();
auto driver = my_driver::create(alloc, ...);
```

Direct constructors would bypass this, allowing `new` or global heap allocation.

### 2. Resource Management

The factory returns `hal::ptr<T>` (a reference-counted smart pointer). This ensures:

- **Automatic cleanup** — Object is deleted when the last pointer is released
- **Shared ownership** — Managers and resources can safely share the driver
- **No dangling pointers** — Once you hold a `hal::ptr`, the object is guaranteed to live

### 3. Initialization Guarantees

The factory can enforce initialization invariants before the driver is handed to the caller:

```cpp
[[nodiscard]] static hal::ptr<my_driver> create(
  hal::allocator p_resource,
  hal::ptr<hal::i2c> p_bus) {

  // Validate inputs before constructing
  if (!p_bus) {
    throw std::invalid_argument("bus cannot be null");
  }

  return hal::allocate<my_driver>(
    p_resource, private_key{}, p_resource, p_bus);
}
```

## Synchronous Factories

When construction does not call any async operations, the factory must return
`hal::ptr<T>` directly:

```cpp
export class gpio_port : public hal::pimpl<gpio_port> {
public:
  struct impl;

  [[nodiscard]] static hal::ptr<gpio_port> create(
    hal::allocator p_resource,
    hal::u8 p_port_number);

  gpio_port(private_key, hal::allocator, hal::u8);
};
```

Usage:

```cpp
auto alloc = mem::make_monotonic_allocator<4096>();
auto port = gpio_port::create(alloc, 0);  // Returns immediately
```

## Asynchronous Factories

When construction requires hardware communication (I2C handshakes, device detection), the factory returns `hal::future_ptr<T>`:

```cpp
export class mpu6050 : public hal::pimpl<mpu6050> {
public:
  struct impl;

  [[nodiscard]] static hal::future_ptr<mpu6050> create(
    async::context& p_context,
    hal::allocator p_resource,
    hal::ptr<hal::i2c> p_bus,
    hal::u8 p_address = 0x68);

  mpu6050(private_key,
          hal::allocator,
          hal::ptr<hal::i2c>,
          hal::u8);
};
```

Note: `hal::future_ptr<T>` is an alias for `async::future<hal::ptr<T>>`.

Usage:

```cpp
async::inplace_context<1024> ctx;
auto alloc = mem::make_monotonic_allocator<4096>();
auto bus = /* acquire i2c bus */;

// Factory performs async initialization during create()

// Version 1. Within a coroutine
auto imu = co_await mpu6050::create(ctx, alloc, bus);

// Version 2. Outside of a coroutine (needs a sleep function)
auto imu = mpu6050::create(ctx, alloc, bus).sync_wait(
  [](async::sleep_duration p_sleep_time){
    std::this_thread::sleep_for(p_sleep_time);
  });
```

## Factory Parameter Patterns

### Allocation Always First

When a factory takes an allocator, it comes first after `p_context` (if async):

```cpp
// ✅ Sync version, allocator comes first
static hal::ptr<my_driver> create(
  hal::allocator p_resource,        // First
  hal::ptr<hal::i2c> p_bus,         // Then dependencies
  settings const& p_settings);

// ✅ Async version, context 1st, allocator 2nd
static hal::future_ptr<my_driver> create(
  async::context& p_context,        // First (async only)
  hal::allocator p_resource,        // Second
  hal::ptr<hal::i2c> p_bus,         // Then dependencies
  settings const& p_settings);
```

This consistency makes factories easier to understand and discover.

### Settings Come Last

Configuration structs always come last:

```cpp
static hal::ptr<my_driver> create(
  hal::allocator p_resource,
  hal::ptr<hal::i2c> p_bus,
  settings const& p_settings = {}); // Last, with default
```
