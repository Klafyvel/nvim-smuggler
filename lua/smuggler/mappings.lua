-- Default mappings for nvim-smuggler
return {
	smuggle = {
		mode = "n",
		key = "<leader>cs",
		command = "<Cmd>Smuggle<cr>",
		opts = {
			desc = "Send <count> lines to the REPL.",
		},
	},
	smuggle_range = {
		mode = "v",
		key = "<leader>cs",
		command = "<Cmd>SmuggleRange<cr>",
		opts = {
			desc = "Send <range> to the REPL.",
		},
	},
	smuggle_config = {
		mode = "n",
		key = "<leader>ce",
		command = "<Cmd>SmuggleConfig<cr>",
		opts = {
			desc = "(Re)configure the current buffer for smuggling.",
		},
	},
	smuggle_operator = {
		mode = "n",
		key = "gcs",
		command = "<Cmd>set opfunc=v:lua.require'smuggler'.send_op<cr>g@",
		opts = {
			desc = "Send code to the REPL using a vim operator.",
		},
	},
}
