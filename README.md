# lua-prefix_tree

```Lua
local tree = prefix_tree.new()

tree:add_list('43 7-8 10, 11',             'Austria Special services'    )
tree:add_list('43 7 30, 40',               'Austria Special services'    )
tree:add_list('47 0, 1, 810-815, 85, 880', 'Norway mob. special services')

tree:find('4371003760056') -- -> 'Austria Special services',     '43710', true
tree:find('4373003760056') -- -> 'Austria Special services',     '43730', true
tree:find('4381103760056') -- -> 'Austria Special services',     '43811', true
tree:find('4781303760056') -- -> 'Norway mob. special services', '47813', true
```