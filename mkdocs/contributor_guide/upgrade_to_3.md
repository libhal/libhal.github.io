# Upgrading a library from libhal 2.x.y to 3.x.y

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
```

This will handle everything you need for checking your library conforms to the
libhal standards.

## (2) Add a release yaml file with the next version of the library

The file name in the `.github` file will be `3.0.0.yml` if you are launching
that version.

### For device, util, or any other cross platform libraries

```yaml
name: 🚀 Deploy 3.0.0

on:
  workflow_dispatch:

jobs:
  deploy:
    uses: libhal/ci/.github/workflows/deploy-all.yml@5.x.y
    with:
      version: 3.0.0
    secrets: inherit
```

### For header only libraries

```yaml
name: 🚀 Deploy 3.0.0

on:
  workflow_dispatch:

jobs:
  deploy:
    uses: libhal/ci/.github/workflows/deploy.yml@5.x.y
    with:
      compiler: gcc
      version: 3.0.0
      arch: x86_64
      compiler_version: 12.3
      compiler_package: ""
      os: Linux
    secrets: inherit
```

We only deploy to linux x86_64 because its simple. Its not super important which target we select as we are only deploying a recipe and header files.

### For platform libraries

See `libhal-lpc4078`'s usage and apply the same thing for your library.

## (3) Refactor `conanfile.py`

1. Set `required_conan_version` to `required_conan_version = ">=2.1.0"`.
2. Remove `version` attribute from `conanfile.py`
3. Set `libhal` version to `[^3.0.0]` &
4. Add `transitive_headers=True` as a second parameter to `self.requires`
5. Upgrade any other libraries needed for the package such as libhal-util

## (4) Refactor code

This is where the fun bit comes in. Now that all of the interfaces have been
modified, Each header and cpp file that uses them will need to fixed up.

1. For every api that inherits an interface, update the APIs for derived class
   to match the new interface.
2. Replace factory functions with constructors (make functions should stay the
   same as they were before).
3. Use exceptions rather than `return hal::new_error()`. Make sure to use
   `hal::safe_throw` instead of `throw` directly. To know which exception to
   throw you MUST read the `libhal/error.hpp` file and determine which
   exception fits the best.

## (5) Refactor tests

This shouldn't be too hard. Apply the same techniques used in refactor code.
Be sure to look at `libhal-util`, `libhal-soft` and `libhal-mock` to get an idea of what is needed for the refactor.

## (6) Refactor test_package

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
discord. Make sure to make it a thread so the main channel is not overwhelmed with messages.
