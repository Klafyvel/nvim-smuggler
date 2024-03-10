<div align="center">

# NVim-Smuggler

*Well, listen up, folks! [`REPLSmuggler.jl`](https://github.com/klafyvel/REPLSmuggler.jl) just slipped into your cozy REPL like a shadow in the night.*

[Demo](#Demo) | [Features](#Features) | [Installation](#Installation) | [Configuration](#Configuration) | [Documentation](#Documentation) | [Acknowledgements](#Acknowledgements) | [License](#License)
</div>

Neo-Vim companion plugin for [REPLSmuggler.jl](https://github.com/klafyvel/REPLSmuggler.jl). Send code to your Julia REPL, and get Neo-Vim diagnostics in return.


## Demo

[![asciicast](https://asciinema.org/a/W6RTJeVzRL3SvUIHfuauLGDF7.svg)](https://asciinema.org/a/W6RTJeVzRL3SvUIHfuauLGDF7)

## Features

- [x]  Send text to Julia REPL
- [x]  Auto-detection of available REPL
- [x]  Send multiple lines
- [x]  Send range
- [x]  Send text objects
- [ ]  Dynamic choice of module for execution


## Installation

Using Lazy:

```lua
return {
  "klafyvel/nvim-smuggler",
  config=true,
  dependencies = { "nvim-neotest/nvim-nio" },
}
```
    
## Configuration

Using Lazy, you can set the following options (here given with their default values):
```lua
{
  "klafyvel/nvim-smuggler",
  opts = {
      mappings = true, -- set to false to disable all mappings.
      map_smuggle = "<leader>cs", -- Use `[count]<leader>cs` in normal mode to send count lines.
      map_smuggle_range = "<leader>cs", -- Use `<leader>cs` in visual mode to send the current selection.
      map_smuggle_config = "<leader>ce", -- Use `<leader>ce` in normal mode to reconfigure the plugin.
      map_smuggle_operator = "gcs", -- Use `gcs[text object]` to send a text object in normal mode.
  },
  dependencies = { "nvim-neotest/nvim-nio" },
}
```
## Documentation

See [`:help smuggler`](https://github.com/klafyvel/nvim-smuggler/blob/main/doc/smuggler.txt).


## Acknowledgements

 - [vim-slime](https://github.com/jpalardy/vim-slime) by jpalardy inspired the design for sending code to the REPL from a buffer,
 - [nvim-nio](https://github.com/nvim-neotest/nvim-nio) is used for all asynchronous stuff in the plugin.


## License

NVim-Smuggler is available under the [MIT](https://choosealicense.com/licenses/mit/) license.


