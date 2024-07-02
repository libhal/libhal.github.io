# ⏩ DMA: Direct Memory Access Development Guide

DMA is a key feature in many microcontrollers. DMA allows data to be transferred
from one location to another without the need for the CPU to perform the copy.
This can be used to transfer large amounts of data from one place in memory to
another place. It can also be used to automatically transfer data to a
peripheral.

As an example, lets consider an peripheral implementation of `hal::spi`. In order to write an spi driver without DMA, the CPU has to load a register used by the peripheral with data, then wait for the data to be shifted out of the device, before another byte can be put in. This means that the CPU has to baby sit the spi peripheral for each and every byte that is transferred. Whereas with DMA all that is needed is to tell the controller:

1. The address of source data
2. The address of the destination data
3. The length of the transfer
4. The word width of the source & destination (8-bit, 16-bit, 32-bit)
5. \[optional\] The endianness of the transfer
6. And whether or not to increment the source and/or the destination address

After that, just fire it off and it will do the work of loading the data register for you until it finishes. On completion, an interrupt will be invoked that indicates to the application that the transfer has completed.

And that about it for simplicity. There are typically other configurations such as:

1. Stride/stride-length: how many words lengths to skip in the input or output sequence. For example, if you had two dacs and PCM16 with L/R data alternating in the array like so, `u16l0, u16r0, u16l1, u16_r1, ..., u16_ln, u16_rn`, then the left side dac could start at address 0 with a stride length of 2 to skip the right side data. The same logic can be used to setup the right dac.
2. Circular mode: DMA channels acts like a ring buffer allowing it to jump back to the start of the buffer when it reaches the end. This is very useful for `hal::serial` implementations.
3. Burst size: allows a DMA controller to keep control over the bus for multiple cycles in order to ensure that data is sent without any break time.

## Channels

DMA controllers generally have a fixed set of DMA channels. These channels can
operate independently, and allows for multiple transfer to occur at the "same"
time.

Channels can be used for a period of time or can be occupied for the lifetime of a driver. In general, DMA channels shouldn't be help for the lifetime of the
driver as that would limit the number of available DMA channels that can be used by other drivers. An explicit exception to this is `hal::serial` which requires that its implementation is backed by a buffer. It is common to see
uart implementations where there is only a single byte register for the uart data that is overwritten when the next byte is received. In order to not lose bytes, either an interrupt service routine is needed or DMA can be used fill up a buffer of bytes. Interrupts, although fast, still require cpu attention where as DMA handle this work for the cpu.

The number of channels is limited and thus it is possible for there to be more drivers that require a DMA channel than DMA channels available. In these cases, the function for setting up DMA MUST busy wait until a DMA channel is made available before returning. In general, when designing an application, it is important to be mindful of the number of DMA channels a device has and how many drivers need channels. If the number of device drivers that use 1 or more DMA channels is greater than the number of channels, then the application developer must be mindful of this and design around this constraint.

## Ram blocks

When the cpu access memory from ram, it will use the device's address and data bus to make the transfer occur. DMA is no different. If DMA attempts to access the same resource as the cpu, then either the cpu or the DMA controller will stall until the other device is finished.

A lot of devices will separate their memory into multiple ram blocks. The reason, with respect to DMA, is that having multiple ram blocks allow DMA to access one block of ram while the cpu works with ram in another ram block. If an application can design itself around this, it will help with the performance of the cpu and DMA when performing any sort of work.

For example, lets say you want to make an MP3 player project. Gaps in audio can cause audio distortions and artifacts like clicks and pops. Gaps can be prevented by always ensuring that audio is making its way to the DAC. To ensure that there is always audio available to be streamed through the DAC a double buffering approach is used, where one buffer is actively being streamed out to the DAC and the other buffer is being filled with the new audio data. A dedicated thread is provided for audio decoding and audio streaming. The audio stream thread takes a buffer of audio data, sets up DMA for the transfer and then blocks its own thread. The audio decoder can now fill the other buffer with decoded mp3 data. Now consider this, lets assume that the buffers are both on the same RAM chip. In this case, whenever the DMA and cpu attempt to access the ram block, one of them will be stalled waiting for the other to finish. This can reduce performance and potentially result in audio artifacts. If these buffers are located in different ram blocks, then the DMA can access the ram block without stalling the CPU and vise-versa.

