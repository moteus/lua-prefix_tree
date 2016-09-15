local tree = require "prefix_tree.tree"
local list = require "prefix_tree.list"
local ut   = require "prefix_tree.utils"

local _COPYRIGHT = "Copyright (C) 2016 Alexey Melnichuk";
local _VERSION   = '0.1.0'
local _NAME      = 'prefix_tree'

local function decode_file_list(FileName_or_file, functor, pack_range)
  local file, do_close, err
  if type(FileName_or_file) == 'string' then
    do_close, file, err = true, io.open(FileName_or_file,'r')
    if not file then return nil, err end
  else
    file = assert(FileName_or_file)
  end

  local prefix_count, line_no = 0, 0
  for str in file:lines() do
    line_no = line_no + 1
    local prefixes, value = ut.split_first(str, '\t', true)
    local count = list.decode(functor, pack_range, prefixes, value or '')
    if not count then
      err = "Error prefix at line " .. line_no .. ": `" .. (prefixes or '') .. "`"
      break
    end
    prefix_count = prefix_count + count
  end

  if do_close then file:close() end

  if err then return nil, err end

  return prefix_count
end

---
-- Индексированный поиск по префиксам
-- при вводе полного слова осуществляется поиск значения соответствующий 
-- сомому длинному префиксу
--
local tree_index = ut.class() do

---
-- ctor
function tree_index:__init(invalid_value, char_set)
  self._data           = {}
  self._invalid_value  = invalid_value or {}
  self._char_set       = char_set or tree.default_char_set;

  return self
end

---
-- Добавление префикса и значения
-- существующее значение перезаписывается
-- flag - true - значение для префикса
--      - false - префикс это не префикс а полная строка
function tree_index:add( key, val, flag )
  tree.add(self._data, key, val, flag)

  return self
end

--- Добавляет несколько префиксов
-- ret_list - true - вернуть список добаленных префиксов
-- pack - true сжимать диапазоны  во время загрузки
function tree_index:add_list( str, value, pack, ret_list )
  local t = ret_list and {}

  if pack then
    if type(pack) ~= 'function' then
      pack = list.pack_range
    end
  end

  local n = list.decode(function(prefix)
    self:add(prefix, value)
    if ret_list then t[#t+1] = prefix end
  end, pack, str)

  if not n then return false end

  return t or n
end

---
-- Поиск значения на совпадение самого длинного ключа
-- use_false - по умолчанию включен
--     если у префикса есть 2 значения.
--     брать второе если ключ полностью соответствует префиксу
--     и первое если ключ длиннее префикса.
--     при use_false = false всегда берется только первое значение
-- return value, prefix, flag
function tree_index:find( key , use_false )
  local value, real_key, flag = tree.find(self._data, key , use_false)

  if (value == nil) or (value == self._invalid_value) then
    return nil
  end

  return value, real_key, flag
end

---
-- Удаление значения
function tree_index:del( key )
  return tree.remove(self._data, key)
end

---
-- Итератор
function tree_index:for_each( func )
  tree.for_each(self._data, func)
  return self
end

function tree_index:for_each_sort( char_set_or_func, func_or_nil )
  tree.for_each_sort(self._data, char_set_or_func, func_or_nil)
  return self
end

---
-- Минимизирует префиксное поле
function tree_index:pack(allow_create_prefix, compare_value, char_set)
  tree.pack(
    self._data,
    allow_create_prefix,
    self._invalid_value,
    compare_value,
    char_set
  )
  return self
end

---
-- возаращает часть дерева
-- копирования не происходит
function tree_index:sub_tree( key )
  local data = tree.sub_tree(self._data, key)
  if not data then return end

  t = tree_index.new(
    self._invalid_value, self._char_set
  )
  t._data = data

  return t
end

--- Преобразует значения для префиксов
-- 
function tree_index:transform(func)
  tree.transform(self._data, func)
  return self
end

function tree_index:clear()
  self._data = {}
  return self
end

---
--
function tree_index:keys()
  local t = {}
  self:for_each(function(prefix)
    t[#t + 1] = prefix
  end)
  return t
end

---
--
function tree_index:values()
  local t = {}
  self:for_each(function(prefix,val)
    t[prefix] = val
  end)
  return t
end

--- Проверяет существует ли такой префикс
--
function tree_index:exists( key )
  local _, pfx = self:find(key)
  return pfx == key
end

---
-- расширяет по возможности набор ключей до 
-- указоного списка
-- @param clone = функция для клонирования значения
--
function tree_index:expand( keys, clone )
  if clone then
    for _,newkey in ipairs(keys) do
      local val, key = self:find(newkey)
      if val and (newkey ~= key) then
        self:add(newkey, clone(val))
      end
    end
  else
    for _,newkey in ipairs(keys) do
      local val, key = self:find(newkey)
      if val and (newkey ~= key) then
        self:add(newkey, val)
      end
    end
  end
end

---
-- fn   pack_range - функция для сжатия диапазонов 
-- bool ret_list   - возвращать список префикс => строка из которой он сформирован
--
function tree_index:load_file(FileName, pack_range, ret_list)
  local add_prefix, prefix_list_t

  if ret_list then
    prefix_list_t = {}
    add_prefix = function(prefix, str, value)
      self:add(prefix, value)
      prefix_list_t[prefix] = str
    end
  else
    add_prefix = function(prefix, _, value) self:add(prefix, value) end
  end

  local n, err = decode_file_list(FileName, add_prefix, pack_range)

  if not n then return nil, err end
  
  return prefix_list_t or n
end

---
-- serialize
function tree_index:serialize(packer)
  return packer{
    data           = self._data;
    invalid_value  = self._invalid_value;
    char_set       = self._char_set;
  }
end

---
-- deserialize
function tree_index:deserialize(unpacker, str)
  local t = unpacker(str)
  if not(t.data and t.char_set) then
    return nil, "invalid format"
  end

  local o = tree_index.new(t.invalid_value, t.char_set)
  o._data = t.data

  return o
end

end

local function LoadPrefixFromFile(...)
  local tree          = tree_index:new()
  local prefix_list_t = assert(tree:load_file(...))
  return tree, prefix_list_t
end

local function self_test()
  tree.__self_test()
  list.__self_test()
end

return {
  _NAME                    = _NAME;
  _VERSION                 = _VERSION;
  _COPYRIGHT               = _COPYRIGHT;

  __self_test              = self_test;
  new                      = tree_index.new;
  LoadPrefixFromFile       = LoadPrefixFromFile;
  INVALID_VALUE_ALWAYS_NIL = tree.INVALID_VALUE_ALWAYS_NIL;
  pack_range               = list.pack_range;
}
