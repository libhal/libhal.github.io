# CAN BUS: Controller Area Network Bus

!!! warning
    This document describes the CAN for libhal 5.0.0 which is not available yet.

Welcome to the libhal controller area network (CAN) tutorial. CAN BUS is used
as a reliable broadcast communication.

## Learning about CAN BUS

To learn more about CAN BUS we recommend these online resources:

- [🎥 CAN Bus: Serial Communication - How It Works?](https://www.youtube.com/watch?v=JZSCzRT9TTo)
  11m 24s video going over the basics of CAN BUS. It does not go over message
  ID arbitration which is quite important to understand with CAN BUS, but not necessary to use CAN APIs.
- [📄 Introduction to the Controller Area Network (CAN) by Texas Instruments](https://www.ti.com/lit/an/sloa101b/sloa101b.pdf):
  A fully featured document going over most of the important aspects of CAN
  bus. You'll learn everything you need to know about CAN with this document.

## CAN interfaces and how to use them

libhal breaks CAN up into multiple interfaces and abstractions.

- `hal::can_transceiver`: Provides APIs for sending can messages and receiving
  messages.
- `hal::can_message_interrupt`: Provides APIs for setting an interrupt when a
  message is received.
- `hal::can_bus_manager`: Provides APIs for managing the state of the can bus
  hardware.
- Standard can filters:
    - `hal::can_identifier_filter`: Provides a means to filter can bus messages
      via a message ID.
    - `hal::can_mask_filter`: Provides a means to filter can bus messages via an
      message ID and mask combo.
    - `hal::can_range_filter`: Provides a means to filter can bus messages via a
      range of can message IDs
- Extended can filters (same as standard but for extended message IDs):
    - `hal::can_extended_identifier_filter`
    - `hal::can_extended_mask_filter`
    - `hal::can_extended_range_filter`

The CAN peripheral functionality is broken up across multiple interfaces in
order to enable greater flexibility for applications, device drivers, and the
various capabilities of hardware. For example, the number of filters of each
type can vary wildly between different devices, but the predominately fit in
these three categories.

### The `hal::can_message`

The `hal::can_message` struct contains all of the information stored within a
typical message. The object `hal::can_message` represents a standard CAN
message in libhal. It provides all of the information you'd need in a typical
CAN message. It is used for sending and receiving messages on the can bus. Note
that the remote request and extended fields utilize bits 29th and 30th,
respectively, within the of the 32-bit `id_flags` field. The 31st bit is
reserved for now and must remain 0.

The can message and its APIs are defined below.

```C++
struct can_message
{
  /**
   * @brief Memory containing the ID and remote request and extended flags
   *
   * The 31st (final) bit in this mask is reserved and must always be set to 0.
   * Prefer to use the accessor APIs rather than modify this field directly.
   *
   */
  hal::u32 id_and_flags = 0;
  /**
   * @brief Reserve padding memory
   *
   * The size of the contents of the is struct are not a multiple of 4 meaning,
   * on 32-bit and above systems, this struct has a size of 16-bytes where 3 of
   * the bytes are padding bytes.
   *
   * These bytes are reserved and only zeros may be written to them.
   *
   */
  std::array<hal::byte, 3> reserved{};
  /**
   * @brief The number of valid elements in the payload
   *
   * Can be between 0 and 8. A length value above 8 should be considered
   * invalid and can be discarded.
   */
  uint8_t length = 0;
  /**
   * @brief Message data contents
   *
   */
  std::array<hal::byte, 8> payload{};

  /**
   * @brief Enables default comparison
   *
   */
  constexpr bool operator<=>(can_message const&) const = default;

  /**
   * @brief Set message ID
   *
   * @param p_id - 29 to 11 bit message ID
   * @return constexpr can_message& - reference to self for function chaining
   */
  constexpr can_message& id(hal::u32 p_id);
  /**
   * @brief Set the messages remote request flag
   *
   * @param p_is_remote_request - set to true to set message as a remote
   * request.
   * @return constexpr can_message& - reference to self for function chaining
   */
  constexpr can_message& remote_request(bool p_is_remote_request);
  /**
   * @brief Set the messages extended flag
   *
   * @param p_is_extended - set to true to set this message as an extended
   * message ID.
   * @return constexpr can_message& - reference to self for function chaining
   */
  constexpr can_message& extended(bool p_is_extended);
  constexpr hal::u32 id();
  constexpr bool remote_request();
  constexpr bool extended();
};
```

### Using `hal::can_transceiver`

For now, lets set aside how we acquire a `hal::can_transceiver` and consider
what you can do once you have one.

```C++
u32 baud_rate() = 0;
```

This function returns the baud rate in hertz of the CAN BUS. The baud rate
represents the communication rate. Common baud rates for CAN BUS are:

- 100 kHz or Kbit/s
- 125 kHz or Kbit/s
- 250 kHz or Kbit/s
- 500 kHz or Kbit/s
- 800 kHz or Kbit/s
- 1 MHz or Mbit/s

This function exists to ensure that drivers that share a `hal::can_transceiver`
can detect if the baud rate doesn't match a fixed baud rate required by another
device on the bus. CAN BUS driver may provide an out-of-interface function for
setting the baud rate, but this interface does not allow such control.

When a can driver is constructed it is passed a baud rate it should set itself
to. If the baud rate cannot be achieved the constructor will throw
`hal::argument_out_of_domain`. Note when setting up a CAN BUS network that
every device on the bus must have the same baud rate. The baud rate is not
changeable via the `hal::can_transceiver`.

```C++
void send(can_message const& p_message) = 0;
```

The send API allows a `hal::can_transceiver` to send/broadcast messages onto
the can bus. Simply construct a `hal::can_message` and pass it to this function
and it will make its way. This function will block until the message has been
sent over the bus. This means that this API could block a thread if it never
gains access over the bus long enough to transmit its message.

```C++
std::span<can_message const> receive_buffer() = 0;
std::size_t receive_cursor() = 0;
```

`hal::can_transceiver` are mandated to hold a buffer can messages received over
the bus. The user is allowed, at object construction to provide buffer memory
for the driver. That buffer is then exposed by the `receive_buffer()` API to
allow applications and drivers to scan it and to find messages meant for them.
The buffer returned from `receive_buffer()` updated as a circular buffer where
the `receive_cursor()` API indicates where the driver's write cursor position
is located. Any value returned from `receive_cursor()` will always work like so:

```C++
// `can.receive_cursor()` always returns a value between 0 and
// `can.receive_buffer().size() - 1` meaning the following expression is always
// well defined. can_message is default initialized to all zeros.
can.receive_buffer()[can.receive_cursor()];
```

See [⛓️‍💥how interface circular buffers in libhal work](.).

Using the circular buffer APIs directly can be tedious and error prone, so we
provide some utility classes in `libhal-util/can.hpp`.

#### `hal::can_message_finder`

```C++
hal::can_transceiver& can = /* ... */;
hal::can_message_finder reader(can, 0x240);
std::optional<hal::can_message> found_message = reader.find();
if (found_message) {
  // Do something with the message here...
} else {
  // Message has not not been received yet
}
```

This helper class uses the `hal::can_transceiver` to scan the receive buffer,
relative to the position of the receive cursor, and return a copy of that
`hal::can_message` with the matching ID. Find will only find messages received
after the construction of the object. If there does not exist a message with
the ID specified, `std::nullopt` is returned. Repeated calls to `find()` will
search for messages with that ID.

For example, consider we have the following messages in the receive buffer post
object creation:

1. message 0x015
2. message 0x240
3. message 0x333
4. message 0x240

The first call to find will the message at index 2 and return a copy. The
second call will find the message at index 4 and return a copy. If no
additional messages are received and `find()` is called, `std::nullopt` will be
returned.

The lifetime of the `hal::can_message_reader` is bound to the
`hal::can_transceiver` passed to it and must not exceed the lifetime of that
`hal::can_transceiver`.

#### `hal::can_message_reader`

!!! warning
    There are some safety concerns with this class returning a span to
    something that will be modified by the transceiver.

Here is an example of how to use the `hal::can_message_reader`:

```C++
hal::can_transceiver& can = /* ... */;
hal::can_message_reader reader(can);
std::optional<std::span<hal::can_message>> new_messages = reader.read();
// Confirm we have messages available
if (new_messages) {
  // Since we have some new messages, we can iterate over them and print out
  // their ID and length.
  for (auto const& message : *new_messages) {
    hal::print<64>("{ id: %" PRIu32 ", length: %" PRIu8 "}",
                   message.id(),
                   message.length);
  }
}
```

The lifetime of the `hal::can_message_reader` is bound to the
`hal::can_transceiver` passed to it and must not exceed the lifetime of that
`hal::can_transceiver`.

### CAN BUS device manager

In order to acquire implementations of the interfaces above, a can device
manager object should be created. How this object is created depends on your
platforms. As an example lets consider `stm32f103`:

```C++
namespace hal::stm32f1 {
class can {
public:
   // Constructor
  can(std::span<hal::can_message> p_receive_buffer,
      can_pins p_pins = can_pins::pa11_pa12,
      hal::u32 baud_rate = 100_kHz);
  // The rest...
}
}

// Constructing a can object using pins PB9 & PB8 on the stm32f103c8 and
// setting the bus baud rate to 1MHz.
std::array<hal::can_message, 16> receive_buffer;
hal::stm32f1::can can(receive_buffer, hal::stm32f1::can_pins::pb9_pb8, 1_MHz);

// Acquiring resources from device manager...

// Typically, a can manager object only has a single transceiver, but in some
// cases they support messages and communication over two ports. The
// `transceiver` object claims the can object's transceiver resources and
// attempting to create another will throw the `hal::device_or_resource_busy`
// exception. The resource is released on the destruction of this object.
auto transceiver = can.acquire_transceiver();

// The notes about the transceiver apply to the bus manager. There is typically
// only one and if you attempt to create multiple, the
// `hal::device_or_resource_busy` exception will be thrown.
auto bus_manager = can.acquire_bus_manager();

auto id_filter_0 = can.acquire_id_filter();
auto id_filter_1 = can.acquire_id_filter();
auto id_filter_2 = can.acquire_id_filter();
auto id_filter_3 = can.acquire_id_filter();
```

The stm32f103 only has a single CAN peripheral. Here we have to provide which
CAN TX & RX pins we want to use. Next we select the baud rate in terms of
frequency.

```C++
// Constructing a can object
hal::stm32f1::can can(hal::stm32f1::can_pins::pb9_pb8, 1_MHz);

// Acquire a transceiver from the can manager object.
auto transceiver = can.acquire_transceiver();

// Attempting to acquire a 2nd transceiver ❌ throws
// hal::device_or_resource_busy because can_transceiver is still around. If
// `can_transceiver` is destroyed, then this API can be used to acquire a new
// transceiver.
auto transceiver2 = can.acquire_transceiver(); // ❌

// Acquire a mask filter
auto mask_filter0 = can.acquire_mask_filter();
// acquire mask filters until there are no more filter resources available...
auto mask_filterN = can.acquire_mask_filter();  // ❌ throw
```

If a device runs out of a the resources needed to generate an implementation
such as a filter or bus manager, that API throws `hal::device_or_resource_busy`.

CAN devices have a limited number of filters, each with a specific set of
resources assigned to it. When acquiring a filter, the object returned manages,
controls, and holds onto these resources for the duration of the filter's
lifetime, allowing them to be reused after the filter object is destroyed. This
means that the same resources can be used for multiple filters, but only one
filter can use a particular set of resources at any given time. Here is a
demonstration of what that would look like, assuming we only had 2 mask filters:

```C++
// ✅✅ means that we have two filters available
// 🟡✅ means that one mask has been taken and the other is available

// START: ✅✅
auto mask_filter0 = can.acquire_mask_filter(); // 🟡✅
{
   auto mask_filter_scoped = can.acquire_mask_filter(); // 🟡🟡
} // mask_filter_scoped resources freed 🟡✅
auto mask_filter1 = can.acquire_mask_filter(); // 🟡🟡
// filters are exhausted and thus trying to create mask_filter2 results in an
// exception being thrown!
auto mask_filter2 = can.acquire_mask_filter(); // 🟡🟡❌
```

The same goes for acquiring a `hal::can_bus_manager`. Typically there is only
one and attempting to make two will throw an exception.

## Usage in device drivers

A typical device drivers that uses can bus interfaces will accept a
`hal::can_transceiver` and a filter. The device driver should capture the
`hal::can_transceiver` for future use and use the filter to allow messages it
expects to receive over the bus. Such a class would look like this:

```C++
class servo_controller {
public:
  servo_controller(hal::can_transceiver& p_transceiver,
                 hal::can_identifier_filter& p_filter):
                 m_can(&p_transceiver) {
    p_filter.allow(servo_message_id);
    // Do the rest...
  }

  void send_position(hal::u8 p_position) {
    hal::can_message payload;
    payload.length = 1;
    // Assume: 0 means 0deg & 255 means 360deg
    payload.payload[0] = p_position;
    payload.id(servo_message_id)
      .extended(false)
      .remote_request(false);

    m_can->send(payload);
  }

private:
  constexpr hal::u32 servo_message_id = 0x050;

  hal::can_transceiver* m_can;
};
```

In general, filters do not need to be captured. Filters can be set at driver
construction and then given back to the caller. Capturing a filter is only
necessary if the filter will have its ID modified at runtime.

The example above assumes that the driver only ever needs to write can messages
and never needs to receive them.

### Interfaces to Avoid

Device drivers should not accept `hal::can_bus_manager` or
`hal::can_message_interrupt` for any API. These interfaces are reserved for use
by applications, and accepting them could lead to disruptions in other drivers
and potentially the entire system. Additionally, `hal::can_message_interrupt`
cannot be shared because it can only support a single interrupt callback,
meaning that if two drivers were provided this interface, only the last one to
set the callback would be functional, while the previous callback would be
discarded.

### Receiving messages

When you want to also receive messages over CAN prefer to capture the
`hal::can_transceiver` via `hal::can_message_finder`. It will supply the memory
to capture the `hal::can_transceiver` and provide the necessary memory to track
new incoming messages from the `hal::can_transceiver`.

```C++
class battery_sensor {
public:
  battery_sensor(hal::can_transceiver& p_transceiver,
                 hal::can_identifier_filter& p_filter):
                 m_can(p_transceiver, battery_response_message_id) {
    p_filter.allow(battery_response_message_id);
    // Do the rest...
  }

  void request_battery_capacity() {
    hal::can_message payload;

    payload.id(battery_message_id)
      .extended(false)
      .remote_request(false);
    payload.length = 0;

    m_can.transceiver().send(payload);
  }

  std::optional<float> get_battery_capacity() {
    auto message = m_can.find();
    if (message && message.length == 1) {
      return float(message.payload[0]) / 255.0f;
    }
    return std::nullopt;
  }

private:
  constexpr hal::u32 battery_message_id = 0x050;
  constexpr hal::u32 battery_response_message_id = 0x050;

  hal::can_message_finder m_can;
};
```

The transceiver can be accessed using the `transceiver()` API.

### Selecting the right filter type

1. Select `hal::can_identifier_filter` if the device driver only needs to
   filter a single standard message ID.
2. Select `hal::can_extended_identifier_filter` if the device driver only needs
   to filter a single extended message ID.
3. Select `hal::can_range_filter` if the device driver expects to see messages
   in a range of standard message IDs.
4. Select `hal::can_extended_range_filter` if the device driver expects to see
   messages in a range of standard message IDs.
5. Select `hal::can_mask_filter` if the device driver expects to see messages
   that fit a standard identifier with some bits that can change. In general,
   this filter type isn't particular useful for device drivers.
6. Select `hal::can_extended_mask_filter` if the device driver expects to see
   messages that fit an extended identifier with some bits that can change. In
   general, this filter type isn't particular useful for device drivers.

### Filter adaptors

Can peripherals may not provide all of the filters needed by device drivers or
application. In these cases, we can use an adaptor from `libhal-util` to
convert one filter to another.

### Range to identifier filter

!!! warning
    This does not exist currently!

libhal provides `hal::range_to_identifier_can_adaptor` which can take a
`hal::can_range_filter` and generate multiple `hal::can_identifier_filters`.
This can be beneficial when the set of IDs is contiguous OR close enough
together.

```C++
hal::can_range_filter& range_filter = /* ... */;
hal::range_to_identifier_can_adaptor id_generator(range_filter);
auto id_filter_1 = id_generator.create();
auto id_filter_2 = id_generator.create();
auto id_filter_3 = id_generator.create();

id_filter_1.allow(0x111); // range 0x111 ↔ 0x111
id_filter_2.allow(0x112); // range 0x111 ↔ 0x112
id_filter_3.allow(0x117); // range 0x111 ↔ 0x117
id_filter_3.allow(0x110); // range 0x110 ↔ 0x115
id_filter_3.allow(0x116); // range 0x110 ↔ 0x115 (no change)
```

Each id generated links back to the `hal::range_to_identifier_can_adaptor`
object. They are bound by its lifetime. Each time a filter calls `allow()`, it
expands the range to fit the max and min values passed previously.

The filter is not as useful if the range between IDs is large and there are
messages within that ID range.

There exist an equivalent for extended IDs.

### Mask to identifier filter

libhal provides `hal::mask_to_identifier_can_adaptor` which can take a
`hal::can_mask_filter` and generate multiple `hal::can_identifier_filters`.

TBD...

## Making a CAN driver

TBD...
