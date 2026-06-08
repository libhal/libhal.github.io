# ‼️ Error Handling Design Philosophy

## Core Principle

The primary objective for APIs is to make invalid inputs
**impossible to represent**. Every other error handling mechanism is a fallback
for when that isn't achievable.

---

## The Decision Hierarchy

### 1. Unrepresentable at the Type Level

The strongest defense is the type system. If invalid inputs cannot be
expressed, no runtime check is needed.

libhal provides `<libhal/initializers.hpp>` which encodes hardware selectors as **template parameters**, not runtime values. `port<5>`, `pin<17>`, `bus<3>`, `channel<0>` are distinct types — the number is baked into the type at compile time and cannot be a runtime variable. An invalid selector cannot be constructed at all without a compile error:

```cpp
// Example output_pin only has ports 0 to 3, pins 0 to 15
hal::example::output_pin pin(hal::port<1>, hal::pin<11>); // fine
hal::example::output_pin pin(hal::port<8>, hal::pin<0>); // ❌ invalid port > 8

// Example
hal::example::output_pin(hal::port_param auto p_port, hal::pin_param auto p_pin)
{
  static_assert(p_port() <= 3,
                "example platform only supports GPIO ports 0 to 3");
  static_assert(p_pin() <= 15,
                "example platform only supports GPIO pin 0 to 15");
}
```

This is a stronger guarantee than `consteval` constructors. There is no object
to construct with a wrong value, the value *is* the type. For cases not covered
by template parameters (note: the above expression with `auto` is called an
abbreviated function template parameter):

- Use strongly typed enums (`enum class`/`enum struct`) as the input parameter
  instead of integers.
- Use `consteval` constructors to catch invalid compile-time literals as
  compiler errors
- Use/create bounded types to constrain value ranges at the API boundary

If an API is hard to use without a mistake (footgun), then the API should be considered for deprecation if its already released. If the API has not been released, then **API elimination** should be considered. API elimination removes APIs that structurally permit invalid states before they reach the codebase.

For example, consider the following APIs:

```C++
// This driver controls 8-bidirectional pins. Each can be enabled
class gate_controller_8_channel {
  // Turns on
  void enable_port(u8 p_port); // turns on p_port, must be between 0 and 8
  void disable_port(u8 p_port); // turns on p_port, must be between 0 and 8
  void configure_port(std::bitset<8> p_port);  // configures ports based on the
                                               // bitset.
};
```

APIs such as `enable_port(n)` / `disable_port(n)` have preconditions on the
input parameter, means that its possible to pass an invalid value to these APIs.
Replacing both with `multi_port_control(std::bitset<8>)` eliminates the error
surface entirely while also being more performant. The invalid state is gone,
not guarded against.

**Practical caveat on enums**: Enums are leaky - `port_flag(42)` compiles
silently. A strong wrapper class with private constructor and named factory
methods moves the gap to value creation and away from its usage.

### 2. Clamp / Saturate

Valid **only** when the nearest in-bounds value preserves the
**semantic intent** of the operation. The key question is:
*does the clamped value still mean what the caller intended?*

**Good example — motor control**: A motor interface accepting power in the
range `[-1.0, 1.0]`. If a caller passes `1.5`, clamping to `1.0` still means
"maximum power forward." The intent is preserved. The system may not perform
optimally, but it behaves correctly and safely within its operational envelope.

**Bad example — I2C multiplexer**: An I2C MUX is typically used when multiple
devices share the same address — for example, two temperature sensors at the
same address, one measuring oven interior temperature and one measuring
exterior. If incorrect port selection silently falls back to the nearest valid port, then the system may read from the wrong sensor. The caller intended a specific physical device but due to the clamped value a different one was communicated with.

**The rule**: Clamp when the boundary is a magnitude limit. Never clamp when the value selects identity — a device, a channel, a resource.

### 3. Errors

> **Note**: This section discusses the policy for errors in general, regardless
> of the signaling mechanism used. libhal defaults to exceptions as its error
> handling mechanism, but the principles here apply equally to any error
> representation (result types, error codes, etc.). Where "catch block" is used
> below, read it as "error handling site" for non-exception systems.

Reserved strictly for **runtime conditions outside the programmer's control**,
where a meaningful, non-trivial error handling site can be written.

Before adding any error type, the question must be answered:
*what does the caller actually do with this?* If the answer is vague, it is not
an error — it is a contract violation.

**Good example**: A device-not-found error during I2C initialization. The
application may be scanning for available devices, and absence is a valid
runtime discovery. The handler has real work to do — try a different address,
fall back to a default device, trigger a hardware reset. Another example would
be a spotty device that may need occasional resetting to appear on the bus
again.

**Bad example**: An out-of-bounds index computed from a math error in the
calling code. No handler can fix broken math. The error will either be
swallowed silently — masking the bug — or propagate to terminate anyway. A
contract violation is the correct tool.

**Exception anti-patterns**: Sometimes an error seems like the appropriate
answer to a problem, but error propagation is bottom up which may violate the
intentions of an error. Consider timeout checking. If a timeout has been
detected deep within a call chain, that function may emit an error and
propagate it up. The problem with timeout errors is that they can be swallowed
by intermediate functions before it reaches the code with authority to act on
it. Timeout and cancellation authority belongs at the top. This is why contract
violations are the correct tool because the application developer gets to
choose what the contract violation should do for the specific application.

### 4. Contracts (`pre()` / C++26)

For true precondition violations where no interpretation of the input is
meaningful or safe, and no catch block could resolve the condition.

Contract violations default to `std::terminate`, but with diagnostics such as, file, line, condition text, and a customizable violation handler. For embedded
targets this handler can log and reset rather than spin. This is terminate
*with context*, not bare terminate.

**When to use**: The value is wrong because the calling code has a bug, and the nearest valid value would silently do something semantically incorrect or dangerous.

**Interim approach (pre-C++26)**: Call `std::terminate`. This is intentionally blunt — a precondition violation is a bug, and a crash with a clear call site is more honest and debuggable than silent corruption. Migration to C++26 contracts later will add diagnostics and a configurable violation handler without changing the fundamental semantics.

---

## Summary Table

| Situation                                                  | Tool                                 |
| ---------------------------------------------------------- | ------------------------------------ |
| Invalid input is structurally expressible                  | Type system / enum flags / consteval |
| Out-of-bounds where boundary preserves intent              | Clamp / saturate                     |
| Runtime condition, meaningful handler with concrete action | Error (exception in libhal)          |
| Precondition violated, no sane interpretation exists       | Contract violation                   |
| Unhandled exception reaches top of stack                   | `std::terminate`                     |
| Graceful system shutdown                                   | `std::terminate`                     |

---

## The Guiding Test

For any error condition, ask in order:

1. Can the type system make this unrepresentable?
2. Does the nearest valid value still mean what the caller intended?
3. Is there a non-trivial, concrete action a catch block can take to resolve this at runtime?
4. If none of the above — it is a contract violation.
