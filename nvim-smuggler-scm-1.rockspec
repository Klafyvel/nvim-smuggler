rockspec_format = '3.0'
package = 'nvim-smuggler'
version = 'scm-1'

dependencies = {
  'lua >= 5.1',
  'nvim-nio',
}

test_dependencies = {
  'nlua',
  'pathlib.nvim',
}

source = {
  url = 'git://github.com/klafyvel/' .. package,
}

build = {
  type = 'builtin',
}
