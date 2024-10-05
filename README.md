<div align="center">

# NVim-Smuggler

*Well, listen up, folks! [`REPLSmuggler.jl`](https://github.com/klafyvel/REPLSmuggler.jl) just slipped into your cozy REPL like a shadow in the night.*

[Demo](#Demo) | [Features](#Features) | [Installation](#Installation) | [Configuration](#Configuration) | [Documentation](#Documentation) | [Acknowledgements](#Acknowledgements) | [License](#License) | [![LuaRocks](https://img.shields.io/luarocks/v/Klafyvel/nvim-smuggler?logo=lua&color=purple)](https://luarocks.org/modules/Klafyvel/nvim-smuggler)
</div>

Neo-Vim companion plugin for [REPLSmuggler.jl](https://github.com/klafyvel/REPLSmuggler.jl). Send code to your Julia REPL, and get Neo-Vim diagnostics in return.

> [!WARNING]
> NeoVim 0.10 or later is required.


## Demo

[![asciicast](https://asciinema.org/a/W6RTJeVzRL3SvUIHfuauLGDF7.svg)](https://asciinema.org/a/W6RTJeVzRL3SvUIHfuauLGDF7)

## Installation

Using rocks.nvim:
```
:Rocks install nvim-smuggler
```

Using Lazy:

```lua
return {
  "klafyvel/nvim-smuggler",
  config=true,
  dependencies = { "nvim-neotest/nvim-nio" },
}
```
    
## Configuration and Documentation

See [`:help smuggler`](https://github.com/klafyvel/nvim-smuggler/blob/main/doc/smuggler.txt).


## Acknowledgements

 - [vim-slime](https://github.com/jpalardy/vim-slime) by jpalardy inspired the design for sending code to the REPL from a buffer,
 - [nvim-nio](https://github.com/nvim-neotest/nvim-nio) is used for all asynchronous stuff in the plugin.


## License

NVim-Smuggler is available under the [MIT](https://choosealicense.com/licenses/mit/) license.