Note that this also depends on if your system is a "Single Bus System" or a "Multi Bus System".

- **Single Bus System:** If there is only one data and address bus shared by all components, then even with multiple RAM blocks, access to these blocks is serialized through the single bus. In this case, the DMA and CPU cannot truly operate in parallel when accessing different blocks, as the single bus must arbitrate between them. This can still lead to stalls, though the overall impact might be reduced if the arbiter is efficient.
- **Multiple Bus System:** Some more complex systems might employ multiple buses (e.g., a separate bus for DMA and CPU). This architecture can allow truly concurrent access to different RAM blocks, significantly reducing or eliminating stalls because each master has its own path to memory.

## Implementing `hal::<platform>::setup_dma_transfer(dma)`

All parts of this section require the user manual for your particular device.

### Implementing the `dma` structure

The `dma` structure should include fields for every possible configuration that the dma.

!!! warning

    Channel selection should not be a field in the dam structure. The channel selected should be determined by the `setup_dma_transfer` call based on
    which channels are available. Some dma devices provide a priority for each channel. The current philosophy is to ignore this priority system and simply provide the first channel that is available and if possible make the priority of all channels the same.

Here is an example dma structure from `libhal-lpc40`:

```C++
enum class dma_transfer_type : std::uint8_t
{
  /// Flow Control: DMA controller
  memory_to_memory = 0b000,
  /// Flow Control: DMA controller
  memory_to_peripheral = 0b001,
  /// Flow Control: DMA controller
  peripheral_to_memory = 0b010,
  /// Flow Control: DMA controller
  peripheral_to_peripheral = 0b011,
  /// Flow Control: Destination Peripheral
  peripheral_to_peripheral_dp = 0b100,
  /// Flow Control: Destination Peripheral
  memory_to_peripheral_dp = 0b101,
  /// Flow Control: Source Peripheral
  peripheral_to_memory_sp = 0b110,
  /// Flow Control: Source Peripheral
  peripheral_to_peripheral_sp = 0b111
};

enum class dma_transfer_width : std::uint8_t
{
  bit_8 = 0b000,
  bit_16 = 0b001,
  bit_32 = 0b010,
};

struct dma
{
  void const volatile* source;
  void volatile* destination;
  std::size_t length;
  // With every transfer, increment the address of the source location. Set to
  // true to move forward through the length of the transaction. Set to false
  // to keep the address the same for the entire length of the transfer. Set
  // false is usually used when the address is a peripheral driver and the
  // register you are reading from updates. Set to true when you want to
  // transfer a sequence of data, an array, from ram to a peripheral or another
  // area of memory.
  bool source_increment;
  // Same as source_increment but with the destination address.
  bool destination_increment;
  dma_transfer_width source_transfer_width;
  dma_transfer_width destination_transfer_width;
  dma_transfer_type transfer_type;
};
```

Removed from the example above are the source and destination request number fields which are specific to the `lpc40` series. The burst count is also not present as well. If you're devices has such fields and are required to work, then add them to your data structure. Reading the above code should give you an idea of what a user must do in order to establish a dma transfer.

Note the technique of using a strongly typed enumeration classes as binary control patterns. When making enumeration classes for each of your configuration parameters, it is wise to give the unique constants defined in the datasheet as the constants defined in the enum class. This way, the code for `setup_dma_transfer()` does not have to perform a translation from the value of the enum class to a value that the dma hardware can understand.

When implementing the structure do the following:

1. Open datasheet and search for the "DMA" section. Generally there will be a short synopsis about the device and what it supports.
2. Read/skim the section on DMA. Locate the registers for controlling DMA and note what configurations it supports.
3. Copy the dma structure above.
4. Update the `dma_transfer_type` enum class fields with the set of values that match your device. If the enum class value codes cannot fit in std::uint8_t then the smallest size unsigned number that can fit your codes. If your device does not require or use such a construct, then simply delete the `dma_transfer_type` and `dma_transfer_type` field from the `dma` structure.
5. Update `dma_transfer_width` enum class with the binary codes for your device's DMA transfer width.
6. Add any other fields that are available for your dma besides channel selection.

