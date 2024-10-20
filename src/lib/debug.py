"""
This is a simple decorator that can be used to print debug statements when a function is called and when it returns a value.

The @debug decorator is a simple example of how to use the functools.wraps decorator to preserve the function's
name, docstring, and other attributes.

The @debug decorator can be applied to any function, and it will print a debug statement when the function is called,
with the arguments and keyword arguments passed to the function. It will also print a debug statement when the function
returns a value.

Example usage:

@debug
def my_function(x, y):
    return x + y

result = my_function(1, 2)

This will print the following to the console:

Calling my_function(1, y=2)
my_function returned 3

Note that the @debug decorator can be used on functions that already have other decorators applied to them.
"""

import functools


def debug(func):
    """This is a decorator that can be used to print debug statements when a function is called and when it returns a value."""

    @functools.wraps(func)
    def wrapper_debug(*args, **kwargs):
        """
        This is a wrapper function that is returned by the @debug decorator. It wraps the original function passed to
        the @debug decorator, and it prints debug statements when the function is called and when it returns a value.
        """
        args_repr = [repr(a) for a in args]
        kwargs_repr = [f"{k}={v!r}" for k, v in kwargs.items()]
        signature = ", ".join(args_repr + kwargs_repr)
        print(f"Calling {func.__name__}({signature})")
        value = func(*args, **kwargs)
        print(f"{func.__name__!r} returned {value!r}")
        return value

    return wrapper_debug
