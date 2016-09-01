package.path = "..\\src\\?.lua;" .. package.path

pcall(require, "luacov")

local utils       = require "utils"
local TEST_CASE   = require "lunit".TEST_CASE
local RUN, IT = utils.RUN, utils.IT

local print, require, ipairs, tonumber, tostring = print, require, ipairs, tonumber, tostring

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

it('should decode append range', function()
  tree:add_list('7 495-499', 'allow')

  assert_nil  (         tree:find('74941'))
  assert_equal('allow', tree:find('74951'))
  assert_equal('allow', tree:find('74961'))
  assert_equal('allow', tree:find('74971'))
  assert_equal('allow', tree:find('74981'))
  assert_equal('allow', tree:find('74991'))
end)

it('should decode prefix range', function()
  tree:add_list('7495-7499', 'allow')

  assert_nil  (         tree:find('74941'))
  assert_equal('allow', tree:find('74951'))
  assert_equal('allow', tree:find('74961'))
  assert_equal('allow', tree:find('74971'))
  assert_equal('allow', tree:find('74981'))
  assert_equal('allow', tree:find('74991'))
end)

it('should decode multi lists', function()
  tree:add_list('7 495-499; 7 9 10-19', 'allow')

  assert_true (tree:exists('7495'))
  assert_true (tree:exists('7919'))
  assert_false(tree:exists('74997'))
end)

it('should create all prefixes', function()
  tree:add_list('7 49500-49599', 'allow')
  tree:add_list('749900-749999', 'allow')

  assert_false (tree:exists('7495'))
  assert_false (tree:exists('7499'))
  assert_true  (tree:exists('749500'))
  assert_true  (tree:exists('749555'))
  assert_true  (tree:exists('749599'))
  assert_true  (tree:exists('749900'))
  assert_true  (tree:exists('749955'))
  assert_true  (tree:exists('749999'))
end)

it('should reduce number of prefixes', function()
  tree:add_list('7 49500-49599', 'allow', true)
  tree:add_list('749900-749999', 'allow', true)

  assert_true  (tree:exists('7495'))
  assert_true  (tree:exists('7499'))
  assert_false (tree:exists('749500'))
  assert_false (tree:exists('749555'))
  assert_false (tree:exists('749599'))
  assert_false (tree:exists('749900'))
  assert_false (tree:exists('749955'))
  assert_false (tree:exists('749999'))
end)

it('should preserve leading zeros', function()
  tree:add_list('7 09500-09599', 'allow', true)
  tree:add_list('7 09900-09999', 'allow')
  tree:add_list('0 09900-09999', 'allow')
  tree:add_list('005500-005599', 'allow')

  assert_true  (tree:exists('7095'))
  assert_true  (tree:exists('709900'))
  assert_true  (tree:exists('009900'))
  assert_true  (tree:exists('005500'))
end)

it('should returns prefixes', function()
  local p1 = assert_table(tree:add_list('7 49500-49599', 'allow', false, true))
  local p2 = assert_table(tree:add_list('749900-749999', 'allow', false, true))

  local set = {}
  assert_equal(100, #p1)
  for _, prefix in ipairs(p1) do
    assert(tonumber(prefix) >= 749500 and tonumber(prefix) <= 749599, prefix)
    assert_nil(set[prefix])set[prefix] = true
  end

  local set = {}
  assert_equal(100, #p2)
  for _, prefix in ipairs(p2) do
    assert(tonumber(prefix) >= 749900 and tonumber(prefix) <= 749999, prefix)
    assert_nil(set[prefix], prefix)set[prefix] = true
  end
end)

it('should returns packed prefixes', function()
  local p1 = assert_table(tree:add_list('7 49500-49599', 'allow', true, true))
  local p2 = assert_table(tree:add_list('749900-749999', 'allow', true, true))

  local set = {}
  assert_equal(1, #p1)
  for _, prefix in ipairs(p1) do
    assert(tonumber(prefix) >= 7495 and tonumber(prefix) <= 7495, prefix)
    assert_nil(set[prefix])set[prefix] = true
  end

  local set = {}
  assert_equal(1, #p2)
  for _, prefix in ipairs(p2) do
    assert(tonumber(prefix) >= 7499 and tonumber(prefix) <= 7499, prefix)
    assert_nil(set[prefix], prefix)set[prefix] = true
  end
end)

end

local _ENV = TEST_CASE'prefix_tree.API' if ENABLE then
local it = IT(_ENV)

local tree

function setup()
  tree = ptree.new()
end

it('should not clone empty subtree', function()
  local s = assert_nil(tree:sub_tree('123'))
end)

it('should clone subtree', function()
  tree:add_list('12 0-5')
  local s = assert_table(tree:sub_tree('123'))
  assert_function(s.add)
  assert_function(s.find)
end)

it('should check exists only full prefix', function()
  tree:add_list('12 0-5', 'allow')
  local s = assert_table(tree:sub_tree('123'))
  assert_equal('allow', tree:find('123456'))
  assert_false(tree:exists('123456'))
  assert_true(tree:exists('123'))
end)

end

RUN()
