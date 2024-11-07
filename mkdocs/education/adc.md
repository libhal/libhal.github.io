# ADC: Analog to Digital Converter

!!! warning
    This document describes the ADC for libhal 5.0.0 which is not out yet.

Welcome to the libhal adc tutorial. ADCs are used to sample analog voltage
signals and convert them into a number that can be used by controllers to sense
the world .

## Learning about ADCs

This article will not explain how ADCs work as there are many lovely tutorials out there on line already. We but will provide a list of resources to learn
about ADCs:

- [Sparkfun Tutorial](https://learn.sparkfun.com/tutorials/analog-to-digital-conversion/all):
  (RECOMMENDED) Quick and easy to understand.
- [element14 ADC tutorial video](https://www.youtube.com/watch?v=g4BvbAKNQ90):
  A great 10min long video that goes into the many different ADC
  implementations and how they convert voltages into decimal numbers.

## ADC interfaces and how to use them

libhal has 4 ADC interfaces. Each is suffixed with the bit resolution of the
ADC.

- `hal::adc8`: for ADCs with 8 bits or below
- `hal::adc16`: for ADCs with 9 to 16 bits
- `hal::adc24`: for ADCs with 17 to 24 bits
- `hal::adc32`: for ADCs with 25 to 32 bits

Different applications require different resolutions of analog measurement.

- `hal::adc8` for when resolution is not very important and can be low
- `hal::adc16` will be the most common ADC version and will suite most general
  use cases
- `hal::adc24` is for applications that need high precision
- `hal::adc32` is for applications that need extremely high precision

The ADC interfaces have a singular API which is `read()`.

```C++
// Returns value from 0 to 255
hal::u8 hal::adc8::read();
// Returns value from 0 to 65,535
hal::u16 hal::adc16::read();
// Returns value from 0 to 16,777,215
hal::u32 hal::adc24::read();
// Returns value from 0 to 4,294,967,295
hal::u32 hal::adc32::read();
```

The `read()` API returns a value between `0` and the maximum value
representable for that bit-width. Drivers that are not exactly the bit-width of
the adc they represent must upscale their ADC values to match the ADC they are
implementing. For example a 9-bit ADC would need to perform an upscale to
16-bits.

### How ADC upscaling works

libhal provides an integer upscaling facility in:

```C++
template<std::size_t incoming_bit_width, std::size_t upscaled_bit_width>
constexpr container_int_t<upscaled_bit_width> upscale(
    std::unsigned_integral auto p_value);
```

This may look pretty complicated but lets see it in use:

```C++
hal::u16 my_adc::read() {
  hal::u16 adc_value = /* ... acquire 9-bit sample ... */;
  // scale 9-bit sample to 16-bits
  return hal::upscale<9, 16>(adc_value);
}
```

The key to proportional upscaling is replicating the original bits into the
larger bit depth through shifting and bitwise OR operations. Consider upscaling
an 8-bit value to 16 bits:

```plaintext
8-bit value:          10110101 (decimal 181)
Naive padding:        10110101 00000000 (decimal 46,336)
Bit duplication:      10110101 10110101 (decimal 46,421)
```

Zero-padding (left shifting) multiplies the value by 256, which distorts the
proportional relationship. More importantly, zero-padding can never reach the
maximum 16-bit value (65,535) as the lower bits are always 0. Similarly,
padding with 1s means you can never reach 0 in the larger bit depth.

To demonstrate this distortion, let's look at the middle value of a `uint8_t`
(127):

```plaintext
8-bit middle:         01111111 (decimal 127, 49.803% of 256)
Naive padding:        01111111 00000000 (decimal 32,512)
Bit duplication:      01111111 01111111 (decimal 32,767)
```

With naive zero-padding, 32,512 is only 49.61% of the 16-bit maximum (65,535),
creating a proportional error of 0.193%. In contrast, bit duplication yields
32,767, which is exactly 50% of 65,535, maintaining the correct proportional
relationship from the original 8-bit value.

Bit duplication ensures that all values maintain their relative positions when
scaled up - when the input is 0, the output is 0, and when the input is max
(255), the output is max (65,535). This makes it ideal for ADC upscaling where
maintaining proportional relationships across the entire range is crucial.

### Using upscaled ADC values for math

Typically, ADC values are used to scale other values. Lets take a very
rudimentary example of a potentiometer with 350 degrees of movement.

```C++
hal::u16 adc_to_degrees(hal::adc16& p_adc) {
  constexpr hal::u16 max_degrees = 350;
  constexpr auto u16_max = std::numeric_limits<hal::u16>::max();

  auto const u16_sample = p_adc.read();
  // Multiplication between two u16s requires u32 to contain it
  hal::u32 const overscaled_value =  max_degrees * u16_sample;
  // Divide resolve by the maximum value of a u16 to scale it back to degrees
  // Because we are dividing by the max of u16, the resulting value will be u16
  // in size.
  auto const degrees = static_cast<hal::u16>(overscaled_value / u16_max);

  return degrees;
}
```

Scaling using a proportional integer value works like so:

```plaintext
           /  adc_value * 350  \
degrees = | ------------------- |
           \       65535       /
```

Lets put in a value that is in the middle of the ADC value. We should get a
degrees value also in the middle of the 350 degrees which is 175.

```plaintext
           /    32767 * 350    \
degrees = | ------------------- | =  175 (middle of the potentiometer)
           \       65535       /
```

### Performance of scaled values

By using scaled values, the application writer can decide how they want to
perform mathematics on the adc samples based on their maximum value. For
example, if the application requires a `adc24` and the result is multiplied by
an `8-bit` number, the result can still be contained in a `u32` without needing
to use a `u64` bit value. Note that u64 math on 32-bit systems must me emulated
in software which results in a performance drop.

## ADC Utilities

### ADC scaler APIs

To make this scaling easier we provide two APIs

```C++
constexpr hal::u16 hal::scale_value(hal::u16 p_max_value,
                                    hal::adc16& p_adc);
template<std::integral int_t>
constexpr hal::u16 hal::scale_value(hal::range<int_t> p_value_range,
                                    hal::adc16& p_adc);
```

Using these APIs we get:

```C++
hal::u16 adc_to_degrees(hal::adc16& p_adc) {
  constexpr hal::u16 max_degrees = 350;
  return scale_value(max_degrees, p_adc);
}

hal::u16 adc_to_degrees(hal::adc16& p_adc) {
  // In this case we have a minimum that is not
  constexpr hal::u16 min_degrees = 20;
  constexpr hal::u16 max_degrees = 350;
  return scale_value({ .min = min_degrees, .max = max_degrees}, p_adc);
}
```

### Adaptor classes

Let say you have a 16-bit ADC and want to use it in place of a 8-bit adc. This
can happen when a driver that requires an ADC requires a different ADC then what you currently have. Reducing the resolution is as easy as shifting the
data to the right to reach the desired bit-width.

```C++
template<hal::adc_t destination_adc, hal::adc_t source_adc>
class adc_adaptor {
public:
  adc_adaptor(source_adc& p_source);
  adc_adaptor(source_adc&& p_source);
};
```

Usage:

```C++
hal::adc24& high_precision_adc = /* ... */;
hal::adc_adaptor<hal::adc16> adc_16_bit(high_precision_adc);
hal::u16 reading = adc_16_bit.read();
```

The adaptor can also scale up bit data but usage in that direction is dubious if an driver requires a specific resolution.

```C++
hal::adc8& low_precision_adc = /* ... */;
hal::adc_adaptor<hal::adc16> adc_16_bit(low_precision_adc);
hal::u16 reading = adc_16_bit.read();
```

## Building Drivers that take `hal::adcN`

`hal::adcN` can be shared but in general it is recommended to pass a single adc
to a single driver to use. Driver implementors should assume that they are the
only users of the `hal::adcN`. Driver implementors should assume that the passed in adc will outlive the lifetime of the driver.

Drivers that require an ADC to function should look similar to the following:

```C++
class my_driver {
public:
  my_driver(hal::adc16& p_adc): m_adc(&p_adc) {
    // Do what is needed for the driver
  }

private:
  hal::adc16* m_adc = nullptr;
}
```

- For your application, decide what bit-resolution your driver requires. When
  in doubt, choose `hal::adc16` as it is the most common ADC type.
- Accept your ADC type by reference and store the ADC's address within a
  pointer. See style guide "S.15.2 Storing references" for more details.

And thats about it. You can use the adc as much as you like in your APIs. The
only concern is ensuring that you do not get integer overflows when performing
math on the ADC values.

## Implementing the ADC interface

!!! warning
    This section is incomplete!

ADCs can appear in different locations such as:

- Embedded into the silicon of a microcontroller
- Discrete devices that a controller to speak to over protocols like i2c and
  spi.

ADCs typically come with multiple channels. Each ADC object should manage and
control a singular ADC channel. Initializing an ADC object may require that it
setup the whole.

## Why this design choice?

This section goes over the API design choice for the `hal::adcN` APIs. Starting
with the original design:

### Why not provide a single interface w/ a bit-width API?

A very common approach for an ADC abstraction would be something like this:

```C++
struct adc {
  hal::u8 bit_width();
  hal::u32 read();
};
```

Where an API is provided for both the bit-width and ADC value. To compute actual
scaled value, the caller will need to call the `bit_width` API before it can
use the information from `read()`. Calculating the maximum value for a bit width
can be done with the following expression: `(1 << bit_width) - 1`. This
approach would allow interfaces to be used for everything ADC related.

There are a couple of reasons why I do not like this approach:

#### Problem #1: 2 virtual calls needed to realize the value

If a function or method has never once called any APIs on an ADC, it must first
call `bit_width` then call `read` to understand the value of `read`. Luckily
the `bit_width` is a value that should be known at compile time and is
intrinsic to the ADC's hardware, so returning the value is very simple and
straight forward. But for each scope where the `bit_width` information is lost,
the `bit_width` API must be called.

The second virtual API call requires additional cycles, although not that many,
but if we can avoid extra API calls and get all of the information in a single
call, then I think that is the better technical design decision.

#### Problem #2: Caching bit-width in drivers

For drivers, calling `bit_width` each time you need to scale a value based on
`read` would be a waste of cycles. It would be faster to call `bit_width` once
at driver construction and cache the full-scale value into a `hal::u32`. Then
reuse that value through out the code.

This would mean that drivers using an ADC interface will preferable cache
an extra 32-bit word to save on a virtual call. Thus, this API design results
in additional memory usage in order to improve on performance.

#### Problem #3: Computational complexity

Because the width isn't known until runtime, code using any such ADC will have
to prepared for ADCs with large bit widths such as 24-bit ADCs. Code will need
to perform a check against the bit-width and determine what resolution is
needed for the code. It would look something like this:

```C++
hal::u32 scale_to_degrees(hal::adc_split& impl)
{
  constexpr hal::u16 max_degrees = 360;
  auto bit_width = impl.bit_width();
  auto response = impl.read();

  if (bit_width > 16) {
    auto const shift_amount = bit_width - 16;
    response >>= shift_amount;
    bit_width = 16;
  }

  auto const max_scale = (1 << bit_width) - 1;
  auto const up_scaled = response * max_degrees;
  auto const final_value = up_scaled / max_scale;
  return final_value;
}
```

In this case, our math can only work with 16-bit resolution values, so a check
against the bit_width is required. If that branch is taken additional
operations are needed to scale the value down to a bit-width that the code can
work with. Or to eliminate the branch, the code could use `hal::u64`, but then
the performance on 32-bit systems tanks.

#### Problem #4: Why not return both?

You could return a struct with both of the information. But now each call has
the additional cost of returning a bit-width each time it is called even if it
won't be used.

#### Conclusion about bit-width APIs

The choice to include a bit-width API takes information that is known at
compile time and is intrinsic to the device and makes it only accessible via
runtime. To accommodate this, code developers must:

1. Make additional calls
2. Cache information
3. Computer the full-scale value
4. Perform additional logic to ensure math safety

These can all be eliminated by categorizing each adc bit-width bucket into the
4 interfaces mentioned and merging the bit-width info into the returned value
via upscaling. Lets consider `hal::adc16`:

1. Only requires a single call
2. No need to cache information, simply use the sample that was returned
3. Full scale is known at compile time as the max value of a `u16` (65535)
4. No additional logic is required because bit-width is intrinsic to the
   interface

Using upscaled values eliminates operations that would otherwise be reproduced
throughout a code base and across drivers. Scaling within each of the `adcN`
interface buckets ensures that only a single left shift and OR operation is
required to upscale the data.

### Benchmarks against other options

```C++
#include <cinttypes>
#include <climits>
#include <concepts>
#include <cstdint>
#include <cstdio>
#include <limits>

#include <libhal-exceptions/control.hpp>
#include <libhal-util/serial.hpp>
#include <libhal-util/steady_clock.hpp>
#include <libhal/error.hpp>

#include <resource_list.hpp>

// This is only global so that the terminate handler can use the resources
// provided.
resource_list resources{};

[[noreturn]] void terminate_handler() noexcept
{
  bool valid = resources.status_led && resources.clock;

  if (not valid) {
    // spin here until debugger is connected
    while (true) {
      continue;
    }
  }

  // Otherwise, blink the led in a pattern, and wait for the debugger.
  // In GDB, use the `where` command to see if you have the `terminate_handler`
  // in your stack trace.

  auto& led = *resources.status_led.value();
  auto& clock = *resources.clock.value();

  while (true) {
    using namespace std::chrono_literals;
    led.level(false);
    hal::delay(clock, 100ms);
    led.level(true);
    hal::delay(clock, 100ms);
    led.level(false);
    hal::delay(clock, 100ms);
    led.level(true);
    hal::delay(clock, 1000ms);
  }
}

void application();

int main()
{
  // Setup the terminate handler before we call anything that can throw
  hal::set_terminate(terminate_handler);

  // Initialize the platform and set as many resources as available for this the
  // supported platforms.
  initialize_platform(resources);

  try {
    application();
  } catch (std::bad_optional_access const& e) {
    if (resources.console) {
      hal::print(*resources.console.value(),
                 "A resource required by the application was not available!\n"
                 "Calling terminate!\n");
    }
  }  // Allow any other exceptions to terminate the application

  // Terminate if the code reaches this point.
  std::terminate();
}

namespace hal {

using integral_type = std::uint16_t;
constexpr auto integral_type_bit_width = sizeof(integral_type) * CHAR_BIT;

struct adc_scaled
{
  virtual integral_type read() = 0;
};

struct adc_float
{
  virtual float read() = 0;
};

struct adc_piecewise
{
  struct read_t
  {
    integral_type value;
    std::uint8_t bit_width;
  };
  virtual read_t read() = 0;
};

struct adc_piecewise_max
{
  struct read_t
  {
    integral_type value;
    integral_type full_scale;
  };
  virtual read_t read() = 0;
};

struct adc_split
{
  virtual std::uint8_t bit_width() = 0;
  virtual integral_type read() = 0;
};

constexpr std::uint8_t test_bit_width = 7;
std::uint16_t adc_data = 31;

template<std::unsigned_integral int_t, std::size_t bit_width>
constexpr int_t upscale(int_t p_value)
{
  constexpr std::size_t resultant_bit_width = sizeof(int_t) * CHAR_BIT;
  static_assert(bit_width > 0 && bit_width <= resultant_bit_width,
                "Bit width must be between 1 and 32");
  // If already 32 bits, return as-is
  if constexpr (bit_width == resultant_bit_width) {
    return p_value;
  }

  // Create mask for the input bits
  constexpr int_t mask = (1u << bit_width) - 1;

  // Calculate number of iterations needed (ceiling(32/bit_width) - 1)
  constexpr auto iterations =
    (resultant_bit_width + bit_width - 1) / bit_width - 1;

  // Place cleaned input value in MSB position
  constexpr auto shift_distance = resultant_bit_width - bit_width;
  int_t result = (p_value & mask) << shift_distance;

  // Replicate the pattern for the calculated number of iterations
  for (auto i = 0U; i < iterations; ++i) {
    result |= (result >> bit_width);
  }
  return result;
}

struct adc_scaled_impl : public adc_scaled
{
  integral_type read() override
  {
    return upscale<integral_type, test_bit_width>(adc_data);
  }
};

struct adc_piecewise_impl : public adc_piecewise
{
  read_t read() override
  {
    return { adc_data, test_bit_width };
  }
};

struct adc_split_impl : public adc_split
{
  std::uint8_t bit_width() override
  {
    return test_bit_width;
  }

  integral_type read() override
  {
    return adc_data;
  }
};

struct adc_float_impl : public hal::adc_float
{
  float read() override
  {
    constexpr auto max = (1 << test_bit_width) - 1;
    return float(adc_data) / max;
  }
};

struct adc_piecewise_max_impl : public adc_piecewise_max
{
  read_t read() override
  {
    constexpr auto max = (1 << test_bit_width) - 1;
    return { adc_data, max };
  }
};
}  // namespace hal

constexpr std::uint16_t max_degrees = 360;
constexpr std::uint16_t u16_max = std::numeric_limits<std::uint16_t>::max();
constexpr auto shift_amount = hal::integral_type_bit_width - 16;

[[gnu::noinline]]
std::uint32_t scale_to_degrees(hal::adc_scaled& impl)
{
  auto const response = impl.read();
  auto const response_u16 =
    static_cast<std::uint16_t>(response >> shift_amount);
  auto const up_scaled = response_u16 * max_degrees;
  auto const final_value = up_scaled / u16_max;
  return final_value;
}

[[gnu::noinline]]
std::uint32_t scale_to_degrees(hal::adc_piecewise& impl)
{
  auto const [response, bit_width] = impl.read();
  auto const max_scale = (1 << bit_width) - 1;
  auto const up_scaled = response * max_degrees;
  auto const final_value = up_scaled / max_scale;
  return final_value;
}

[[gnu::noinline]]
std::uint32_t scale_to_degrees(hal::adc_split& impl)
{
  auto const bit_width = impl.bit_width();
  auto const response = impl.read();
  auto const max_scale = (1 << bit_width) - 1;
  auto const up_scaled = response * max_degrees;
  auto const final_value = up_scaled / max_scale;
  return final_value;
}

[[gnu::noinline]]
std::uint32_t scale_to_degrees(hal::adc_piecewise_max& impl)
{
  auto const [response, max_scale] = impl.read();
  auto const up_scaled = response * max_degrees;
  auto const final_value = up_scaled / max_scale;
  return final_value;
}

[[gnu::noinline]]
std::uint32_t scale_to_degrees(hal::adc_float& impl)
{
  auto const response = impl.read();
  auto const final_value = response * max_degrees;
  return final_value;
}

[[gnu::noinline]]
std::uint32_t scale_to_degrees2(hal::adc_split& impl)
{
  auto bit_width = impl.bit_width();
  auto response = impl.read();

  if (bit_width > 16) {
    auto const shift_amount = bit_width - 16;
    response >>= shift_amount;
    bit_width = 16;
  }

  auto const max_scale = (1 << bit_width) - 1;
  auto const up_scaled = response * max_degrees;
  auto const final_value = up_scaled / max_scale;
  return final_value;
}

template<typename T>
void use(T&& t)
{
  __asm__ __volatile__("" ::"g"(t));
}

void application()
{
  using namespace std::chrono_literals;
  constexpr auto sample_count = 2'000'000;

  // Calling `value()` on the optional resources will perform a check and if the
  // resource is not set, it will throw a std::bad_optional_access exception.
  // If it is set, dereference it and store the address in the references below.
  // When std::optional<T&> is in the standard, we will change to use that.
  auto& led = *resources.status_led.value();
  auto& clock = *resources.clock.value();
  auto& console = *resources.console.value();

  hal::print(console, "Starting ADC benchmark!\n");

  hal::adc_piecewise_impl piecewise;
  auto const start_piecewise = clock.uptime();
  for (int i = 0; i < sample_count; i++) {
    auto const value = scale_to_degrees(piecewise);
    use(value);
  }
  auto const volatile end_piecewise = clock.uptime();
  auto const volatile delta_piecewise = end_piecewise - start_piecewise;

  auto const volatile start_split = clock.uptime();
  hal::adc_split_impl split;
  for (int i = 0; i < sample_count; i++) {
    auto const value = scale_to_degrees(split);
    use(value);
  }
  auto const volatile end_split = clock.uptime();
  auto const volatile delta_split = end_split - start_split;

  auto const start_scaled = clock.uptime();
  hal::adc_scaled_impl scaled;
  for (int i = 0; i < sample_count; i++) {
    auto const value = scale_to_degrees(scaled);
    use(value);
  }
  auto const volatile end_scaled = clock.uptime();
  auto const volatile delta_scaled = end_scaled - start_scaled;

  auto const start_max = clock.uptime();
  hal::adc_piecewise_max_impl max;
  for (int i = 0; i < sample_count; i++) {
    auto const value = scale_to_degrees(max);
    use(value);
  }
  auto const volatile end_max = clock.uptime();
  auto const volatile delta_max = end_max - start_max;

  auto const volatile start_float = clock.uptime();
  hal::adc_float_impl float_adc;
  for (int i = 0; i < sample_count; i++) {
    auto const value = scale_to_degrees(float_adc);
    use(value);
  }
  auto const volatile end_float = clock.uptime();
  auto const volatile delta_float = end_float - start_float;

  hal::print<64>(console, "   start_scaled = %" PRIu64 "\n", start_scaled);
  hal::print<64>(console, "     end_scaled = %" PRIu64 "\n", end_scaled);
  hal::print<64>(console, "start_piecewise = %" PRIu64 "\n", start_piecewise);
  hal::print<64>(console, "  end_piecewise = %" PRIu64 "\n", end_piecewise);
  hal::print<64>(console, "    start_split = %" PRIu64 "\n", start_split);
  hal::print<64>(console, "      end_split = %" PRIu64 "\n", end_split);
  hal::print<64>(console, "      start_max = %" PRIu64 "\n", start_max);
  hal::print<64>(console, "        end_max = %" PRIu64 "\n", end_max);
  hal::print<64>(console, "    start_float = %" PRIu64 "\n", start_float);
  hal::print<64>(console, "      end_float = %" PRIu64 "\n", end_float);
  hal::print(console, "\n");
  hal::print<64>(console, "delta_piecewise = %" PRIu64 "\n", delta_piecewise);
  hal::print<64>(console, "   delta_scaled = %" PRIu64 "\n", delta_scaled);
  hal::print<64>(console, "    delta_split = %" PRIu64 "\n", delta_split);
  hal::print<64>(console, "      delta_max = %" PRIu64 "\n", delta_max);
  hal::print<64>(console, "    delta_float = %" PRIu64 "\n", delta_float);

  hal::print(console, "Resetting in 10s!\n");
  hal::delay(clock, 10s);

  resources.reset();
}
```

All tests executed on an stm32f103c8 which featues a Cortex-M3 processor which
does not include a floating point unit. Using GCC 12.3.1.

Built using the following commands:

```bash
# Defaults to min size build
conan build . -pr stm32f103c8 -pr arm-gcc-12.3
# For release
conan build . -pr stm32f103c8 -pr arm-gcc-12.3 -s build_type=Release
```

```bash
nm --demangle --size-sort build/stm32f103c8/MinSizeRel/app.elf | grep "::read"
0000000c W hal::adc_split_impl::read()
00000014 W hal::adc_piecewise_max_impl::read()
00000018 W hal::adc_scaled_impl::read()
0000001c W hal::adc_float_impl::read()
00000024 W hal::adc_piecewise_impl::read()

nm --demangle --size-sort build/stm32f103c8/MinSizeRel/app.elf | grep "::bit_width"
00000004 W hal::adc_split_impl::bit_width()
```

Above we see that the scaled is in the middle in terms of code size. But
we will go over why this isn't an issue in the next block.

```bash
nm --demangle --size-sort build/stm32f103c8/MinSizeRel/app.elf | grep scale_to_degrees
00000018 T scale_to_degrees(hal::adc_scaled&)
0000001a T scale_to_degrees(hal::adc_float&)
0000001c T scale_to_degrees(hal::adc_piecewise_max&)
00000024 T scale_to_degrees(hal::adc_piecewise&)
00000026 T scale_to_degrees(hal::adc_split&)
00000036 T scale_to_degrees2(hal::adc_split&)
```

In a minimum sized build, using `adc_scaled` results in the smallest code size for the same results. In this case, the `adc_scaled::read` API takes up
more memory than the cost of its usage. We believe that it makes sense to optimize for the usages as those are more likely to be more numerous than ADC implementations.

```bash
 nm --demangle --size-sort build/stm32f103c8/Release/app.elf | grep "::read"
0000000c W hal::adc_split_impl::read()
00000014 W hal::adc_piecewise_max_impl::read()
00000018 W hal::adc_scaled_impl::read()
0000001c W hal::adc_float_impl::read()
00000024 W hal::adc_piecewise_impl::read()

nm --demangle --size-sort build/stm32f103c8/Release/app.elf | grep scale_to_degrees
00000024 t scale_to_degrees(hal::adc_piecewise&) (.constprop.0)
00000024 t scale_to_degrees(hal::adc_piecewise_max&) (.constprop.0)
00000024 t scale_to_degrees(hal::adc_split&) (.constprop.0)
00000028 t scale_to_degrees(hal::adc_float&) (.constprop.0)
0000002c t scale_to_degrees(hal::adc_scaled&) (.constprop.0)

00000040 T scale_to_degrees(hal::adc_scaled&)
00000044 T scale_to_degrees(hal::adc_piecewise_max&)
00000044 T scale_to_degrees(hal::adc_float&)
0000004c T scale_to_degrees(hal::adc_piecewise&)
0000005c T scale_to_degrees(hal::adc_split&)
00000088 T scale_to_degrees2(hal::adc_split&)
```

In the above Release build, the results are similar. `(.constprop.0)` in GCC
means that the symbol is a duplicate of another function but optimized to
perform around the same. In the optimized code scaled fairs the worst by an
additional 8 bytes compared to the lowest code size functions. But on the other
hand, for the original symbol, the scaled ADC code is the smallest in terms of
code size.

```plaintext
# Release Build Cycles

delta_piecewise = 12000075
   delta_scaled = 12000084
    delta_split = 12000084
      delta_max = 12000081
    delta_float = 12000443

# Min Size Build Cycles
delta_piecewise = 156000044
   delta_scaled = 134000059
    delta_split = 176000052
      delta_max = 136000052
    delta_float = 844000052
```

As you can see the cycles for almost all of these benchmarks are almost
identical. So much so that there isn't really a clear winner. Some seem to
perform worse off in specific builds. But overall they are about the same. And
if all else is the same in performance, then code size should be the deciding
factor.
