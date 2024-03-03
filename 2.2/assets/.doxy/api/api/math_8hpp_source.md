

# File math.hpp

[**File List**](files.md) **>** [**include**](dir_cba0faac6e93618a6e2539705915bd70.md) **>** [**libhal-util**](dir_5e94bd3e75b6b11eff60149e0bc5664b.md) **>** [**math.hpp**](math_8hpp.md)

[Go to the documentation of this file](math_8hpp.md)

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

#include <concepts>
#include <limits>

#include <libhal/error.hpp>

namespace hal {
template<typename T>
[[nodiscard]] result<T> multiply(T p_lhs, T p_rhs)
{
  if (p_lhs == 0 || p_rhs == 0) {
    return T{ 0 };
  }

  T result = p_lhs * p_rhs;

  if (p_lhs != result / p_rhs) {
    return hal::new_error(std::errc::result_out_of_range);
  }

  return result;
}

template<typename T>
[[nodiscard]] constexpr T absolute_value(T p_value)
{
  if constexpr (std::is_unsigned_v<T>) {
    return p_value;
  } else {
    if (p_value >= 0) {
      return p_value;
    }
    if (p_value == std::numeric_limits<T>::min()) {
      return std::numeric_limits<T>::max();
    }
    return -p_value;
  }
}

template<typename T>
[[nodiscard]] constexpr T rounding_division(T p_numerator, T p_denominator)
{
  bool num_sign = p_numerator >= 0;
  bool den_sign = p_denominator >= 0;

  auto numerator = absolute_value(p_numerator);
  auto denominator = absolute_value(p_denominator);

  if (denominator > numerator || denominator == 0) {
    return T{ 0 };
  }

  const T remainder = numerator % denominator;
  const T half_denominator = (denominator / 2);
  T quotient = numerator / denominator;
  // Round if remainder is greater than half of the denominator
  if (half_denominator != 0 && remainder >= half_denominator) {
    quotient++;
  }

  if (num_sign != den_sign) {
    return -quotient;
  }

  return quotient;
}

template<typename T>
[[nodiscard]] constexpr T distance(T p_left, T p_right)
{
  if (p_right > p_left) {
    return p_right - p_left;
  } else {
    return p_left - p_right;
  }
}

template<std::integral T>
[[nodiscard]] constexpr std::make_unsigned_t<T> distance(T p_left, T p_right)
{
  static_assert(sizeof(T) <= sizeof(int32_t));

  using unsigned_t = std::make_unsigned_t<T>;
  // Put left and right values into 64-bit containers to prevent overflow
  int64_t left{ p_left };
  int64_t right{ p_right };

  if (right > left) {
    // Subtraction operation on right to left in this order can never overflow
    // because the maximum resultant of left and right being INT32_MAX and
    // INT32_MIN, will equal UINT32_MAX which can be stored within an int64_t
    // value.
    int64_t difference = right - left;
    // Casting this value to the unsigned variant will always fit as the
    // distance between any 32-bit signed numbers can always fit in a 32-bit
    // unsigned number.
    return static_cast<unsigned_t>(difference);
  } else {
    // Same logic as the if statement block above.
    int64_t difference = left - right;
    return static_cast<unsigned_t>(difference);
  }
}
constexpr static bool equals(std::floating_point auto p_value1,
                             std::floating_point auto p_value2,
                             float p_epsilon = 1e-9f)
{
  if (p_value1 == p_value2) {
    return true;
  }
  auto value1_abs = std::abs(p_value1);
  auto value2_abs = std::abs(p_value2);
  auto diff = std::abs(p_value1 - p_value2);
  auto absolute_values_sum = value1_abs + value2_abs;

  using float_t = decltype(absolute_values_sum);

  if (p_value1 == 0 || p_value2 == 0 ||
      (absolute_values_sum < std::numeric_limits<float_t>::min())) {
    return diff < (p_epsilon * std::numeric_limits<float_t>::min());
  } else {
    auto relative_error =
      diff / std::min(absolute_values_sum, std::numeric_limits<float_t>::max());
    return relative_error < p_epsilon;
  }
}
}  // namespace hal

```
