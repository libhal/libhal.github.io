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

## Implementing an ADC device driver

## Implementing an ADC peripheral driver

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
