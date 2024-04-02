# 🚀 Getting Started

## 🧰 Install Prerequisites

What you will need in order to get started with libhal.

- `python`: 3.10 or above
- `conan`: 2.2.0 or above
- `clang`: 17

=== "Ubuntu 20.04+"

    Install Python 3.10 (only required for 20.04):

    ```
    sudo apt update
    sudo apt install software-properties-common -y
    sudo add-apt-repository ppa:deadsnakes/ppa
    sudo apt install Python3.10
    ```

    Install `llvm` toolchain & APT repos:

    ```
    wget https://apt.llvm.org/llvm.sh
    chmod +x llvm.sh
    sudo ./llvm.sh 17
    ```

    Install LLVM's C++ standard library (this will use the llvm apt repos):

    ```
    sudo apt install libc++-17-dev libc++abi-17-dev
    ```

    Installing conan:

    ```
    python3 -m pip install "conan>=2.2.2"
    ```

=== "MacOS X"

    Install Homebrew:

    ```
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ```

    Install latest version of Python && llvm:

    ```
    brew install python
    brew install llvm@17
    ```

    Install conan:

    ```
    python3 -m pip install "conan>=2.2.2"
    ```

    Make `clang-tidy` available on the command line:

    ```
    sudo ln -s $(brew --prefix llvm)/bin/clang-tidy /usr/local/bin/
    ```

    Install Rosetta (only required for M1 macs):

    ```
    /usr/sbin/softwareupdate --install-rosetta --agree-to-license
    ```

=== "Windows"

    We recommend using the `choco` package manager for windows as it allows
    easy installation of tools via the command line.

    To install `choco`, open PowerShell as an administrator and run the
    following command:

    ```powershell
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    ```

    !!! tip

        If the `choco` command doesn't work after running this script try
        closing and opening again PowerShell.

    Now install `python`:

    ```powershell
    choco install python
    ```

    Install llvm:

    ```powershell
    choco install llvm --version=17.0.6
    ```

    Installing conan:

    ```powershell
    python -m pip install -U "conan>=2.2.2"
    ```

---

## 🔧 Setting up Conan

Add the `libhal-trunk` repository to your system. This repository holds all of
the libhal packages.

```bash
conan remote add libhal-trunk https://libhal.jfrog.io/artifactory/api/conan/trunk-conan
```

Next, install the libhal `settings_user.yml` which extends the architectures of
conan's `settings.yml` file to include baremetal architectures. These additional
architecture definitions are required for ALMOST ALL libhal applications.

```bash
conan config install -sf profiles/baremetal/v2 https://github.com/libhal/conan-config.git
```

Next, setup the host profile. Host profiles define the compiler,
compiler version, standard library version, and many other settings used to
configure how applications are built.

First detect the default. This will be overwritten in the next step.

```bash
conan profile detect --force
```

Now install the profile for your particular OS and CPU architecture.

=== "Intel Linux"

    If your host machine is using an intel core processor as its CPU then you'll
    want to use this default configuration.

    ```bash
    conan config install -sf profiles/x86_64/linux/ -tf profiles https://github.com/libhal/conan-config.git
    ```

=== "ARM64 Linux"

    It is less likely your host desktop is an ARM64. This section is mostly for
    building applications and tests on a Raspberry PI or other SBC. But if you
    do have a laptop powered by an ARM64 core, then this is the correct
    configuration for you.

    ```bash
    conan config install -sf profiles/armv8/linux/ -tf profiles https://github.com/libhal/conan-config.git
    ```

=== "M1 Mac"

    If your Mac Book uses an M1 processor then you'll want to use this default
    configuration.

    ```bash
    conan config install -sf profiles/armv8/mac/ -tf profiles https://github.com/libhal/conan-config.git
    ```

=== "Intel Mac"

    If your Mac Book uses an Intel processor then you'll want to use this default
    configuration.

    ```bash
    conan config install -sf profiles/x86_64/mac/ -tf profiles https://github.com/libhal/conan-config.git
    ```

=== "Intel Windows"

    If your Windows machine uses an Intel processor then you'll want to use this
    default configuration.

    ```bash
    conan config install -sf profiles/x86_64/windows/ -tf profiles https://github.com/libhal/conan-config.git
    ```

=== "ARM64 Windows"

    If you have a modern surface laptop with ARM64, then this may be the right
    choice for you (this profile is untested).

    ```bash
    conan config install -sf profiles/armv8/windows/ -tf profiles https://github.com/libhal/conan-config.git
    ```

---

## 🛠️ Building Demos

Clone the target library you would like to run the demos for. You can download
just one or both if you have both devices.

!!! warning

    stm32f103 not ported to libhal 3.0.0 yet, please do not use these steps for
    it. This will be fixed when the migration is complete. Thank you for your
    patience.

=== "LPC4078"

    ```bash
    git clone https://github.com/libhal/libhal-lpc40
    cd libhal-lpc40
    ```

=== "STM32F103"

    ```bash
    git clone https://github.com/libhal/libhal-stm32f1
    cd libhal-stm32f1
    ```

The next command will install the profiles for the and LPC40 series
micro-controllers. For LPC40 micro-controllers there are: `lpc4072`, `lpc4074`,
`lpc4076`, `lpc4078`, and `lpc4088`.