### Implementing the `setup_dma_transfer` function

The dma code should look like the following. Read the comments to get an idea of what is necessary to make this work.

```C++
constexpr std::size_t dma_channel_count = 8;

// We need to provide memory to hold the callbacks for each dma channel. When
// the dma transfer is finished, an interrupt will be invoked. That interrupt
// handler will invoke the dma callback in this list.
std::array<hal::callback<void(void)>, dma_channel_count> dma_callbacks{
  hal::cortex_m::default_interrupt_handler,
  hal::cortex_m::default_interrupt_handler,
  hal::cortex_m::default_interrupt_handler,
  hal::cortex_m::default_interrupt_handler,
  hal::cortex_m::default_interrupt_handler,
  hal::cortex_m::default_interrupt_handler,
  hal::cortex_m::default_interrupt_handler,
  hal::cortex_m::default_interrupt_handler,
};

void handle_dma_interrupt() noexcept;
void initialize_dma();

// Atomic flag for acquiring the dma
std::atomic_flag dma_busy = ATOMIC_FLAG_INIT;

void setup_dma_transfer(dma const& p_configuration,
                        hal::callback<void(void)> p_interrupt_callback)
{
  // Step 1.
  //
  // Compose the configuration, control, and whatever other registers you need
  // to setup the dma.
  auto const config_value = /* ... */;
  auto const control_value = /* ... */;

  // Step 2.
  //
  // Acquire atomic lock using spin lock
  while (dma_busy.test_and_set(std::memory_order_acquire)) {
    continue;  // spin lock
  }

  // Step 3.
  //
  // Initialize dma (this should be a one shot and should return early if the
  // dma has already been initialized).
  // Ensure that this call does not throw an exception, if so, use
  initialize_dma();

  // Step 4.
  //
  // Busy wait until a channel is available
  while (true) {
    // Step 5.
    //
    // Check for an available channel.
    auto const available_channel = /* ... get available channel ... */

    // Lets assume that if the channel number is above 8 then all channels are
    // available.
    if (available_channel < 8) {
      // Step 6.
      //
      // Copy callback to the callback array
      dma_callbacks[available_channel] = p_interrupt_callback;

      // Step 7.
      //
      // Get & setup dma channel
      auto* dma_channel = get_dma_channel_register(available_channel);

      dma_channel->source_address =
        reinterpret_cast<std::uintptr_t>(p_configuration.source);
      dma_channel->destination_address =
        reinterpret_cast<std::uintptr_t>(p_configuration.destination);
      dma_channel->control = control_value;

      // Step 8.
      //
      // Start dma transfer
      dma_channel->config = config_value;
      break;
    }
  }

  // Step 9. Release lock
  dma_busy.clear();
}


void initialize_dma()
{
  // You can use the fact that the dma is powered on to determine if the device
  // has already been initialized.
  if (is_on(peripheral::gpdma)) {
    return;
  }

  // Otherwise power it on
  power_on(peripheral::gpdma);

  // Turn on interrupts
  initialize_interrupts();

  // enable the dma interrupt
  hal::cortex_m::enable_interrupt(irq::dma, handle_dma_interrupt);

  // Replace this code with what enables the dma
  dma_reg->config = 1;
}

void handle_dma_interrupt() noexcept
{
  // The zero count from the LSB tells you where the least significant 1 is
  // located. This allows the handled DMA interrupt callback to start at 0 and
  // end at the last bit.
  auto const status = std::countr_zero(dma_reg->interrupt_status);
  auto const clear_mask = 1 << status;

  // NOTE: This may not be necessary on your device
  dma_reg->interrupt_terminal_count_clear = clear_mask;
  dma_reg->interrupt_error_clear = clear_mask;

  // Call this channel's callback
  dma_callbacks[status]();
}
```

Take the above code and update the code to fit the needs of your device.
