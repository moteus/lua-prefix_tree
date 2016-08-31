package.path = "..\\src\\lua\\?.lua;" .. package.path

pcall(require, "luacov")

local utils       = require "utils"
local TEST_CASE   = require "lunit".TEST_CASE
local RUN, IT = utils.RUN, utils.IT

local print, require = print, require

local ptree = require "prefix_tree"

print("------------------------------------")
print("Module    name: " .. ptree._NAME);
print("Module version: " .. ptree._VERSION);
print("Lua    version: " .. (_G.jit and _G.jit.version or _G._VERSION))
print("------------------------------------")
print("")

local ENABLE = true

local _ENV = TEST_CASE'prefix_tree.self_test' if ENABLE then
local it = IT(_ENV)

it('should pass self test', function()
  ptree.__self_test()
end)

end

RUN()