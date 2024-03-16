# Upgrading a Device Library from libhal 2.x.y to 3.x.y

This guide is for device, utility, RTOS, or any other cross platform libraries that need to be ported from libhal 2.x.y to 3.x.y.

The upgrade to libhal 3.x.y is a breaking change for everything so their major
number for your library will need to be updated. So if the previous version was
2.1.5, then its new version is 3.0.0. If the version was 3.0.1, then the next
is 4.0.0. Remember that version for later because everywhere in this code with
where you see `3.0.0` replace it with the correct version for your library.

## (1) Set the `ci.yml` to the following

```yaml
name: ✅ CI

on:
  workflow_dispatch:
  pull_request:
  push:
    branches:
      - main
  schedule:
    - cron: "0 12 * * 0"

jobs:
  ci:
    uses: libhal/ci/.github/workflows/library_check.yml@5.x.y
    secrets: inherit

  deploy_cortex-m4f_check:
    uses: libhal/ci/.github/workflows/deploy.yml@5.x.y
    with:
      arch: cortex-m4f # Replace with correct architecture
      os: baremetal
      compiler: gcc
      compiler_version: 12.3
      compiler_package: arm-gnu-toolchain
    secrets: inherit

  demo_check:
    uses: libhal/ci/.github/workflows/demo_builder.yml@5.x.y
    with:
      compiler_profile_url: https://github.com/libhal/arm-gnu-toolchain.git
      compiler_profile: v1/arm-gcc-12.3
      platform_profile_url: https://github.com/libhal/libhal-lpc40.git
      platform_profile: v2/lpc4078 # replace if you are not using lpc4078
    secrets: inherit
```

This will handle everything you need for checking your library conforms to the
libhal standards.

## (2) Add a release yaml file with the next version of the library

The new scheme for launching versions is to have a workflow dispatch action
file. This action must be manually invoked to launch a version. This allows for
more control over which versions are deployed to the server as well as launching revisions if a dependency has a bug but a client cannot upgrade the
library version.

The file name in the `.github` file will be `X.0.0.yml` where X is the next major version number.

```yaml
name: 🚀 Deploy 3.0.0 # Replace with the next major version

on:
  workflow_dispatch:

jobs:
  deploy:
    uses: libhal/ci/.github/workflows/deploy_all.yml@5.x.y
    with:
      version: 3.0.0 # Replace with the next major version must match the title
    secrets: inherit
```

## (3) Refactor library `conanfile.py` (found at the root of the repo)

Replace the contents of the file with the data below:

```python
# Copyright 2024 Khalil Estell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from conan import ConanFile

required_conan_version = ">=2.0.14"


class libhal___device___conan(ConanFile):
    name = "libhal-__device__"
    license = "Apache-2.0"
    homepage = "https://github.com/libhal/libhal-__device__"
    description = ("... fill this out ...")
    topics = ("... fill this out ...")
    settings = "compiler", "build_type", "os", "arch"

    python_requires = "libhal-bootstrap/[^1.0.0]"
    python_requires_extend = "libhal-bootstrap.library"

    def requirements(self):
        bootstrap = self.python_requires["libhal-bootstrap"]
        bootstrap.module.add_library_requirements(self)

    def package_info(self):
        self.cpp_info.libs = ["libhal-__device__"]
        self.cpp_info.set_property("cmake_target_name", "libhal::__device__")
```

Replace every instance of `__device__` with the name of the library.

```python
    description = ("... fill this out ...")
    topics = ("... fill this out ...")
```

Fill the `description` and `topics` sections based on what they were before.

## (4) Update CMakeLists.txt

Remove the following packages and link libraries from your CMake file. These
are now automatically linked against your library when you use
`libhal_test_and_make_library`.

```cmake
  PACKAGES
  libhal
  libhal-util

  LINK_LIBRARIES
  libhal::libhal
  libhal::util
```

## (5) Update `test_package/CMakeLists.txt`

Replace it with this, update `__device__` to the correct library name:

```cmake
# Copyright 2024 Khalil Estell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cmake_minimum_required(VERSION 3.15)
project(test_package LANGUAGES CXX)

find_package(libhal-__device__ REQUIRED CONFIG)

add_executable(${PROJECT_NAME} main.cpp)
target_include_directories(${PROJECT_NAME} PUBLIC .)
target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_20)
target_link_libraries(${PROJECT_NAME} PRIVATE libhal::__device__)
```

## (5) Update `test_package/conanfile.py`

Replace it with this:

```python
# Copyright 2024 Khalil Estell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from conan import ConanFile


class TestPackageConan(ConanFile):
    settings = "os", "arch", "compiler", "build_type"

    python_requires = "libhal-bootstrap/[^1.0.0]"
    python_requires_extend = "libhal-bootstrap.library_test_package"

    def requirements(self):
        self.requires(self.tested_reference_str)
```

## (5) Replace `demos/conanfile.py`

Replace it with the following:

```python
# Copyright 2024 Khalil Estell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from conan import ConanFile


class demos(ConanFile):
    python_requires = "libhal-bootstrap/[^1.0.0]"
    python_requires_extend = "libhal-bootstrap.demo"

    def requirements(self):
        bootstrap = self.python_requires["libhal-bootstrap"]
        bootstrap.module.add_demo_requirements(self)
        # Change 3.0.0 to the correct major release number
        # Replace __device__ with the name of the library
        self.requires("libhal-__device__/[^3.0.0 || latest]")
```

!!! info

    You may be wonder why we have `|| latest` for the version range. "latest" is the version used by CI to ensure that the demo builds using the "latest"
    version built on the CI's virtual machine. It isn't a valid libhal version for a library, so we can use it for CI purposes.

## (6) Replace `demos/CMakeLists.txt`

```cmake
# Copyright 2024 Khalil Estell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cmake_minimum_required(VERSION 3.20)

project(demos LANGUAGES CXX)

libhal_build_demos(
    DEMOS
    demo1
    demo2
    # Add more demos if applicable

    PACKAGES
    libhal-__device__

    LINK_LIBRARIES
    libhal::__device__
)
```

`libhal`, `libhal-util`, and `libhal-__platform__` (where `__platform__` is
the platform defined in your platform profile file), are automatically
searched for and linked into your project, so you only need to link in your
library and any others that are needed for the demos to build correctly.

Add any other additional packages that are linked in beyond the `__device__`.

Replace `demo1` and `demo2` with the correct demo names in the `applications`
directory. Demos have the name `demo_name.cpp`, and the name you put in the
`DEMOS` list is their name without the `.cpp` extension.

## (7) Refactor code

This is where the fun bit comes in. Now that all of the interfaces have been
modified, Each header and cpp file that uses them will need to fixed up.

1. For every api that inherits an interface, update the APIs for derived class
   to match the new interface.
2. Replace factory functions with constructors (make functions should stay the
   same as they were before).
3. Use exceptions rather than `return hal::new_error()`. Make sure to use
   `hal::safe_throw` instead of `throw` directly. To know which exception to
   throw you MUST read the `libhal/error.hpp` file and determine which
   exception fits the best. If none of them seem to fit, join the discord and
   ask about it in the "discussions" channel. Also consider leaving an issue on the `libhal/libhal` repo about the error you'd like to add to the list or if you aren't sure. See `std::errc` for the list of error codes we use to make our exceptions.

## (8) Refactor `tests_package/`

Update the test package to use the newly refactored code. If there is nothing
in the `main.cpp` besides including a header file, then leave it as is.

## (8) Refactor tests

This shouldn't be too hard. Apply the same techniques used in refactor code.
Be sure to look at `libhal-util`, `libhal-soft` and `libhal-mock` to get an idea of what is needed for the refactor. Remove all of the checks for success
status such as:

```C++
  expect(!result1);
  expect(!result2);
  expect(!result3);
  expect(!result4);
  expect(!result5);

  // or

  expect(bool{ result1 });
  expect(bool{ result2 });
  expect(bool{ result3 });
  expect(bool{ result4 });
  expect(bool{ result5 });
```

To test for a thrown exception use the following pattern:

```C++
  expect(throws<hal::argument_out_of_domain>([&]() {
    test_subject_object.function_that_will_throw(input_that_will_cause_throw);
  }));
```

`throws` checks if an exception of a particular type is thrown and will catch it and return an expectation value. It takes a lambda or any other callable,
that invokes the throwing behavior. If the calls do not throw an exception then
throws fails and reports that to the user.

## (7) Refactor test_package

Remove any code needed for boost.

```C++
namespace boost {
void throw_exception(std::exception const& e)
{
  hal::halt();
}
}  // namespace boost
```

Remove anything that is target specific in the test package such as cross
compile flags. Those flags MUST be removed and only handled by the compiler.

Update the test package to make the new APIs.

## Questions?

If you have any questions please post them in the `discussions` channel in
discord. Make sure to make it a thread so the main channel is not overwhelmed
with messages.
