# 🪤 Error Handling in libhal

libhal utilizes C++ exception handling for transmitting errors. C++ exceptions
were chosen over other error handling mechanisms because they:

1. Improve code performance by separating error handling code from normal
   code, thus enhancing the performance of the normal code by reducing the
   cost of calling functions that could fail.
2. Make error handling easier by allowing the user to wrap multiple blocks of
   code within a handler distinguished by the type/category.
3. Reduce the binary size of libraries and applications by:
   1. Using a single algorithm to allocate, construct, and transport errors
      and direct the CPU to the appropriate error handling code.
   2. Eliminating the need for functions to contain error return paths when
      participating in error propagation.
   3. Providing an error path using unwind instructions, a compressed form of
      machine instructions that simulate the epilog of a function, but without
      the requirement to return objects on the stack.
4. Although handler code can increase the code size compared to plain code
   (if/else/switch), the number of error handling blocks (`catch` blocks) is
   typically much smaller compared to the cost of a distributed error handling
   approach (`result<T, E>`, returning error codes, `optional/nil/null`).
5. Offer additional space in which they could be significantly improved upon
   beyond their current performance.

With that out of the way, let's delve into how libhal manages errors.

## How to use exceptions in C++

Let's start with signaling an error. This can be done by writing the following
bit of code:

```C++
void check_if_device_is_valid(/* ... */) {
  constexpr hal::byte expected_id = 0xAD;

  // Get ID info from device ...

  if (expected_id != retrieved_id) {
     throw hal::no_such_device(this, expected_id);
  }
}
```

And to catch the thrown error you do this following:

```C++
void bar() {
  try {
    check_if_device_is_valid(/* ... */);
  } catch(const hal::no_such_device& p_error) {
    // do something using the error info.
  }
}
```

Note that this is a simplified example.

The `throw` keyword functions similarly to other languages, where you can
throw or raise an error object. This exits the function's scope without
returning normally. This action causes the system to revert the CPU's state
back to the state of the try scope. The exception mechanism then moves the
CPU's program counter to the correct catch block based on the thrown type. In
this case, since we threw `hal::no_such_device`, the catch block for that type
will be selected. If no catch blocks are present with a valid error type in any
scope from which the error object was thrown, then `std::terminate()` is called.

Everything within the scope of the try block is no longer valid memory. The
significance of this is that the exception unwinding mechanism can and must
skip spending cycles on constructing and bubbling objects from a lower stack
frame to a higher one. Since the thrown object is the only thing that escapes
the scope, any information needed for error handling should be copied to the
thrown object as it is being thrown.

## `hal::exception` hierarchy

libhal has a hierarchy of errors, which looks like the following:

```plaintext
hal::exception
├── hal::no_such_device
│   └── hal::stm32f1::i2c_core_dump_io_error
├── hal::io_error
│   └── hal::lpc40::i2c_core_dump_io_error
├── hal::timed_out
├── ...
└── hal::unknown
```

`hal::exception` is the base exception for all libhal exceptions and is
typically not thrown directly. Its descendants are thrown instead, most having
a 1-to-1 correspondence with the enumerated constants in `std::errc`.
`std::errc` follows the POSIX error codes, providing a reasonable approximation
of the types of errors hardware might encounter. An exception to this rule is
`hal::unknown`, which represents an unknown error, used when the exact error is
undetermined. Such cases should be rare in code.

To see the full list of exception types available, refer to
the [error API docs](https://libhal.github.io/3.0/api/libhal/error.html#error).
It is important to consult this documentation to understand which exceptions
should be thrown and under what circumstances they can be recovered from.

## Expectation from libhal libraries

libhal libraries and utilities are required to only use only the direct
descendants of `hal::exception` or a more derived exception with additional
information.

Exceptions outside of the `hal::exception` hierarchy may still be thrown from a libhal library if it comes from a call to a user defined callback. The user is allowed to throw any types they wish, although care should be taken in choosing the types to be thrown. This is useful for application code that wants to bypass
catch blocks provided by libhal libraries.

## How Do You Know What Throws What?

C++ does not currently have a mechanism to inform the user at compile time if
an uncaught exception will terminate your application. Therefore, to know what
may be thrown from a function, you'll need to consult the API documentation
for the function. All libhal interfaces have strict requirements for their
implementations to throw very specific `hal::exception` derived types.

## Knowing when to catch an error

First and foremost, accept that your application may encounter an exception
that will terminate it. Plan with this possibility in mind. Use
hal::set_exception to set the terminate handler function as needed for your
application, such as saving state information and resetting the device.

With this in mind, ONLY catch the errors you know how to handle. If you do not
know how to handle an error, allow it to propagate to higher levels in the
call chain. This gives higher-level code the opportunity to handle errors.

Do not encase each function in a try/catch block, as this is detrimental to
code size and degrades the performance of the unwind mechanism by providing it
more scopes to search through.

## When to catch `hal::exception`

`hal::exception` should only be caught when code wants to swallow all possible
exceptions from libhal OR when translating exceptions from C++ to a C API that
needs an error code that roughly follows `std::errc`.

```C++
int c_callback() {
  try {
    foo();
    bar();
    baz();
  } catch (const hal::exception& p_error) {
    return static_cast<int>(p_error.error_code());
  }
}
```

## Using `hal::exception::instance()`

```C++
try {
  read_timeout();
  bandwidth_timeout();
} catch (const hal::timed_out& p_exception) {
  if (&read_timeout == p_exception.instance()) {
    hal::print(console, "X");
    read_complete = true;
  }
  // TODO: Replace this exceptional bandwidth timeout with a variant that
  // simply returns if the timeout has occurred. This is not its intended
  // purpose but does demonstrates proper usage of `p_exception.instance()`.
  else if (&bandwidth_timeout == p_exception.instance()) {
    hal::print(console, "\n   +  |");
    bandwidth_timeout = hal::create_timeout(counter, graph_cutoff);
  } else {
    throw;
  }
}
```

In this case, `read_timeout` and `bandwidth_timeout` are callable objects that
live in a scope above the try block allowing them to be modified and updated in
the error handling block. Because both of these objects can throw an exception, we may want to know which one throw the exception. We can use the `instance()` function to get the address of the object that threw an exception. If the instance does not match anything in scope, then it may have been from an object that was lower in the stack and is no longer valid.

Note the comment or `bandwidth_timeout`. `bandwidth_timeout` is apart of the normal control flow and should not be reporting errors to move along the normal control flow. `read_timeout` on the other hand does report an actual error in this context. This example is taken from `libhal-esp8266/demos/applications/at_benchmark.cpp`.

!!! caution

    DO NOT USE `const_cast` and `reinterpret_cast` to FORCE an address from `instance()` into a pointer to some other type and then attempt to use it. This is strong undefined behavior. ONLY use the address returned from instance as a means to compare it to other objects.

## Why you shouldn't throw an `int` or other primitives

Application callbacks are allowed to throw whatever type they wish although
care should be taken to consider a good type to throw.

Throwing `int` is generally a bad choice because it gives little to no
information about what the kind of error is. And if such a choice was used, it
probably means that the int encodes an error code, meaning many sections of
code would need to catch it, check if its their error code, and rethrow it, if
it is not the correct error code. This resulting in a large number of catch blocks.
