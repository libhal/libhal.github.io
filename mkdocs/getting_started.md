# 🚀 Getting Started

## 🧰 Install Prerequisites

What you will need in order to get started with libhal.

- `python`: 3.10 or above
- `conan`: 2.2.0 or above
- `llvm`: 17
- `make`: (CMake is downloaded via conan and uses make to build)
- `git` (only needs to be installed on Windows)

=== "Ubuntu 20.04+"

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

    !!! info

        If you are using 20.04 you will need to upgrade Python to 3.10:

        ```
        sudo apt update
        sudo apt install software-properties-common -y
        sudo add-apt-repository ppa:deadsnakes/ppa
        sudo apt install Python3.10
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

    When `choco` prompts you to run install scripts from the commands below
    enter `all` so it can install everything.

    Install `git` (must be in admin powershell):

    ```powershell
    choco install git
    ```

    Install mingw to get mingw-make for Windows CMake
    (must be in admin powershell):

    ```powershell
    choco install mingw
    ```

    Install `python` (must be in admin powershell):

    ```powershell
    choco install python --version=3.12.2
    ```

    Install llvm (must be in admin powershell):

    ```powershell
    choco install llvm --version=17.0.6
    ```

    Install conan (must be in admin powershell):

    ```powershell
    python -m pip install -U "conan>=2.2.2"
    ```

    There is no more installation required at this point.

    Close and reopen powershell as a normal user now.

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

First detect the default.

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

Before start building demos, we have to consider on what device do we plan to run the demo on? ARM microcontrollers are quite common so lets use that as an example. Lets clone the `libhal-arm-mcu` repo.

```bash
git clone https://github.com/libhal/libhal-arm-mcu
cd libhal-arm-mcu
```

The next lets install the device profiles. Device profiles instruct the build system, conan & cmake, to build the binaries for your particular device. A few commonly used profiles are the `lpc4078` and `stm32f103c8` profiles. To make them available on your system run the following command:

```bash
conan config install -sf conan/profiles/v1 -tf profiles https://github.com/libhal/libhal-arm-mcu.git
```

The device profiles only has half of the information. The other half needed to build an application is the compiler profile. Compiler profiles are used to instruct the conan+cmake build system on the compiler to use for the build.

```bash
conan config install -sf conan/profiles/v1 -tf profiles https://github.com/libhal/arm-gnu-toolchain.git
```

Now we have everything we need to build our project. To build using conan you
just need to run the following:

=== "LPC4078"

    ```bash
    conan build demos -pr lpc4078 -pr arm-gcc-12.3
    ```

=== "STM32F103"

    ```bash
    conan build demos -pr stm32f103c8 -pr arm-gcc-12.3
    ```

When you build for the `lpc4078` you should have a `uart.elf` and `blinker.elf`
file in the `demos/build/lpc4078/MinSizeRel/` directory.

When you build for the `stm32f103c8` you should have a `uart.elf` and
`blinker.elf` file in the `demos/build/stm32f103c8/MinSizeRel/` directory.

!!! error

    You can get this error if the arm gnu toolchain wasn't installed correctly
    and the cmake toolchain was already generated.

    ```
      The CMAKE_CXX_COMPILER:

        /Users/user_name/.conan2/p/b/arm-ged7418b49387e/p/bin/bin/arm-none-eabi-g++

      is not a full path to an existing compiler tool.
    ```

    Fix this by deleting the `demos/build/` like so:

    ```
    rm -r demos/build
    ```

## 💾 Uploading Demos to Device

In order to complete this tutorial you'll one of these devices:

- LPC4078 MicroMod with SparkFun ATP board
- SJ2 Board
- STM32F103 MicroMod with SparkFun ATP board
- STM32 Blue Pill along with USB to serial adapter

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
    nxpprog --control --binary demos/build/lpc4078/MinSizeRel/uart.elf.bin --device /dev/tty.usbserial-140
    ```

    - Replace `/dev/tty.usbserial-140` with the correct port
      name of the device plugged into your computer via USB.
    - Replace `uart.elf.bin` with any other application found in the
      `demos/applications/` directory.

=== "STM32F103"

    Install the `stm32loader` flashing software for STM32 devices:

    ```bash
    python3 -m pip install stm32loader
    ```

    then

    ```bash
    stm32loader -e -w -v -B -p /dev/tty.usbserial-10 demos/build/stm32f103c8/MinSizeRel/uart.elf.bin
    ```

    Replace `/dev/tty.usbserial-10` with the correct port
    name of the device plugged into your computer via USB.

    Use `demos/build/stm32f103c8/Debug/uart.elf.bin` or replace it with any
    other application to be uploaded.

!!! question

    Don't know which serial port to use?
    ### On Linux
    With the device unplugged, run the below command
    ```
    $ ls /dev/ttyUSB*
    ls: cannot access '/dev/ttyUSB*': No such file or directory
    ```
    Plug the device into the USB port, then rerun the command, the device should appear in the result:
    ```
    $ ls /dev/ttyUSB*
    /dev/ttyUSB0
    ```
    The device may also be under the name `/dev/ttyACM*`, like below
    ```
    $ ls /dev/ttyACM*
    /dev/ttyACM0
    ```
    From the above 2 examples for device name, the port name in the `stm32loader` command would be
    replaced with `/dev/ttyUSB0` or `/dev/ttyACM0` respectively.

    ### On Mac
    With the device unplugged, run the below command
    ```
    $ ls /dev/tty.usbserial-*
    zsh: no matches found: /dev/tty.usbserial-*
    ```
    Plug the device into the USB port, then rerun the command, the device should appear in the result:
    ```
    $ ls /dev/tty.usbserial-*
    /dev/tty.usbserial-14240
    ```

    From the above example for the device name, the port name in the `stm32loader` command would be
    replaced with `/dev/tty.usbserial-14240`.
    ### On Windows
    Open Device Manager, by pressing the Windows key and typing "Device Manager", then pressing enter.

    Once the Device Manager window is open, plug the device in to your computer via USB and expand
    the `Ports (COM & LPT)` menu. The device should be visible in the list with a COM port like below:

    ![image](./assets/device-manager.png)
    From the above screenshot, the port name in the `stm32loader` command would be
    replaced with `COM3`.

## ⚡️ Changing Built Type

The build type determines the optimization level of the project. The libhal default for everything is `MinSizeRel` because code size is one of the most important aspects of the project.

You can also change the `build_type` to following build types:

- 🧪 **Debug**: Turn on some optimizations to reduce binary size and improve
  performance while still maintaining the structure to make debugging easier.
  Recommended for testing and prototyping.
- ⚡️ **Release**: Turn on optimizations and favor higher performance
  optimizations over space saving optimizations.
- 🗜️ **MinSizeRel**: Turn on optimizations and favor higher space saving
  optimizations over higher performance.

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
