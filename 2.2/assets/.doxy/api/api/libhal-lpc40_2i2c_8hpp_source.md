

# File i2c.hpp

[**File List**](files.md) **>** [**include**](dir_cba0faac6e93618a6e2539705915bd70.md) **>** [**libhal-lpc40**](dir_2fff134b595a3a874b0307aab0eea726.md) **>** [**i2c.hpp**](libhal-lpc40_2i2c_8hpp.md)

[Go to the documentation of this file](libhal-lpc40_2i2c_8hpp.md)

```C++

// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#pragma once

#include <atomic>
#include <cstdint>
#include <span>

#include <libhal/i2c.hpp>

#include "constants.hpp"
#include "pin.hpp"

namespace hal::lpc40 {
class i2c : public hal::i2c
{
public:
  using write_iterator = std::span<const hal::byte>::iterator;
  using read_iterator = std::span<hal::byte>::iterator;

  struct bus_info
  {
    peripheral peripheral_id;
    irq irq_number;
    pin sda;
    std::uint8_t sda_function;
    pin scl;
    std::uint8_t scl_function;
    float duty_cycle = 0.5f;
  };

  static result<i2c> get(std::uint8_t p_bus,
                         const i2c::settings& p_settings = {});

  i2c(i2c& p_other) = delete;
  i2c& operator=(i2c& p_other) = delete;
  i2c(i2c&& p_other);
  i2c& operator=(i2c&& p_other);
  ~i2c();

private:
  i2c(bus_info p_bus);

  status driver_configure(const settings& p_settings) override;
  result<transaction_t> driver_transaction(
    hal::byte p_address,
    std::span<const hal::byte> p_data_out,
    std::span<hal::byte> p_data_in,
    hal::function_ref<hal::timeout_function> p_timeout) override;

  void setup_interrupt();
  void interrupt();

  bus_info m_bus;
  write_iterator m_write_iterator;
  write_iterator m_write_end;
  read_iterator m_read_iterator;
  read_iterator m_read_end;
  std::errc m_status{};
  hal::byte m_address = hal::byte{ 0x00 };
  bool m_busy = false;
  bool m_moved = false;
};
}  // namespace hal::lpc40

```
