package.path = "..\\src\\?.lua;" .. package.path

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

local _ENV = TEST_CASE'prefix_tree.decode_list' if ENABLE then
local it = IT(_ENV)

local tree

function setup()
  tree = ptree.new()
end

it('should decode', function()
  tree:add_list('7 495-499', 'allow')

  assert_nil  (         tree:find('74941'))
  assert_equal('allow', tree:find('74951'))
  assert_equal('allow', tree:find('74961'))
  assert_equal('allow', tree:find('74971'))
  assert_equal('allow', tree:find('74981'))
  assert_equal('allow', tree:find('74991'))
end)

end

RUN()
