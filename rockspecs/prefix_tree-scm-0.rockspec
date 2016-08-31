package = "prefix_tree"
version = "scm-0"
source = {
  url = "https://github.com/moteus/lua-prefix_tree/archive/master.zip",
  dir = "lua-prefix_tree-master",
}

description = {
  summary = "Prefix tree which allows find longes prefix for some string",
  homepage = "https://github.com/moteus/lua-prefix_tree",
  license  = "MIT/X11",
}

dependencies = {
  "lua >= 5.1, <5.4",
  "lpeg",
}

build = {
  type = "builtin",
  copy_directories = {"test"},

  modules = {
    ["prefix_tree"        ] = "src/prefix_tree.lua",
    ["prefix_tree.tree"   ] = "src/prefix_tree/tree.lua",
    ["prefix_tree.list"   ] = "src/prefix_tree/list.lua",
    ["prefix_tree.utils"  ] = "src/prefix_tree/utils.lua",
  }
}
