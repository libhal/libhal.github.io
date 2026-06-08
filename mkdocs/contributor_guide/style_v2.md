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
// ✅ Matches the datasheet — acceptable
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
Never use decimal or octal — they obscure the bit-level structure that matters
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
enforced by the `doxygen-check` pre-commit hook — undocumented public APIs
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

- **`.cppm`** — module interface files. These declare the public API of a module
  or partition. Every exported symbol lives in a `.cppm` file.
- **`.cpp`** — module implementation files. These provide definitions that
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
module hal:gpio;  // no 'export' keyword — this is an implementation unit

// Definitions, internal helpers, impl structs go here.
// Nothing in this file is visible to consumers of the module.
```

### S.4.3 Exporting declarations

Export individual declarations — classes, functions, enums, and type aliases —
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
