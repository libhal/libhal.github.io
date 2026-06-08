# 📜 Design Philosophy

These are the core design tenets that `libhal` and its associated libraries must
seek to achieve with every design choice, line written, and architecture change
made.

## D.1 Multi Targeted

`libhal` and the libraries that extend it should work anywhere. So long as the
appropriate compiler or cross-compiler is used, the driver should behave as
intended. The exception is `platform` libraries, which are designated to
execute for a particular platform. Even so, platform libraries must be unit
testable on any host machine.

## D.2 General

`libhal` interfaces should be general, meaning they do not include APIs or
configuration settings that are uncommon across most targets or specific to a
particular platform.

## D.3 Safe & Reliable

`libhal` and its style guide aim to use patterns, techniques, and documentation
to reduce safety issues and improve reliability. libhal is designed with a
long-term roadmap toward functional safety certification (IEC 61508 / ISO
26262). Every design decision should consider whether it supports or obstructs
that goal.

## D.4 Tested & Testable

`libhal` code should be unit tested and designed to be testable. We have future
plans to add hardware-in-the-loop testing as part of our testing infrastructure.

## D.5 Fast Builds

`libhal` and its ecosystem provide prebuilt binaries for supported toolchain
configurations. Libraries should avoid dependencies that significantly increase
build times, and any new dependency must justify its compile-time cost.

## D.6 Portable

`libhal` code must not depend on any OS or target-specific behavior. It is
designed to work on baremetal 32-bit MCUs, Linux, macOS, and Windows from the
same source. No platform-specific code may appear outside of platform libraries.

## D.7 Explicit Over Implicit

libhal prefers explicit over implicit at every layer. Allocators are passed
as parameters rather than taken from a global. Async context is a named
parameter, not injected via thread-local storage. Dependencies are wired
visibly. If something can be made a visible, traceable part of an API without a
meaningful cost, it should be.

## D.8 Memory Safety Through Ownership

Driver dependencies that outlive a function call must be held as `hal::ptr<T>`
which is a non-nullable, reference-counted smart pointer that tracks allocator
lifetime alongside the object. Raw references are valid only for dependencies
consumed within the current call and not retained. This model ensures that
no driver can outlive the resources it depends on.
