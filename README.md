# lua-prefix_tree


```Lua
local tree = prefix_tree.new()

tree:add_list('43 710, 711, 730, 740, 810, 820', 'Austria Special services')
tree:add_list('47 0, 1, 810, 811, 812, 813, 814, 815, 85, 880', 'Norway mob. special services')

tree:find('4781303760056') -- -> 'Norway mob. special services', '47813', true
```