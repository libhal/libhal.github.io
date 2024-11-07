# Stream ADC: Multi Sample Analog to Digital Converter

!!! warning
    This document describes the ADC for libhal 5.0.0 which is not out yet.

!!! warning
    This document is not complete yet.

Welcome to the libhal stream adc tutorial. Stream ADCs are like normal ADCs but allow you to supply them with a buffer that they will capture data into. If you don't know what an ADC is, see the [adc tutorial](adc.md).

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

- `hal::stream_adc8`: for ADCs with 8 bits or below
- `hal::stream_adc16`: for ADCs with 9 to 16 bits
- `hal::stream_adc24`: for ADCs with 17 to 24 bits
- `hal::stream_adc32`: for ADCs with 25 to 32 bits

Different applications require different resolutions of analog measurement.

- `hal::stream_adc8` for when resolution is not very important and can be low
- `hal::stream_adc16` will be the most common ADC version and will suite most general
  use cases
- `hal::stream_adc24` is for applications that need high precision
- `hal::stream_adc32` is for applications that need extremely high precision

The ADC interfaces have a singular API which is `read()`.
