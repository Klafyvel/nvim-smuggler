# Code formatting

Code should be formatted following [StyLua](https://github.com/JohnnyMorganz/StyLua), this is enforced through the CI. Be aware that some of the `goto` statements in the code are problematic for some builds of `stylua` (see [here](https://github.com/JohnnyMorganz/StyLua/issues/407)), so it is recommended to install `stylua` using cargo.

You can use the following `.git/hooks/pre-commit`: 

```bash
#!/usr/bin/env bash

# Redirect output to stderr.
exec 1>&2

git diff-index -z --name-only --diff-filter=AM main | \
    grep -z '\.lua$' | \
    xargs -0 --no-run-if-empty stylua --check
```
