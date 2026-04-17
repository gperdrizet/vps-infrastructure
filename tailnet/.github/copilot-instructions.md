# Project guidelines

## Code style

- Use sentence case for all headings, section titles, list items, and labels.
- Do not use em dashes or emojis in code, comments, or documentation.
- In Python, prefer single quotes for all strings unless the string itself contains a single quote.
- Add detailed docstrings to every function, class, and module.
- Write inline comments to explain intent, not mechanics.
- Add a blank line between logical blocks of code, including between conditional clauses, loops, and function calls.

## Python conventions

```python
def example_function(value: int) -> str:
    '''Convert an integer to its string representation.

    Args:
        value: The integer to convert.

    Returns:
        The string form of the integer.
    '''
    if value < 0:
        return f'negative {abs(value)}'

    elif value == 0:
        return 'zero'

    else:
        return str(value)
```

## Architecture

TODO: Describe major components and service boundaries here.

## Build and test

TODO: Add install, build, and test commands here so the agent can run them automatically.

## Conventions

TODO: Note patterns that differ from common practices, with examples.
