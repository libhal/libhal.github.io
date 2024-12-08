# SPI: Serial Peripheral Interface

!!! warning
    This document describes the CAN for libhal 5.0.0 which is not available yet.

Welcome to the libhal Serial Peripheral Interface (SPI) tutorial. SPI is a
commonly used medium speed communication protocol used for things such as SD
cards, sensors, and displays.

## Learning about SPI

Here are some resources for learning SPI:

- [🎥 Understanding SPI by Rohde Schwarz](https://www.youtube.com/watch?v=0nVNwozXsIc):
    - **Runtime:** 12min
    - **Description:** This video goes over much of theory and use cases for SPI. After watching this you should have all of the knowledge necessary to continue this tutorial.

## SPI interfaces and how to use them

In libhal there is a single interface for SPI: `hal::spi_channel`. It provides
a means to communicate over the SPI bus and control the chip select for a
device.

### Public APIs

```C++
class spi_channel {
  struct settings
  {
    enum class mode : u8
    {
      m0, // SPI mode 0
      m1, // SPI mode 1
      m2, // SPI mode 2
      m3, // SPI mode 3
    };
    u32 clock_rate = 100_kHz;
    mode select = mode::m0;
  };

  void configure(settings const& p_settings);
  u32 clock_rate();

  void transfer(std::span<hal::byte const> p_data_out,
                std::span<hal::byte> p_data_in = {},
                hal::byte p_filler = default_filler);

  void chip_select(bool p_select);
  void lock() { chip_select(true); }
  void unlock() { chip_select(false); }
};
```

!!! note
    "channel" terminology for a spi driver may be a bit foreign to typical
    users of SPI. Why a "channel"? Channel implies a dedicated communication
    path. It can also imply that there is some sharing between other such
    channels utilizing the same bus resource but in a controlled way.

Use the comments labeled below to explain how you'd use `hal::spi_channel`:

```C++
void spi_channel_usage(hal::spi_channel& spi) {
  // Set the settings for this channel. Note that this does not apply the
  // settings to the SPI bus immediately. Instead it caches the configuration
  // settings and applies them to the SPI bus after bus acquisition via the
  // `chip_select()` or `transfer()` APIs.
  spi.configure({
    .clock_rate = 250_kHz,
    .mode = hal::spi_channel::mode::m0, // select SPI MODE 0
  });

  // Acquires exclusive control over the spi bus and applies configuration
  // settings to the bus. If the bus is currently busy, this call will block
  // until control over the bus is available.
  spi.chip_select(true);
  // After this point, the settings passed into configure will be applied to
  // the SPI bus.

  // Write `device_config_payload` to the device selected on the bus
  constexpr std::array<hal::byte, 2> device_config_payload = { 0x02, 0x4A };
  spi.transfer(device_config_payload);

  // Read 2 bytes from the bus into the response buffer.
  std::array<hal::byte, 2> response = {};
  spi.transfer({}, response);

  // Releases control over the spi bus
  spi.chip_select(false);

  // Now use the data in `response`.
}
```

The above works but in general, direct control over the chip select should be
avoided and `std::lock_guard` should be used instead.

```C++
float read_sensor_data(hal::spi_channel& p_spi)
{
  // Prefer to use `std::lock_guard` as an automatic way to acquire and release
  // the spi bus at the end of the scope. Also ensures the bus is released in
  // the event of an exception.
  std::lock_guard access_bus(p_spi);

  // Perform a write transfer then a read
  constexpr std::array<hal::byte, 1> sensor_register = { 0x03 };
  p_spi.transfer(sensor_register);

  std::array<hal::byte, 2> sensor_data{};
  // Passing an empty span for the `p_data_out` will cause the SPI bus to
  // transfer the default filler byte 0xFF. Data will be read from the bus into
  // the `sensor_data` array.
  p_spi.transfer({}, sensor_data);

  // Use the data to compute the sensor reading. Note this is all made up for
  // demonstration purposes.
  return (sensor_data[1] << 8 | sensor_data[0]) / 12.0f;
} // After the return, access_bus is destroyed and the bus is released!
```

### Clock Rate Settings

Setting the clock rate for SPI is a "best effort" approach following this expression:

```C++
spi.clock_rate() <= settings.clock_rate; // this always evaluates to TRUE.
```

The actual clock rate of the SPI bus will be equal to or less than the
`settings.clock_rate` passed to the `configure` API. We make these assumptions
about how SPI will be used:

- Devices that communicate over SPI have a maximum clock rate they can tolerate.
- Devices that communicate over SPI can talk at frequencies below their maximum
  without issue.
- Any call to `configure` could be a request to set the clock rate to the
  maximum a device can support.

With these assumptions, a reasonable approach to clock rate setup would be to allow the bus frequency to be equal to or below the selected clock rate. If you have an application where the clock rate has to meet a very tight tolerance, you can use the `clock_rate()` function to return the integer value of the frequency in hertz.

We choose this over throwing an exception if they do not match, because we believe that most users will be okay with "fastest possible" vs "exactly the number I specified". And if they really need the second one, they can check themselves.

## SPI Device Manager

In order to acquire spi_channels you will need an spi device manager. SPI
channels are acquired from a platform's SPI manager object like so:

```C++
#include <libhal-arm-mcu/stm32f1/output_pin.hpp>
#include <libhal-arm-mcu/stm32f1/spi.hpp>
#include <libhal-util/atomic_spin_lock.hpp>

void initialize_platform() {
  // do stuff ...

  static hal::atomic_spin_lock spi_bus_lock;
  static hal::stm32f1::output_pin cs1('A', 5);
  static hal::stm32f1::output_pin cs2('A', 6);

  // Select SPI bus 1, and pass it the
  static hal::stm32f1::spi spi_manager(hal::port<1>, spi_bus_lock);

  static auto spi_channel1 = spi_manager.acquire_channel(cs1);
  static auto spi_channel2 = spi_manager.acquire_channel(cs2);

  // do other stuff ...
}
```

The code provides a chip select output pin to the spi manager and it returns
a `hal::spi_channel` with access to the SPI bus. Each spi manager object
controls a single bus so creating a channel results in multiple objects that
have access to a single bus. Because of this, the spi channel objects must
ensure that only one chip select out of the set of spi channel's corresponding
to a single spi bus is active at a time AND that only one channel gets access
to the spi bus at a time.

## SPI Utility Libraries

`libhal-util` provides a couple of helpful APIs for using SPI.

Each of the APIs below automatically asserts the chip select so it is not
necessary to do so outside. If you need to perform multiple writes, read, or
write-then-read operations without asserting and de-asserting the chip select
each time, add the `hal::no_cs` token as the first parameter of the utility
APIs.

### `hal::write(hal::spi_channel& p_spi, ...)`

```C++
#include <mutex>

#include <libhal-util/spi.hpp>

void hal_write_spi_example(hal::spi_channel& p_spi) {
  constexpr std::array<hal::byte, 2> payload = {0x04, 0x22};
  // Performs chip select, writes `payload` on the spi bus, ignore bytes on the
  // receive line.
  hal::write(p_spi, payload);
}
```

Or you can use `std::to_array` to create a temporary array inline.

```C++
#include <mutex>

#include <libhal-util/spi.hpp>

void hal_write_spi_example(hal::spi_channel& p_spi) {
  // Performs chip select, writes array { 0x04, 0x22 } on the spi bus, ignore
  // bytes on the receive line.
  hal::write(p_spi, std::to_array<hal::byte>({0x04, 0x22}));
}
```

And here is how you use `hal::no_cs` with the `write` API.

```C++
#include <mutex>

#include <libhal-util/spi.hpp>

void hal_write_spi_example(hal::spi_channel& p_spi,
                           std::span<hal::byte const> p_ssid,
                           std::span<hal::byte const> p_password) {
  constexpr auto header = std::to_array<hal::byte>({0xAA, 0xBB, 0x00, 0x7F});
  constexpr auto spacer = std::to_array<hal::byte>({0x00});

  // Select the chip via std::lock_guard
  std::lock_guard select_device(p_spi);
  // Write the following sets of data without asserting and de-asserting for
  // reach write operation.
  hal::write(hal::no_cs, p_spi, header);
  hal::write(hal::no_cs, p_spi, p_ssid);
  hal::write(hal::no_cs, p_spi, spacer); // lets assume this is necessary
  hal::write(hal::no_cs, p_spi, p_password);
}
```

### `hal::read(hal::spi_channel& p_spi, ...)`

```C++
#include <mutex>

#include <libhal-util/spi.hpp>

void hal_read_spi_example(hal::spi_channel& p_spi) {
  std::array<hal::byte, 2> buffer{};

  // Perform an SPI read, ignore bytes on the receive line.
  hal::read(p_spi, buffer);

  // Buffer contains 2 bytes read from the SPI bus
}
```

If you you want to read a fixed number of bytes, you can set the template
parameter to an unsigned number and that amount of bytes will be read and
returned as an `std::array<hal::byte, N>`:

```C++
#include <mutex>

#include <libhal-util/spi.hpp>

void hal_read_spi_example(hal::spi_channel& p_spi) {
  // Perform an SPI read of 4 bytes and return the array
  auto const response = hal::read<4>(p_spi, buffer);

  // response contains 4 bytes read from the SPI bus
}
```

And here is how you use `hal::no_cs` with the `read` API.

```C++
#include <mutex>

#include <libhal-util/spi.hpp>

void hal_read_spi_example(hal::spi_channel& p_spi) {
  // Select the chip via std::lock_guard
  std::lock_guard select_device(p_spi);
  // Read 4 bytes without changing the chip select state.
  auto const response = hal::read<4>(hal::no_cs, p_spi);
  // Use `response` ...
}
```

### `hal::write_then_read(hal::spi_channel& p_spi, ...)`

```C++
#include <mutex>

#include <libhal-util/spi.hpp>

void hal_read_spi_example(hal::spi_channel& p_spi) {
  constexpr std::array<hal::byte, 1> payload = { 0x10 };
  std::array<hal::byte, 3> buffer{};

  // Perform an SPI write operation, ignoring the bytes received during the
  // write operation, then perform a read operation, filling the write bytes
  // with the filler bytes.
  hal::write_then_read(p_spi, payload, buffer);

  // Buffer contains 3 bytes of data read from the SPI bus
}
```

If you you want to read back a fixed number of bytes, you can set the template
parameter to an unsigned number and that amount of bytes will be read and
returned as an `std::array<hal::byte, N>`:

```C++
#include <mutex>

#include <libhal-util/spi.hpp>

void hal_write_then_read_spi_example(hal::spi_channel& p_spi) {
  // Select the chip via std::lock_guard
  std::lock_guard select_device(p_spi);

  constexpr std::array<hal::byte, 1> payload = { 0x10 };
  // Perform an SPI write operation, ignoring the bytes received during the
  // write operation, then perform a read operation, filling the write bytes
  // with the filler bytes.
  auto const response = hal::write_then_read<3>(p_spi, payload);

  // Response contains 3 bytes of data read from the SPI bus
}
```

And here is how you use `hal::no_cs` with the `hal::write_then_read` API.

```C++
#include <mutex>

#include <libhal-util/spi.hpp>

void hal_write_then_read_spi_example(hal::spi_channel& p_spi) {
  constexpr std::array<hal::byte, 1> data_reg = { 0x10 };
  // Select the chip via std::lock_guard
  std::lock_guard select_device(p_spi);
  // Write `data_reg` address then read 4 bytes without changing the chip
  // select state.
  auto const response = hal::write_then_read<3>(hal::no_cs, p_spi, data_reg);
}
```

## Usage in device drivers

A typical device driver class that requires an spi channel would look like this:

```C++
class pseudo_temperature_sensor : public hal::temperature_sensor {
public:
  /// Accept a `hal::spi_channel` by reference, and capture it's address
  pseudo_temperature_sensor(hal::spi_channel& p_spi): m_spi(&p_spi) {
    constexpr auto config_address = std::to_array({ 0x01 });

    // Set the bus settings
    m_spi->configure(settings);
    // Write configuration register address to bus and then read back an array
    // with length 1, and access byte [0].
    hal::u8 config = hal::write_then_read<1>(*m_spi, config_address)[0];
    // Set enable bit (5) in config register
    config |= 1 << 5;
    // Write back configuration with enable bit set to the configuration
    // register.
    hal::write(*m_spi, std::to_array({ config_address[0], config }));
  }

private:
  constexpr hal::spi_channel::settings settings = {
    .clock_rate = 10_MHz,
    .select = hal::spi_channel::mode::m0,
  };

  float driver_read() override {
    // Made up ration to convert binary i16 value to celsius
    constexpr float bin_to_celsius = 0.025f;
    // Made up address of the temperature data
    constexpr auto temperature_address = std::to_array({ 0x02 });
    // We write the address and read back 2 bytes of data
    auto const data = hal::write_then_read<2>(*m_spi, temperature_address);
    // Combine the data bytes into an i16 value.
    hal::i16 temperature = data[0] << 8 | data[1];
    // Calculate the temperature and return it.
    return temperature * bin_to_celsius;
  }

  // Store hal::spi_channel as a pointer (never a reference)
  hal::spi_channel* m_spi;
};
```

## Writing your own SPI driver

TBD
