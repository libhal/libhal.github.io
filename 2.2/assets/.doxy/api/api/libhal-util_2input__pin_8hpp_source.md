

# File input\_pin.hpp

[**File List**](files.md) **>** [**include**](dir_cba0faac6e93618a6e2539705915bd70.md) **>** [**libhal-util**](dir_5e94bd3e75b6b11eff60149e0bc5664b.md) **>** [**input\_pin.hpp**](libhal-util_2input__pin_8hpp.md)

[Go to the documentation of this file](libhal-util_2input__pin_8hpp.md)

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

#include <libhal/input_pin.hpp>

namespace hal {
[[nodiscard]] constexpr auto operator==(const input_pin::settings& p_lhs,
                                        const input_pin::settings& p_rhs)
{
  return p_lhs.resistor == p_rhs.resistor;
}
}  // namespace hal

```
