local tree = require "prefix_tree.tree"
local list = require "prefix_tree.list"
local ut   = require "prefix_tree.utils"

local function LoadPrefixFromFile_impl(FileName_or_file, functor, pack_range)
  local file, do_close
  if type(FileName_or_file) == 'string' then
    file = assert(io.open(FileName_or_file,'r'),'Can not open file "' .. FileName_or_file .. '"!')
    do_close = true
  else
    file = assert(FileName_or_file)
  end

  local line_no = 0
  ut.try(function()
    for str in file:lines() do
      line_no = line_no + 1
      local prefixes, value = ut.split_first(str, '\t', true)
      if not list.decode(functor, pack_range, prefixes, value or '') then
        error("Error prefix at line " .. line_no .. ": " .. (prefixes or '<EMPTY>'))
      end
    end
    if do_close then file:close() end
  end,
  function(e) --catch
    if do_close then file:close() end
    error(e)
  end)
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
  self.char_set       = char_set or tree.default_char_set;

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
function tree_index:add_list( str, val, ret_list, pack )
  local t = ret_list and {}

  if pack then
    if type(pack) ~= 'function' then
      pack = list.pack_range
    end
  end

  local n = list.decode(function(prefix, value)
    self:add(prefix, value)
    if ret_list then t[#t+1] = prefix end
  end, pack, str, val)

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

  local t = {data = data}
  for k, v in pairs(self) do
    if t[k] == nil then t[k] = v end
  end

  return t
end

function tree_index:transform(func)
  tree.transform(self._data, func)
  return self
end

function tree_index:clear()
  self._data = {}
end

---
--
function tree_index:keys()
  local t = {}
  self:for_each(function(prefix)
    t[t + 1] = prefix
  end)
  return t
end

---
-- возвращает множество ключей
function tree_index:key_set(val)
  if val == nil then val = true end
  local t = {}
  self:for_each(function(prefix)
    t[prefix] = val
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

---
--
function tree_index:set_values(t)
  self:clear()
  for prefix,value in pairs(t)do
    self:add(prefix,value)
  end
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
function tree_index:load(FileName, pack_range, ret_list)
  local add_prefix, prefix_list_t

  if ret_list then
    prefix_list_t = {}
    add_prefix = function(prefix, value, list)
      self:add(prefix,value)
      prefix_list_t[prefix] = list
    end
  else
    add_prefix = function(prefix, value)self:add(prefix,value)end
  end

  LoadPrefixFromFile_impl(FileName, add_prefix, pack_range)

  return prefix_list_t or true
end


---
-- serialize
function tree_index:serialize(packer)
  return packer{
    data           = self._data;
    invalid_value  = self._invalid_value;
    char_set       = self.char_set;
  }
end

---
-- deserialize
function tree_index:deserialize(unpacker, str)
  local t = unpacker(str)
  if not(t.data and t.char_set) then
    return nil, "invalid format"
  end

  return setmetatable({
    data           = t.data;
    invalid_value  = t.invalid_value;
    char_set       = t.char_set;
  }, tree_index_mt)
end

end

local function LoadPrefixFromFile(...)
  local tree          = tree_index:new()
  local prefix_list_t = tree:load(...)
  return tree, prefix_list_t
end

return {
  new                      = tree_index.new;
  LoadPrefixFromFile       = LoadPrefixFromFile;
  INVALID_VALUE_ALWAYS_NIL = tree.INVALID_VALUE_ALWAYS_NIL;
  pack_range               = list.pack_range;
}
