# 🔗 Interface Design Philosophy

Interfaces are the foundation and building blocks of libhal. They are the "A"
and "L" in HAL: hardware abstraction layer. They present a generalized ideal of
a particular aspect of hardware or computing. For example and output pin
represents a pin that can have its output voltage level state changed from a
logical true or false value, which may be represented as a LOW voltage or HIGH
voltage depending on the device.

The following guidelines describe what should be kept in mind when creating an
interface.

Here is an example of some interfaces in libhal. It is recommended to take a
look at these to get an idea of how the interfaces are written.

- [hal::adc](https://github.com/libhal/libhal/blob/main/include/libhal/adc.hpp)
- [hal::serial](https://github.com/libhal/libhal/blob/main/include/libhal/serial.hpp)
- [hal::i2c](https://github.com/libhal/libhal/blob/main/include/libhal/i2c.hpp)
- [hal::spi](https://github.com/libhal/libhal/blob/main/include/libhal/spi.hpp)
- [hal::can](https://github.com/libhal/libhal/blob/main/include/libhal/can.hpp)
- [hal::dac](https://github.com/libhal/libhal/blob/main/include/libhal/dac.hpp)
- [hal::stream_dac](https://github.com/libhal/libhal/blob/main/include/libhal/stream_dac.hpp)

## Smallest Possible v-table

When designing an interface aim to have the least number of virtual functions
as possible.

**Why?**

Each virtual function in the interface will require a v-table entry (a pointer)
in the v-table of each implementation of an interface. Each entry takes up
space in the `.text` or `.rodata` sections of the binary. The more you have the
more space is taken up.

**Consider:**

Combining APIs if it is possible. For example, lets consider `hal::output_pin`
and `hal::i2c`.

`hal::output_pin` could have had a `::high()` and `::low()` API for setting the
pins state. But these could easily be combined into a single API such as
`::level(bool)` which accepts the state as an input parameter.

`hal::i2c` could have had `::write(...)`, `::read(...)`, and
`::write_then_read(...)`. Instead, we have `transaction()` which can determine
which of the 3 communication methods to use depending on whether or not the
write and read buffers are supplied. If only one is available, then it will
perform the respective `write` or `read` operation.

## Make virtual functions pure virtual

Interface API implementations are the responsibility of the implementer to be
implemented.

**Why?**

In almost all cases, default behavior does not make sense.

**Consider:**

The exception to this rule is when a new virtual API is added to the end of the
virtual API list. In order to be backwards compatible, the new API MUST be
implemented with default behavior. Adding a new virtual API is a last resort
and adding a new interface or an additional public class function should be
preferred if it can solve the issue.

## Eliminate viral behavior

Another way to say this is, "consider the overhead by the developer."
This can be space & time overhead in the program or simply the overhead
required by the developer in order to use your API correctly.

**Why?**

Consider the following example of viral behavior through narrow contracts.

Consider this line of code `dac.write(value)`. The input to the `write` function
only accepts values from `0.0f` to `1.0f`. If value is greater or smaller than
this then it is undefined behavior. The developer, to eliminate this undefined
behavior they must do the following: `dac.write(std::clamp(value, 0.0f, 1.0f))`.
This works. The concern here is that now all code that calls this function
MUST add this clamp to ensure that the behavior is well defined OR have some
other mechanism in place to ensure that value does no exceed the narrow
contract of the `write` function. This becomes a vector for bugs and issues in
the code. This viral behavior also leads to duplication of the same clamp code
throughout the application developer's code as well as the interface
implementation code. A well designed implementation would either check that the
input is within the bounds allowed and potentially emit an error or clamp the
value for the user. Now the clamp code is performed at the call site as well as
the implementation. This is a waste of cycles and space.

**Consider:**

Consider what the caller of API will have to do in order to use your API
correctly as well as the implementor of the API. In the example above, the
solution to this viral behavior is to make the narrow contract into a wide
contract where the public API clamps the input for the user, making all input
(besides `NaN`), valid input. That way, the caller can be assured that their
input will be clamped and the implementor can be assured that the value they
get will ALWAYS be the expected values.

Viral behavior can come in different forms that narrow and wide contracts, so
great consideration must be taken when writing an API to eliminate such viral
behavior.

## Private virtual functions

Make virtual functions private. Make them callable via a public interface. Like
so:

```C++
class my_interface {
public:
  void foo() {
    driver_foo();
  }
  bool bar() {
    return driver_bar();
  }
private:
  virtual void driver_foo() = 0;
  virtual bool driver_bar() = 0;
};
```

**Why?**

If, in the event we need to modify the calling convention of a virtual API, we
can do so by altering the public API.

**Consider:**

`hal::motor` and `hal::dac` originally had narrow contracts which were widened
to remove eliminate viral behavior. Previously `hal::motor` could only accept
values from `-1.0f` to `+1.0f`. Anything beyond that would result in undefined
behavior. This resulting in two large issues, viral behavior and undefined
behavior. The first causes code bloat in terms of code size, and visual noise
to the reader due to the code needed to clamp the input to motor's `power()`
API. The second will cause potentially severe and hard to find bugs in the code
which is unacceptable. To resolve this issue, the public API was updated to
clamp the input from the caller before passing the info to the virtual API.
This eliminates the need for the calling code to bounds check the value as well
as eliminates the need for the virtual function implementation to bounds check
the input value. This allows for backwards compatible updates to how a virtual
API is called.

```C++
class motor
{
public:
  void power(float p_power)
  {
    auto clamped_power = std::clamp(p_power, -1.0f, +1.0f);
    return driver_power(clamped_power);
  }

private:
  virtual void driver_power(float p_power) = 0;
};
```

!!! note

    This change is backwards API compatible and ABI compatible but may not be
    link time compatible, since there may be two definitions of the same class
    function between statically linked binaries.

## Consider the stack, ram and rom requirements of an API

Some API designs have the unwanted side effect of causing the user to provide
or allocate a large buffer in order to operate. For example:

```c++
class big_buffer {
public:
  struct big_struct {
    std::array<hal::byte, 10_kB> buffer{};
  };
private:
  virtual void driver_update(const big_struct& p_buffer) = 0;
};
```

**Why?**

This can make interfaces and APIs hard to use in resource constrained systems.
In the example above, in order to call the `driver_update` function, you need
to pass it a buffer that takes up 10kB of ram. If this is allocated on the
stack, it could easily overrun a thread's stack. If a device doesn't even have
10kB of ram then this API can never be called on the system. An example of this
would be a display driver where an entire frame buffer is required in order to
update the display.

**Consider:**

Consider if the input value needs to be so large? Can it be broken up into
pieces? Can it implemented in another way that doesn't require a large amount
of memory?

## Should contain no member

Interfaces should only have public member functions and private virtual member
functions. Nothing more.

**Why?**

The primary purpose of an interface is to define an abstract layer of
communication between different parts of a program. Interfaces should ideally
be agnostic of how their contracts are fulfilled. Including member fields
implies a certain level of implementation detail that detracts from the
abstraction.

Adding fields to an interface can lead to tighter coupling between the
interface and its implementations. This can complicate the design and increase
the difficulty of changes in the future. Implementations are forced to manage
state in a specific way, which can reduce flexibility in how they manage their
internal states and behaviors.

**Consider:**

That you do not actually need to add a data member to the interface.

## Must not be a template

A templated interface is a class template that is also an interface like so:

```C++
template<class PacketSize>
class my_interface {
private:
  virtual void write(std::span<const PacketSize> p_payload) = 0;
};
```

**Why?**

The above example may seem like a great way to broaden an interface to an
unlimited scale, but that is actually a problem. (insert reasons here).

Template interfaces widen the scope and number of interfaces available in
libhal in an unbounded way. This can result in additional v-tables for each
interface implementation.

Interface instances with different template types will not compatible with each
other. Meaning an adaptor of sources would be needed to convert one to another.

**Consider:**

That this is not necessary. Consider that there exists a generic and specific
implementation of an interface. Consider making two interfaces if a single
interface would not suffice.

## Prefer wide API contracts

A wide contract for an API means that an API can take any type of input for all
of the input parameters sent to the API. Meaning that the API is well defined
for all possible inputs that could be passed. That does not mean that the
implementation of an API will accept all possible inputs. The API could throw
an error if the input is beyond what it is capable of working with. But simply
means that the API is well defined for the whole range of the inputs.

**Why?**

It helps eliminate viral behavior and tends to eliminate undefined behavior.

**Consider:**

The cost of an API having a wide contract? Would this result in viral behavior
or eliminate it? Would it result in worse performance? Would it result in
increased ram or increased rom utilization? Would it potentially save in all of
these. If possible try and guarantee a wide contract if possible and only
consider a narrow contract as a last resort. Explain in detail why a narrow
contract was chosen, as those are vectors for bugs and undefined behavior.

## Do NOT break ABI

ABI stands for Application Binary Interface. A breakage to an ABI is not easy
for C++ or other languages to determine. A ABI break can come in many forms
but it usually comes as a change between a version of code compiled previously
and a version of code compiled now. Such a break can result in memory
corruption, invalid input to a function and overall undefined behavior.

**Why?**

Don't do it! Its bad. But in all honesty, all hell breaks loose if we allow ABI
breaks. If we MUST break ABI we MUST update the major version number of the
library.

**Consider:**

With regards to interfaces, given the other rules, there is really only the
following possible ABI breaking changes that can occur:

1. Changing the return value of a virtual function
2. Changing function calling convention.
3. Reordering of virtual API within an interface.
4. Reordering of members within a returned `struct` or `class`.

These are not allowed due to how they affect how programs generate assembly for
each function call. What we are allowed to do is the following:

1. Add additional non-virtual public functions.
2. Add additional overloads for public functions (we should `[[deprecate]]` old
   APIs we know to be harmful).
3. Add additional non-pure virtual APIs below the current set of virtual APIs
   (should avoid this).
4. Add additional fields to a settings `struct` that is passed by reference.
