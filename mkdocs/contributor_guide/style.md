# 🎨 Style Guide

## S.1 Code Standards

All libhal code follows the [C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines).
These are the authoritative baseline. Where libhal's style guide and the Core
Guidelines conflict, libhal's style guide takes precedence.

Code formatting is enforced by libhal's
[`.clang-format`](https://github.com/libhal/libhal/blob/main/.clang-format)
file, which uses the Mozilla C++ style as a base with adjustments. Do not
manually reformat code, run `pre-commit run -a` and let it handle this.

Static analysis is enforced by libhal's
[`.clang-tidy`](https://raw.githubusercontent.com/libhal/libhal/refs/heads/main/.clang-tidy)
file. CI will reject code that introduces new clang-tidy violations. Address
violations directly rather than suppressing them with `// NOLINT` unless a
genuine false positive is documented inline with the following format:

```C++
// NOLINT(<violation-check-name>): <reason>
```

Here is an example:

```C++
// NOLINT(readability-identifier-naming): name of a 3rd party symbol we must define for the application to work properly.
```

## S.2 Naming Conventions

Naming follows the standard library convention. Naming rules are enforced by
`.clang-tidy` and spelling is enforced by `cspell` via `pre-commit run -a`.

### S.2.1 General rules

| Construct                 | Convention                 | Example                            |
| ------------------------- | -------------------------- | ---------------------------------- |
| Namespaces                | `snake_case`               | `hal::lpc40`                       |
| Types and classes         | `snake_case`               | `output_pin`, `i2c_bus`            |
| Template parameters       | `CamelCase`                | `Container`, `WordType`            |
| Functions and methods     | `snake_case`               | `driver_read()`, `set_level()`     |
| Variables                 | `snake_case`               | `baud_rate`, `timeout`             |
| Constants and `constexpr` | `snake_case`               | `max_frequency`, `default_timeout` |
| Macros                    | `CAP_CASE`                 | `HAL_CHECK`                        |
| Function parameters       | `p_` prefix + `snake_case` | `p_timeout`, `p_address`           |
| Private/protected members | `m_` prefix + `snake_case` | `m_baud_rate`, `m_i2c`             |

Avoid macros entirely where possible. See S.7.

### S.2.2 Abbreviations

Prefer full words over abbreviations. A reader should not need domain knowledge
to understand a variable name.

```cpp
// ❌ Unclear abbreviations
u32 cnt = 0;
u32 cdl = freq / 2;
u32 cdh = freq - cdl;

// ✅ Full words
u32 count = 0;
u32 clock_divider_low = frequency / 2;
u32 clock_divider_high = frequency - clock_divider_low;
```

**Allowed abbreviations** are those whose abbreviated form is more universally
understood than the expanded form:

- Hardware protocol names: `i2c`, `spi`, `uart`, `can`, `usb`, `dma`
- Signal and peripheral names: `adc`, `dac`, `pwm`, `gpio`
- Common units and types: `irq`, `isr`, `mcu`
**Register names** are exempt from this rule. If a register is named `CR1` or
`PCLKDIV` in the datasheet, use that name directly. This makes it easier to
cross-reference code against the reference manual.

```cpp
// ✅ Matches the datasheet - acceptable
reg->CR1 |= enable_bit;
reg->PCLKDIV = divider;
```

If `cspell` flags an identifier that is a legitimate technical abbreviation or
a datasheet-derived name, add it to the project's `cspell.json` dictionary
rather than suppressing the check.

## S.3 Formatting

Most formatting is enforced automatically by `clang-format` and `pre-commit`.
The rules below either require developer judgment or explain the rationale
behind what the tools enforce.

### S.3.1 Line length

Keep lines within **80 characters**. `clang-format` handles this automatically.
For the rare case where wrapping would hurt readability more than the long line,
suppress with `clang-format off/on` and a comment explaining why:

```cpp
// clang-format off
// URL must remain intact for reference manual cross-linking
// https://some-very-long-datasheet-url.com/reference/register-map/section-12
// clang-format on
```

### S.3.2 File endings

All files must end with a newline character and use LF line endings. Trailing
whitespace is not permitted. These are enforced automatically by pre-commit and
do not require manual attention.

### S.3.3 Number radix for bit manipulation

When working with register values or bit masks, use only **binary** or **hex**.
Never use decimal or octal. They obscure the bit-level structure that matters
when reading hardware code.

```cpp
// ❌ Decimal and octal hide the bit pattern
u32 mask = 15;
u32 flags = 0377;

// ✅ Binary shows the bit pattern directly
constexpr auto mask = hal::bit_mask::from(0, 3);

// ✅ Hex is acceptable when the value comes from a datasheet
constexpr u32 pll_config = 0x0040'001F;
```

Use digit separators (`'`) to group bits into readable chunks for long binary
or hex literals:

```cpp
constexpr u32 config = 0b1000'0011'0000'0000;
constexpr u32 base_address = 0x4000'0000;
```

### S.3.4 Documentation

Every public API must be documented with Doxygen-style comments. This is
enforced by the `doxygen-check` pre-commit hook, undocumented public APIs
will fail CI.

```cpp
/**
 * @brief Set the output voltage level of the pin.
 *
 * @param p_high If true, drives the pin to the logic high voltage.
 *               If false, drives the pin to the logic low voltage.
 */
void level(bool p_high);
```

Document the *why* and *what*, not the *how*. Avoid restating the function
signature in prose. If a parameter has constraints or units, state them
explicitly.

Internal implementation details and private members do not require Doxygen
comments, but non-obvious logic should have inline `//` comments explaining
intent.

## S.4 Modules

libhal v5 and all libraries in the ecosystem use C++20 modules as the primary
compilation model. All new library code must be written as module files. Headers
still exist for compatibility with toolchains that do not yet support modules.
See [S.10 Headers](#s10-headers) if you need to work with them.

### S.4.1 File extensions

Two file types are used in a module-based library:

- **`.cppm`** - module interface files. These declare the public API of a module
  or partition. Every exported symbol lives in a `.cppm` file.
- **`.cpp`** - module implementation files. These provide definitions that
  belong to a module but are not part of its public interface. Use these to hide
  implementation details, such as the `impl` struct in the pimpl pattern.

```
modules/
  hal.cppm        ← primary module interface (re-exports all partitions)
  gpio.cppm       ← partition interface (public)
  gpio.cpp        ← partition implementation (hidden)
  units.cppm      ← partition interface (public)
```

### S.4.2 Module structure

Each library is organized as a single named module split into partitions. Each
partition covers one domain. The primary interface file re-exports all
partitions so consumers only need one import statement.

**Primary module interface** (`hal.cppm`):

```cpp
export module hal;

// Export partitions
export import :units;
export import :gpio;
export import :i2c;

// Export transitive dependencies
export import strong_ptr;
export import async_context;
```

**Module partition interface** (`gpio.cppm`):

```cpp
export module hal:gpio;

export import async_context;
export import :units;

namespace hal::inline v5 {
  export class input_pin { ... };
  export class output_pin : public input_pin { ... };
  export enum class edge_trigger : u8 { ... };
}
```

**Module partition implementation** (`gpio.cpp`):

```cpp
module hal:gpio;  // no 'export' keyword - this is an implementation unit

// Definitions, internal helpers, impl structs go here.
// Nothing in this file is visible to consumers of the module.
```

### S.4.3 Exporting declarations

Export individual declarations - classes, functions, enums, and type aliases -
using the `export` keyword on each one. Do not use `export namespace { ... }` as
it exports every symbol in the block, including internal helpers that should not
be part of the public API.

```cpp
// ❌ Exports everything in the namespace, including internals
export namespace hal::inline v5 {
  class input_pin { ... };
  enum class edge_trigger : u8 { ... };
  class internal_helper { ... };  // unintentionally exposed
}

// ✅ Exports only what is intentionally public
namespace hal::inline v5 {
  export class input_pin { ... };
  export enum class edge_trigger : u8 { ... };
  class internal_helper { ... };  // stays internal
}
```

### S.4.4 Global module fragment

Standard library headers and third-party C and C++ headers do not have module
interfaces. Include them in the **global module fragment**, which appears before
the `export module` declaration and is separated by a bare `module;` line.

```cpp
module;  // ← begins the global module fragment

#include <cstdint>
#include <chrono>
#include <span>

export module hal:units;  // ← global fragment ends here, module begins
```

Do not `#include` headers below the `export module` line. That is only valid
inside the global module fragment.

### S.4.5 Do not use `import std`

`import std` is not yet supported reliably across all compilers and toolchain
versions that libhal targets. Use individual standard library headers in the
global module fragment instead.

```cpp
// ❌ Not yet supported reliably
import std;

// ✅ Include individual headers in the global module fragment
module;
#include <cstdint>
#include <span>
#include <array>
export module hal:example;
```

### S.4.6 Versioned inline namespaces

All libhal ecosystem libraries use an inline versioned namespace for ABI
stability. The `inline` keyword makes the version suffix transparent to
consumers. See [S.2 Naming Conventions](#s2-naming-conventions) for the full
namespace naming rules.

```cpp
// hal uses hal::inline v5
namespace hal::inline v5 {
  export class output_pin { ... };
}

// async_context uses async::inline v0
namespace async::inline v0 {
  export class mutex { ... };
}
```

Consumers always write `hal::output_pin` and `async::mutex`. The version suffix
is never written externally and contributors should never need to reference it
directly.

### S.4.7 Registering modules in CMake

Every `.cppm` file must be listed in the `MODULES` argument of
`libhal_add_library`. Implementation `.cpp` files that belong to a module are
listed under `SOURCES`. The build system will not pick up either automatically.

```cmake
libhal_add_library(hal
  MODULES
    modules/hal.cppm
    modules/gpio.cppm
    modules/units.cppm
  SOURCES
    modules/gpio.cpp
)
```

## S.5 Bit Manipulation

Manual bit manipulation is error prone and hard to review. libhal provides
`hal::bit_modify`, `hal::bit_value`, and `hal::bit_extract` from `libhal-util`
to handle bit operations in a readable and verifiable way.

### S.5.1 Named compile-time bit masks

Always give bit masks names. Anonymous magic numbers in bit operations are
difficult to cross-reference against a datasheet and easy to get wrong.

Always prefer the template form of bit mask APIs over the runtime form. A
`constexpr` bit mask passed as a template argument gives the compiler full
knowledge of the operation at compile time, enabling significantly better
code generation.

```cpp
// ✅ Named, constexpr, template form
constexpr auto state   = hal::bit_mask::from(4, 5);
constexpr auto enable  = hal::bit_mask::from(3);
constexpr auto prescale = hal::bit_mask::from(6, 13);

hal::bit_modify(reg->control)
  .insert<prescale>(divider)
  .clear<lower_power_mode>()
  .set<enable>();

// ❌ Anonymous and runtime - no compiler optimization, no readability
reg->control = (reg->control & ~0x3F40) | ((divider << 6) & 0x3F40);
```

### S.5.2 `hal::bit_modify`

Use `hal::bit_modify` to read-modify-write a volatile hardware register.
It copies the register value to a temporary, applies all operations to the
temporary, then writes it back on destruction. This avoids multiple volatile
reads and writes.

```cpp
reg_t* reg = get_peripheral_register();

hal::bit_modify(reg->control)
  .insert<pre_scalar>(freq() / desired_frequency)
  .clear<lower_power_mode>()
  .set<enable>();
```

Chain all operations on the same register in a single `bit_modify` call.
This keeps the read-modify-write atomic with respect to the surrounding code
and produces tighter assembly.

### S.5.3 `hal::bit_value`

Use `hal::bit_value` to construct a register value entirely at compile time.
This is useful for default configurations and constants that are known before
runtime.

```cpp
constexpr auto default_pin_config = hal::bit_value(0U)
  .insert<mode>(0x04)
  .clear<high_slew_rate>()
  .set<high_speed_mode>()
  .to<std::uint32_t>();
```

**Tail chaining** - calling the next method directly on the return value of the
previous keeps the entire lifetime of the object visible to the compiler.
This allows GCC and Clang to collapse the chain into a single constant,
producing optimal code with no runtime cost.

### S.5.4 `hal::bit_extract`

Use `hal::bit_extract` to read a field out of a register value.

```cpp
// Polling on a status bit
while (hal::bit_extract<state>(reg->status) == states::busy) {
  continue;
}

// Extracting a multi-bit ADC result
float my_adc::driver_read() {
  constexpr auto capture_value = hal::bit_mask::from(4, 11);
  return hal::bit_extract<capture_value>(reg->status);
}
```

### S.5.5 Exception: native shift and OR for concatenation

When assembling a value from multiple bytes rather than operating on a single
register field, native shift and OR can be clearer than `bit_value`. This
commonly arises when combining bytes read from a sensor over I2C or SPI.

```cpp
// ✅ Readable concatenation with native syntax
auto data = hal::write_then_read<2>(m_i2c, 0x11, addr, timeout);
std::uint32_t val = data[0] << 4 | data[1] >> 4;
```

Choose whichever form is clearer for the specific operation. The goal is
reviewability, not mechanical rule-following.

## S.6 Classes & Types

### S.6.1 Declaration order

Class sections must appear in this order: public, then protected, then private.
Omit any section that would be empty.

Within each section, follow this order:

1. Types and type aliases (`using`, `enum class`, nested structs and classes)
2. Static constants
3. Factory functions
4. Constructors and assignment operators
5. Destructor
6. All other member functions
7. All other data members

```cpp
class my_driver {
public:
  // 1. Types
  struct settings {
    hal::hertz frequency = 100'000 * mp_units::si::hertz;
  };

  // 3. Factory
  static hal::deferred_ptr<my_driver> create(async::context& p_context,
                                              hal::ptr<hal::i2c> p_i2c,
                                              settings const& p_settings);
  // 4. Constructors
  my_driver(private_key, hal::ptr<hal::i2c> p_i2c);

  // 5. Destructor
  ~my_driver() override = default;

  // 6. Member functions
  async::future<hal::celsius> read_temperature(async::context& p_context);

private:
  // 7. Data members
  hal::ptr<hal::i2c> m_i2c;
};
```

Do not define large method bodies inline within the class definition. Only
trivial or performance-critical methods that are very short may be defined
inline. Template classes are an exception as they must be defined within a
module interface file.

### S.6.2 Storing dependencies

Any dependency captured as a class member must be stored as `hal::ptr<T>`.
`hal::ptr<T>` is a non-nullable reference-counted smart pointer that keeps
the dependency alive for at least as long as the object holding it.

```cpp
// ❌ Raw pointer gives no ownership or lifetime guarantee
class my_driver {
  hal::i2c* m_i2c;
};

// ❌ Reference member deletes copy and move constructors
class my_driver {
  hal::i2c& m_i2c;
};

// ✅ hal::ptr expresses ownership and prevents use-after-free
class my_driver {
  hal::ptr<hal::i2c> m_i2c;
};
```

Raw references remain correct for parameters that are consumed within the
current call and not retained. The rule is strictly about what gets stored
in a member variable.

```cpp
// ✅ Reference is fine here - p_settings is consumed and not stored
void configure(hal::i2c& p_bus, settings const& p_settings);

// ✅ hal::ptr required here - p_i2c is stored as m_i2c
my_driver(private_key, hal::ptr<hal::i2c> p_i2c)
  : m_i2c(p_i2c)
{}
```

### S.6.3 Avoid `bool` as a member

`bool` has poor information density as it occupies a full byte per entry. A
single `bool` member is acceptable. When multiple boolean flags are needed,
use `std::bitset` with named `constexpr` index positions to pack them into
the minimum footprint.

```cpp
// ❌ Three separate bytes for three flags
bool m_enabled;
bool m_inverted;
bool m_open_drain;

// ✅ Three bits packed into one word
static constexpr std::size_t enabled_bit    = 0;
static constexpr std::size_t inverted_bit   = 1;
static constexpr std::size_t open_drain_bit = 2;
std::bitset<3> m_flags;
```

!!! note
    `std::bitset` uses a backing block of `unsigned long` internally. On
    32-bit architectures this means a `bitset` of any size from 1 to 32 bits
    still occupies 4 bytes. Pack enough flags together to make that footprint
    worthwhile.

### S.6.4 Avoid `bool` as a parameter

Boolean parameters at a call site are unreadable without looking up the
function signature. See
["Clean code: The curse of a boolean parameter"](https://medium.com/@amlcurran/clean-code-the-curse-of-a-boolean-parameter-c237a830b7a3)
for a detailed treatment.

```cpp
// ❌ What does 'false' mean here?
pin.configure(true, false, false);

// ✅ Each state is self-describing at the call site
pin.configure(pin_direction::output,
              pin_drive::push_pull,
              pin_resistor::none);
```

A `bool` parameter is acceptable when it is the only parameter and reads
naturally as a logical switch at the call site.

```cpp
// ✅ Reads clearly without context
led.level(true);
led.level(false);
```

!!! note
    A `hal::bool` type is planned for a future release. It will provide a
    type-safe named boolean that is self-documenting at call sites without
    requiring a full enum. This section will be updated when it lands.

### S.6.5 `[[nodiscard]]`

Apply `[[nodiscard]]` to any function whose return value being discarded is
almost certainly a bug. The primary case is factory functions: discarding the
return value of `create()` constructs and immediately destroys the driver
without it ever being used.

```cpp
// ✅ Compiler error if the caller drops the return value
[[nodiscard]] static hal::deferred_ptr<my_driver> create(
  async::context& p_context,
  hal::ptr<hal::i2c> p_i2c,
  settings const& p_settings);
```

When the reason a discard is wrong is not obvious from the function name alone,
add a string message to `[[nodiscard]]` so the compiler diagnostic is
self-explanatory.

```cpp
[[nodiscard("Discarding the handle releases the lock immediately.")]]
lock_guard acquire_lock();
```

Do not apply `[[nodiscard]]` to functions that are called primarily for their
side effects or where ignoring the return value is a legitimate pattern.

```cpp
// ❌ Doesn't make sense - called for its side effect
[[nodiscard]] void reset();
```

## S.7 Restrictions

### S.7.1 Avoid macros

Only use macros when something cannot be expressed any other way. In practice
this is extremely rare. Nearly every macro can be replaced with `constexpr`
variables, `constexpr` functions, or templates.

```cpp
// ❌ Macro with no justification
#define MAX_CHANNELS 8
#define CLAMP(x, lo, hi) ((x) < (lo) ? (lo) : (x) > (hi) ? (hi) : (x))

// ✅ constexpr equivalents
constexpr std::size_t max_channels = 8;

template<typename T>
constexpr T clamp(T x, T lo, T hi) {
  return std::clamp(x, lo, hi);
}
```

Only use preprocessor `#if` when `if constexpr` cannot achieve the same result.

### S.7.2 Never include `<iostream>`

Including any `<iostream>` header incurs an automatic 150 kB binary size
penalty. This happens even if the code never calls `std::cout` or any related
function, as the global stream objects are constructed unconditionally at
startup.

```cpp
// ❌ Never in library or driver code
#include <iostream>
#include <ostream>
#include <sstream>
```

`<iostream>` may be used in libraries that exclusively target host-side unit
testing and are never compiled for embedded targets.

### S.7.3 Use PMR for allocation

Raw heap allocation via `new`, `delete`, `malloc`, or `free` is forbidden in
all libhal libraries. These bypass the caller's memory strategy, are
incompatible with systems that have no heap, and make it impossible to use
custom allocators for specific memory regions such as DMA-capable RAM.

All allocation must go through `std::pmr::memory_resource`. The caller provides
the allocator, giving application developers full control over where memory
comes from.

```cpp
// ❌ Raw heap allocation - bypasses caller's memory strategy
class my_driver {
  my_driver() {
    m_buffer = new std::byte[256];
  }
  std::byte* m_buffer;
};

// ✅ PMR allocation - caller controls where memory comes from
class my_driver {
  my_driver(std::pmr::memory_resource* p_resource, std::size_t p_size)
    : m_buffer(p_resource, p_size)
  {}
  hal::allocated_buffer<std::byte> m_buffer;
};
```

When a fixed-size region of memory is needed, prefer `hal::allocated_buffer<T>`
over `std::pmr::vector<T>`. `allocated_buffer` only works with default
constructible types, keeping it appropriate for buffers of integral types or
pre-allocated object slots. `std::pmr::vector` permits resizing after
construction, which violates the rule that allocation happens at startup and
not during normal operation.

Allocation should happen at object construction time, not during normal
operation. A driver that allocates during a read or write call is
incompatible with real-time systems and deterministic memory budgets.

### S.7.4 Avoid `std::atomic` in device libraries

`std::atomic` has portability issues across architectures and is not guaranteed
to be available or lock-free on all targets that device libraries must support.
Device libraries must compile and run correctly on any architecture.

```cpp
// ❌ Not portable across all device library targets
std::atomic<bool> m_busy = false;

// ✅ Design around the async model instead
async::mutex m_access;
```

Platform libraries and processor libraries may use `std::atomic` when the
target architecture and toolchain are known to support it.

### S.7.5 Avoid `<thread>`

Embedded toolchains do not provide `<thread>`. Including it will fail to
compile when cross-compiling for any baremetal target. Use the async context
model for concurrency instead.

```cpp
// ❌ Will not compile on baremetal targets
#include <thread>
std::thread worker([]{ ... });

// ✅ Use async context for concurrent work
async::future<void> worker(async::context& p_context) {
  co_await do_work(p_context);
}
```

!!! note
    libhal does plan to provide `<thread>`-compatible implementations for
    application developers building on top of libhal. These implementations
    are intended for end users and their applications. They must not be used
    within libhal libraries themselves.

### S.7.6 No logging from drivers

Drivers must not write to stdout or stderr. This means no calls to:

- `std::printf` / `std::fprintf`
- `std::puts` / `std::fputs`
- `std::print` / `std::println` (C++26)

The role of logging belongs to the application, not its drivers. A driver that
logs on every read or write is as surprising as a file I/O library that spams
the console on every operation.

```cpp
// ❌ Driver owns no logging responsibility
async::future<hal::celsius> read_temperature(async::context& p_ctx) {
  auto raw = co_await read_raw(p_ctx);
  std::printf("raw=%d\n", raw);   // never do this
  co_return to_celsius(raw);
}

// ✅ Return the value and let the application decide what to do with it
async::future<hal::celsius> read_temperature(async::context& p_ctx) {
  auto raw = co_await read_raw(p_ctx);
  co_return to_celsius(raw);
}
```

!!! note
    S.7.2 already prohibits `<iostream>` for binary size reasons. This rule
    covers the remaining C-style output functions that do not carry the same
    penalty but still violate driver responsibility boundaries.

### S.7.7 No halting or termination

Drivers must not stop execution. The following are forbidden in driver code:

- `std::abort()`
- `std::exit()` and `std::quick_exit()`
- `std::terminate()`
- Infinite loops that never yield control

An application must always retain the ability to decide what happens when
something goes wrong. Drivers surface errors through exceptions and return
control to the caller. The application then decides whether to retry, log, shut
down, or recover.

```cpp
// ❌ Driver takes control away from the application
if (!initialized) {
  std::abort();
}

// ❌ Spin loop with no exit - hangs the system permanently
while (!(reg->status & ready_bit)) {}

// ✅ Throw and let the application handle it
if (!initialized) {
  throw hal::not_initialized{};
}

// ✅ Yield to the scheduler while waiting
while (hal::bit_extract<ready>(reg->status) == 0) {
  co_await async::yield(p_ctx);
}
```

### S.7.8 Avoid `noexcept`

Do not annotate functions with `noexcept`. Since C++17, `noexcept` is part of
a function's type. Removing it in a later version is a breaking ABI change.
libhal keeps the option open for which APIs throw as the library evolves.
Committing to `noexcept` prematurely closes that door.

```cpp
// ❌ ABI commitment - cannot be un-noexcept without breaking callers
[[nodiscard]] hal::result<std::uint16_t> read_sample() noexcept;

// ✅ No annotation - unannotated functions are implicitly potentially-throwing
[[nodiscard]] hal::result<std::uint16_t> read_sample();
```

## S.8 Namespace Hygiene

### S.8.1 Stay within a designated namespace

All libhal code must live within the `hal` namespace or a library-specific
namespace. Never place symbols in the global namespace or in `std`.

```cpp
// ❌ Global namespace pollution
class output_pin { ... };
void configure_pin(output_pin& p_pin);

// ✅ Scoped to the library namespace
namespace hal::lpc40 {
  class output_pin { ... };
  void configure_pin(output_pin& p_pin);
}
```

Headers included via the global module fragment may introduce global
namespace symbols. Do not re-expose them and do not rely on their names
being available outside the translation unit that includes them.

### S.8.2 Keep the `hal` namespace clean

The `hal` namespace is shared across the entire ecosystem. Keep it clean by
nesting implementation details, register maps, and bit mask definitions inside
the class that uses them rather than placing them directly in `hal`.

```cpp
// ❌ Register and mask types pollute the shared namespace
namespace hal {
  struct uart_register_map { ... };
  struct uart_control1 { ... };
  class uart { ... };
}

// ✅ Implementation details are nested inside the class
namespace hal::lpc40 {
  class uart {
    struct register_map {
      std::uint32_t control1;
      std::uint32_t control2;
      std::uint32_t data;
      std::uint32_t status;
    };

    struct control1_register {
      static constexpr auto baud_divisor = hal::bit_mask::from(0, 15);
      static constexpr auto enable       = hal::bit_mask::from(16);
    };
  };
}
```

In general these implementation details should be entirely within the module
implementation .cpp file. Anything defined there is invisible to consumers
regardless of whether it carries export, keeping the interface file and
namespace focused solely on the public API.

## S.9 Third-Party Libraries

### S.9.1 Prefer package manager integration

Add third-party dependencies as `requires` entries in `conanfile.py`. Source
integration adds maintenance burden and complicates license tracking. Reserve it
for libraries not available through Conan Center or the libhal Conan registry.

```python
# ✅ Declared as a package dependency
def requirements(self):
    self.requires("etl/20.38.17")
    self.requires("strong_ptr/1.0.0")
```

```
# ❌ Vendored source when a package is available
third_party/
  etl/   ← avoid when a Conan package exists
```

### S.9.2 Source integration rules

When a library has no suitable package, vendor it into `third_party/<name>/` at
the repository root. The first commit must be the pristine upstream source with
no modifications. This keeps future diffs against upstream unambiguous.

```
third_party/
  minimp3/          ← committed unmodified at upstream v0.9.9.0
    minimp3.h
```

Add the directory to CMake's include path so it can be used in the global module
fragment (see [S.4.4](style.md#s44-global-module-fragment)):

```cmake
target_include_directories(hal PRIVATE third_party/minimp3)
```

If a modification becomes necessary, add a block at the top of the modified file
listing every change:

```cpp
/**
 * [libhal] modifications:
 *
 *   1. Replaced malloc/free with user-provided allocator callbacks.
 *   2. Removed use of POSIX file I/O.
 */

/**
 * <ORIGINAL LICENSE>
 */
```

Verify that the library's license permits distribution and modification before
integrating it.

### S.9.3 Compatibility requirements

Any third-party library used outside a platform library must compile and operate
correctly on all libhal targets: baremetal 32-bit MCUs, Linux, macOS, and
Windows. A library fails this requirement if it:

**Allocates after construction.** Allocation must happen at construction time
through `std::pmr::memory_resource`. Libraries that call `malloc`, `new`, or
`free` during normal operation (reads, writes, callbacks) are not permitted.
If source integration is used, those allocation sites must be replaced and
tracked as modifications per [S.9.2](#s92-source-integration-rules).

```cpp
// ❌ Allocation during operation - incompatible with real-time memory budgets
void codec_process(frame_t* p_frame) {
  auto* buf = new uint8_t[256];   // forbidden
  ...
}

// ✅ PMR allocation at construction time
class codec {
  codec(std::pmr::memory_resource* p_resource)
    : m_buffer(p_resource, 256) {}
  hal::allocated_buffer<std::uint8_t> m_buffer;
};
```

**Calls platform-specific APIs.** POSIX file I/O (`open`, `read`, `write`),
Windows APIs (`CreateFile`, `VirtualAlloc`), or Linux-specific syscalls are
forbidden. See [D.6 Portable](./philosophy.md#d6-portable).

```cpp
// ❌ POSIX - does not compile on baremetal
int fd = ::open("/dev/ttyUSB0", O_RDWR);

// ❌ Windows API - does not compile outside Windows
HANDLE h = CreateFileA("COM3", GENERIC_READ | GENERIC_WRITE, ...);
```

**Contains architecture-specific intrinsics or inline assembly.** ARM CMSIS
intrinsics, x86 SIMD, RISC-V CSR access, or any inline assembly must not appear
outside a platform library.

```cpp
// ❌ ARM-only - breaks on RISC-V and host targets
__DSB();
uint32_t val = __get_PRIMASK();

// ❌ x86 SIMD - breaks on 32-bit MCUs
__m128i result = _mm_add_epi32(a, b);
```

### S.9.4 Exceptions

The following categories are exempt from the portability requirement because
they are inherently platform-specific:

- **RTOS libraries** (FreeRTOS, Zephyr RTOS kernel): permitted only inside
  platform libraries where the target is known. Never a dependency of a device
  library or interface library.
- **Platform Specific API** (POSIX, Win32 APIs): permitted only inside
  platform libraries where the target is known.
- **Exception handling and runtime libraries** (`libexcept`, `libunwind`): core
  infrastructure with dedicated ports per target, vetted separately from the
  normal compatibility review.
- **

---

## S.10 Headers (Legacy / Compatibility)

libhal v5 uses C++20 modules as the primary compilation model. All new library
code must be written as module files. Headers exist only for:

- wrapping third-party C APIs for use in the global module fragment (see
  [S.4.4](style.md#s44-global-module-fragment))
- compatibility builds targeting toolchains without module support

Do not create new `.hpp` headers for library code. When working in a
compatibility context, follow the rules below.

### S.10.1 Self-contained and extension

Every header must compile correctly on its own without relying on symbols
provided by a prior include in whatever translation unit includes it.

Use `.hpp` for C++ headers and `.h` for C headers.

### S.10.2 Include guards

Use `#pragma once`. Do not use `#ifndef` guards.

```cpp
// ❌ Verbose and collision-prone
#ifndef HAL_GPIO_HPP_
#define HAL_GPIO_HPP_
// ...
#endif  // HAL_GPIO_HPP_

// ✅ Simple and sufficient
#pragma once
```

### S.10.3 Include what you use

Include a header for every symbol used directly. Do not rely on transitive
includes. A symbol appearing because another header pulls it in is not part of
that header's API contract and may disappear at any time.

```cpp
// ❌ Assumes <cstdint> arrives transitively
#pragma once
void set_baud(std::uint32_t p_rate);

// ✅ Declares its own dependency
#pragma once
#include <cstdint>
void set_baud(std::uint32_t p_rate);
```

Also remember to remove unused headers.

### S.10.4 Include order

Group includes in the order below, separated by blank lines. Within each group,
`clang-format` sorts alphabetically, do not do it manually.

1. C standard library headers, using `<>` (`<cstdint>`, `<cstring>`)
2. C third-party headers, using `<>` (`<minimp3.h>`)
3. C++ standard library headers, using `<>` (`<array>`, `<span>`)
4. C++ third-party and libhal ecosystem headers, using `<>` (`<libhal-util/serial.hpp>`)
5. Local project headers, using `""` (`"resource_list.hpp"`)

```cpp
#pragma once

// 1. C standard library
#include <cstdint>
#include <cstring>

// 2. C third-party
#include <minimp3.h>

// 3. C++ standard library
#include <array>
#include <span>

// 4. C++ third-party / libhal ecosystem
#include <libhal-util/serial.hpp>
#include <libhal-util/steady_clock.hpp>

// 5. Local project
#include "resource_list.hpp"
```

!!! note
    In test files, `boost.ut` must always be the last include. It overloads
    `operator<<` for `ostream` and must see prior type declarations to generate
    correct output for test failures.

## S.11 Memory-Mapped I/O

Peripheral registers on microcontrollers are accessed by reading and writing
to fixed physical addresses. This section covers how to declare, address, and
access those registers correctly and safely.

### S.11.1 Declare register maps as `volatile` structs

Model a peripheral's register block as a plain struct where every hardware
register is a `volatile` unsigned integer member. The struct must be
standard-layout so that `sizeof` and `offsetof` are reliable.

```cpp
struct register_map {
  volatile std::uint32_t control;    // offset 0x00
  volatile std::uint32_t status;     // offset 0x04
  volatile std::uint32_t data;       // offset 0x08
  std::uint32_t          reserved0;  // offset 0x0C - unused, not volatile
  volatile std::uint32_t baud_rate;  // offset 0x10
};
```

Every readable or writable hardware register must be `volatile`. Reserved or
unused registers that are never accessed do not need to be `volatile`, but
must still be present to maintain correct offsets.

Use `std::uint32_t`, `std::uint16_t`, or `std::uint8_t` to match the register
width specified in the datasheet. Never use `int` or `unsigned int` directly
as their width is implementation-defined.

### S.11.2 Why `volatile` is mandatory

Without `volatile`, the compiler may cache a register's value in a CPU register
and skip subsequent reads, or eliminate writes it considers redundant. Hardware
registers change independently of the CPU, via peripherals, DMA engines, or
interrupts, so every access must reach the hardware.

```cpp
// ❌ Without volatile, the compiler may hoist the read out of the loop
struct register_map {
  std::uint32_t status;   // missing volatile
};

// The compiler sees no writes to status and may transform this into:
//   if (reg->status & ready_bit) { while(true) {} }
while (!(reg->status & ready_bit)) {}

// ✅ volatile forces every iteration to re-read from the hardware address
struct register_map {
  volatile std::uint32_t status;
};
```

### S.11.3 Obtain the register pointer via `reinterpret_cast`

Declare the peripheral base address as a `constexpr std::uintptr_t` and cast
it to a pointer once. Store and pass the typed pointer, never the raw integer.

```cpp
// ✅ Address constant is named and traced to the datasheet
constexpr std::uintptr_t uart0_base = 0x4000'C000;

register_map* reg = reinterpret_cast<register_map*>(uart0_base);

hal::bit_modify(reg->control).set<enable>();
```

```cpp
// ❌ Casting at every use site - type is implicit, address is not named
*reinterpret_cast<std::uint32_t*>(0x4000'C004) |= 0x1;
```

`reinterpret_cast` is the only sanctioned cast for this operation. Do not use
C-style casts.

### S.11.4 Scope register maps to the translation unit

Register map structs and their associated bit mask definitions belong in an
anonymous namespace inside the module implementation `.cpp` file. Anonymous
namespace linkage makes them invisible outside the translation unit, so no
naming ceremony is required. Use plain descriptive names.

```cpp
// In gpio.cpp (module implementation - not visible to consumers)
module hal:gpio;

namespace {

struct register_map {
  volatile std::uint32_t direction;
  volatile std::uint32_t mask;
  volatile std::uint32_t pin;
  volatile std::uint32_t set;
  volatile std::uint32_t clear;
};

struct direction_register {
  static constexpr auto output = hal::bit_mask::from(0);
};

} // namespace
```

### S.11.5 Assert layout with `static_assert`

Use `static_assert` on `sizeof` and `offsetof` to verify that the struct layout
matches the datasheet. Accidental padding shifts every subsequent register by
the padding amount, producing silent hardware bugs.

```cpp
static_assert(sizeof(register_map) == 0x14,
              "register_map size does not match datasheet");
static_assert(offsetof(register_map, baud_rate) == 0x10,
              "baud_rate offset does not match datasheet");
```

Add one `static_assert` per register that has a known offset in the datasheet.
This is the only mechanical check that catches struct layout errors at compile
time.
