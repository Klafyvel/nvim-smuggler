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

## Features

- [x]  Send text to Julia REPL
- [x]  Auto-detection of available REPL
- [x]  Send multiple lines
- [x]  Send range
- [x]  Send text objects
- [ ]  Dynamic choice of module for execution


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
    
## Configuration

The plugin is initialized through its `setup` function, which takes a table as
its sole argument. The options are the following (given with their default
values): 
```lua
  {
    ui = {
        mappings = { -- set to false to disable all mappings.
          smuggle = "<leader>cs", -- Mapping for Smuggle in normal mode.
          smuggle_range = "<leader>cs", -- For SmuggleRange in visual mode.
          smuggle_config = "<leader>ce", -- SmuggleConfig in normal mode.
          smuggle_operator = "gcs", -- SmuggleOperator in normal mode.
        },
        evaluated_hl = "MoreMsg", -- highlight group for evaluated chunks.
        invalidated_hl = "WarningMsg", -- highlight group for invalidated evaluated chunks.
        result_line_length = 80, -- line length of displayed results.
        result_hl_group = "DiagnosticVirtualTextInfo", -- highlight group used for results.
        display_results = true, -- Display evaluation results.
        display_images = true, -- Display images if `images.nvim` is present.
        images_height = 10, -- Number of lines an image should occupy.
        eval_sign_text = "│", -- Symbol in signcolumn to mark evaluated/invalidated.
        show_eval = true, -- If set to false, do not attempt to track modifications in evaluated code chunks.
    },
    log = {
        level = "warn", -- available: trace, debug, info, warn, error, fatal
        use_file = false, -- output logs to `stdpath("data")/smuggler.log`, e.g. `~/.local/share/nvim/smuggler.log `
        use_console = true, -- output logs to the console.
    },
    buffers = {
        eval_by_blocks = false, -- Configure each new session eval by block attribute.
        autoselect_single_socket=true, -- When true, skip socket selection dialog if there's only one choice possible.
        showdir = vim.fs.dirname(vim.fn.tempname()),
        iocontext = { -- Julia's IOContext
        -- (https://docs.julialang.org/en/v1/base/io-network/#Base.IOContext-Tuple%7BIO,%20Pair%7D)
        -- options to use.
            compact = true,
            limit = true,
            displaysize = {10, 80},
        },
    },
  }
```

If you use the `rocks.nvim` package manager, you can use the
[`rocks-config.nvim`](https://github.com/nvim-neorocks/rocks-config.nvim) package to call `setup` in
`.config/nvim/lua/plugins/smuggler.lua`: 
```lua
  require('smuggler').setup({ ... })
```

If you use the `lazy.nvim` package manager, you can provide the configuration
directly with the installation: 
```lua
  {
    "klafyvel/nvim-smuggler",
    opts = {
        ...
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


