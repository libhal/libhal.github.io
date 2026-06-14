# ⏳ Async Policy & Techniques

libhal uses **C++23 coroutines** as the primary mechanism for asynchronous
operations. This page covers when and how to use async patterns in drivers.

## Async Policy

In general, libhal interfaces utilizes virtual functions which are
implemented by a driver. All APIs that have the potential to be async, must
have a return value of `hal::future<T>` and take `async::context&` as a first
parameter. This enables the implementation of the function to either be a
coroutine or a normal function.

## Implementing a sync (non-coroutine) function

In may cases, the usage of `co_await` or `co_return` is not necessary and adds
additional overhead. Some examples of sync APIs would be:

- Setting or reading the state of a GPIO
- Memory mapped DAC with no waiting requirement
- Reading a sample from an ADC with continuous conversion
  - Continuos conversion means that the ADC is always sampling the analog pin
    and updating the ADC value register

```C++
// ❌ Async when not needed - adds overhead
hal::future<int> read_sample(async::context&) {
  co_return reg->data;
}

// ✅ Synchronous operation - direct return
hal::future<int> read_sample(async::context&) {
  return reg->data;
}
```

If you use a normal `return` statement, this will implement the function as a
normal function. The future will be constructed in a "done" state with the value
of `reg->data`.

## Handling Completion Interrupts

A very common pattern in hardware are completion interrupts. These are
interrupts that fire when a bit of work has completed. For example, reading
from an ADC.

```cpp
namespace {
  // Global mutex for this ADC channel. This is allowed to be global since it
  // corresponds to a singular resource and a singular interrupt service
  // routine.
  async::mutex adc_resource_owner;
}

hal::future<u16> my_adc::driver_read(async::context& p_ctx) {
  // If this resource is already in use by another context, then `lock` will
  // block the context by "sync". Resuming the context gives that context
  // a shot at check the resource to see if its available. If its available
  // then the guard is created and the resource is owned by p_ctx. When guard is
  // destroyed, so p_ctx's ownership of this resource.
  auto const guard = adc_resource_owner.lock(p_ctx);

  // Enable ADC interrupt and kick off the ADC sample conversion
  start_adc_conversion();

  // This loop ensures that if the context was unblocked and resumed, but the
  // conversion is not complete, then the coroutine suspends itself again.
  while (not conversion_complete()) {
    // Wait for the interrupt to signal completion
    co_await p_ctx.block_by_signal();
  }

  co_return adc_value();
}

extern "C" {
// This ISR just has to unblock the context and thats it
void adc_conversion_completion_isr() {
  adc_resource_owner->unblock_and_release();
}
}
```

The same pattern works even if you're interrupt is more complicated. For example
I2C interrupt service routines tend to be state machines. In that case, simply
unblock the context when the state machine reaches its termination point.

## Polling-Based Async

Some operations naturally poll rather than block. This can happen when a sensor
or device doesn't support any sort of signal to indicate that it has finished
its work. In these cases, suspending or suspending for a duration of time is
useful.

Use `co_await async::yield(ctx)` or time-based blocking to periodically check
status:

```cpp
hal::future<u16> my_adc::driver_read(async::context& p_ctx) {
  int timeout = 10;

  while (!sensor->is_ready() && timeout-- > 0) {
    // Option 1: Yield to allow the scheduler to run other work
    co_await async::yield(p_ctx);

    // Option 2: Brief delay between polls
    using namespace std::chrono_literals;
    co_await 10ms;
  }

  if (timeout <= 0) {
    throw std::runtime_error("timeout");
  }

  co_return sensor->read();
}
```

Choose a time delay if you have an expectation on when the data will be
available. Use `async::yield` sparingly since it keeps the async operation
ready, which prevents the system from going to sleep.