=== "LPC4078"

    ```
    conan config install -sf conan/profiles/v2 -tf profiles https://github.com/libhal/libhal-lpc40.git
    ```

=== "STM32F103"

    ```
    conan config install -sf conan/profiles/v2 -tf profiles https://github.com/libhal/libhal-stm32f1.git
    ```

The compiler used to cross build application for the ARM Cortex M series is the
Arm-Gnu-Toolchain. Profiles are provided that allow you to select which version
of the compiler you want to use. These profiles set the compiler package as the
global compiler ensuring that un0built dependencies use it for building
libraries. It can be installed using:


```bash
conan config install -tf profiles -sf conan/profiles/v1 https://github.com/libhal/arm-gnu-toolchain.git
```

Now we have everything we need to build our project. To build using conan you just need to run the following:

=== "LPC4078"

    ```bash
    conan build demos -pr lpc4078 -pr arm-gcc-12.3
    ```

=== "STM32F103"

    ```bash
    conan build demos -pr stm32f103 -pr arm-gcc-12.3
    ```

!!! note

    You may need to add the argument `-b missing` at the end of the above
    command if you get an error stating that the prebuilt binaries are missing.
    `-b missing` will build them locally for your machine. After which those
    libraries will be cached on your machine and you'll no longer need to
    include those arguments.

When this completes you should have some applications in the
`build/lpc4078/MinSizeRel/` with names such as `uart.elf` or `blinker.elf`.

Each micro-controller has different properties such as more or less ram and
the presence or lack of a floating point unit.

!!! error

    You can get this error if the arm gnu toolchain wasn't installed correctly
    and the cmake toolchain was already generated.

    ```
      The CMAKE_CXX_COMPILER:

        /Users/kammce/.conan2/p/b/arm-ged7418b49387e/p/bin/bin/arm-none-eabi-g++

      is not a full path to an existing compiler tool.
    ```

    Fix this by deleting the `build/` in the `demo` directory like so:

    ```
    rm -r demos/build
    ```

## 💾 Uploading Demos to Device

In order to complete this tutorial you'll one of these devices:

- LPC4078 MicroMod with SparkFun ATP board
- SJ2 Board
- STM32F103 MicroMod with SparkFun ATP board
- STM32 Blue Pill along with USB to serial adapter

!!! question

    Don't know which serial port to use? Use this guide [Find Arduino Port
    on Windows, Mac, and
    Linux](https://www.mathworks.com/help/supportpkg/arduinoio/ug/find-arduino-port-on-windows-mac-and-linux.html)
    from the MATLAB docs to help. Simply ignore that its made for Arduino, this
    guide will work for any serial USB device.

=== "LPC4078"

    Install the [`nxpprog`](https://pypi.org/project/nxpprog/) flashing software
    for LPC devices:

    ```bash
    python3 -m pip install nxpprog
    ```

    !!! tip

        On Ubuntu 22.04 you will need to use the command `python3.10` because
        the default python is usually 3.8.

        ```bash
        python3.10 -m pip install nxpprog
        ```

    ```bash
    nxpprog --control --binary "build/lpc4078/MinSizeRel/uart.elf.bin" --device "/dev/tty.usbserial-140"
    ```

    - Replace `/dev/tty.usbserial-140` with the correct port.
    - Replace `uart.elf.bin` with any other application found in the
      `demos/applications/` directory.

=== "STM32F103"

    Install the `stm32loader` flashing software for STM32 devices:

    ```bash
    python3 -m pip install stm32loader
    ```

    then

    ```bash
    stm32loader -p /dev/tty.usbserial-10 -e -w -v demos/build/stm32f103c8/Debug/blinker.elf.bin
    ```

    Replace `/dev/tty.usbserial-10` with the correct port.

    Use `demos/build/stm32f103c8/Debug/blinker.elf.bin` or replace it with any other
    application to be uploaded.

## ⚡️ Changing Built Type

The build type determins the optimization level of the project. The libhal default for everything is `MinSizeRel` because code size is one of the most important aspects of the project.

You can also change the `build_type` to following build types:

- ❌ **Debug**: No optimization, do not recommend, normally used for unit
  testing.
- 🧪 **RelWithDebInfo**: Turn on some optimizations to reduce binary size and
  improve performance while still maintaining the structure to make
  debugging easier. Recommended for testing and prototyping.
- ⚡️ **Release**: Turn on optimizations and favor higher performance
  optimizations over space saving optimizations.
- 🗜️ **MinSizeRel**: Turn on optimizations and favor higher space saving
  optimizations over higher performance.

Note that `Release` and `MinSizeRel` build types both usually produce
binaries faster and smaller than `RelWithDebInfo` and thus should definitely
be used in production.

To override the default and choose `Release` mode simply add the following to
your conan command: `-s build_type=Release`

## 🎉 Creating a new Project

Start by cloning `libhal-starter`:

```bash
git clone https://github.com/libhal/libhal-starter.git
```

Take a look at the `README.md` of
[libhal/libhal-starter](https://github.com/libhal/libhal-starter) to get
details about how to modify the starter project and make it work for your needs.
