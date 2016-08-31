------------------------------------------------
-- Общие функции для работы с деревом         --
------------------------------------------------

local default_compare = function(lhs, rhs) return lhs == rhs end;
local default_char_set = {'0','1','2','3','4','5','6','7','8','9'};
local INVALID_VALUE_ALWAYS_NIL = {}

--Удаляет все пустые ветви в дереве
local function pack_empty (t)
  for k,v in pairs(t) do
    if type(k) ~= 'boolean' then
      if not pack_empty(v) then
        t[k] = nil
      end
    end
  end
  if next(t) ~= nil then
    return true
  end
end

-- Поглащение длинных префиксов более короткими
local function pack_dup(t, compare_value)
  compare_value = compare_value or default_compare

  local function do_work(t, v, val_prefix, prefix)
    prefix     = prefix or ''
    val_prefix = val_prefix or ''

    if t[true] ~= nil then
      if compare_value(v, t[true], val_prefix, prefix) then
        t[true] = nil
      else
        v = t[true]
        val_prefix = prefix
      end
    end

    for k,r in pairs(t) do
      if type(k) ~= 'boolean' then
        do_work(r, v, val_prefix, prefix .. k)
      end
    end
  end

  do_work(t)

  return t
end

-- "Сворачивает" ветки поддерева создавая более оптимальное префиксное поле
--[[
  Если есть следующие префиксы : 1[0..8] с одинаковыми значениями то их 
  возможно заменить на один префикс: 1, но при этом необходимо создать префикс 19.
  Значение этого префикса должно быть либо значением префикса 1(если он существовал до сворачивания)
  либо принемать невалидное значение. При этом если невалидное значение отсутствует, то свертка 
  оказывается невозможной. Так же необходимо учитывать что значение для строки `1` после сворачивания
  изменится. Такая замена имеет смысл если результирующее число префиксов будет меньше и если 
  существует возможность создания невалидных значений.
  При этом предпологается что дерево не содержит дубликатов.(1->a; 11->a)
@param invalid_value 
  невалидное значение 
  если оно равно INVALID_VALUE_ALWAYS_NIL, то это приведет к запрету переноса значения с короткого префикса 
    на длинный. Например, если рассмотреть предыдущий пример, и предположить что префикс 1 имеет 
    некоторое значение, то в случае установки этого значения сворачивание будет невозможно. Это предотвращает
    создание ошибочных ситуаций когда номер равный короткому префиксу(1) до сворачивания имел одно значение,
    а после сворачивания другой
@param compare_value
  функция сравнения двух значенй. По умолчанию применяется operator==
@param char_set
  полное множество значений узлов если у узла есть подчиненные узлы которые покрывают это множество
  и эти узлы имеют одинаковое значение то это значение можно перенести на этот узел.
  По умолчанию цыфры от 0 до 9

@note
  Следует учитывать следующие эффект
  Если есть префиксы : 1[0..9] с одинаковыми значениями, то номеру '1' не соответствует ни одно значение.
  После сворачивания в префикс 1 этот номер принимает действительное значение.
  Тот же вариант если есть префикс 1 с одним значениеим и префиксы 11[0..9] с другим, то до свертки номеру 11 соответствует
  значение префикса 1, а после свертки значение префикса 11.
  В таком случае создается еще одно значение [false] которое соответствует старому значению для этого номера.
  Это относится к номеру равному префиксу к которому производится свертка. Свертка может быть произведена если 
  этот номер не является верным.
--]]
local function pack_roll(t, invalid_value, compare_value, char_set)
  compare_value = compare_value or default_compare
  char_set      = char_set or default_char_set

  local do_work 
  do_work = function(t, prfx, val, upval)
    for k,v in pairs(t) do
      if type(k) ~= 'boolean' then
        do_work(v, (prfx or '') .. k, v[true] or val, val)
      end
    end

    if prfx == nil then return  end

    -- таблица для подсчета количества узлов для разных значений
    local node  = {}

    -- в node заносим количество префиксов для каждого значения
    for _, key in ipairs(char_set) do repeat
      local value = t[key] and t[key][true]
      if value == nil then
        break --continue
      end

      local flag = false
      for i in pairs(node)do
        if compare_value(value, i) then
          node[i], flag = node[i] + 1, true
          break
        end
      end

      -- Нет такого значения в node
      if not flag then node[value] = 1 end

    until true end

    -- Находим значение с максимальным числом повторений
    -- total - общее количество префиков в узле
    local total_, max_val = 0
    for i,j in pairs(node)do
      total_ = total_ + j
      if max_val == nil then
        max_val = i
      elseif node[max_val] < j then
        max_val = i
      end
    end

    -- Это означает что ни один подпрефикс не имеет значения и все
    -- подпрефиксы пустые. Это может быть `лист` или например в дереве 
    -- для префиксов 11[0..1] префикс `1` - пустой
    if not max_val then return nil end

    -- Предотвращает создание длинных префиксов
    if invalid_value == INVALID_VALUE_ALWAYS_NIL then 
      val = nil
    end

    -- Кол-во префиксов которое можно удалить
    local remove_pfx_count = node[max_val]

    -- 1 -> a
    -- 12 -> b
    -- 12[0..4] -> a
    -----------------
    -- для префикса `12` если выбрать сжатие кол-во удаляемых префиксов равно 6
    -- т.к. после замены 12->a; 12[5-9]->b; префикс `12` тоже можно удалить и результат будет
    -- 1 -> a
    -- 12[5..9] -> b
    -----------------
    if (upval ~= nil) and (upval == max_val) and t[true] then
      remove_pfx_count = remove_pfx_count + 1
    end

    --кол-во новых префиксов
    local new_pfx_count = #char_set - total_
    assert(new_pfx_count >= 0)

    -- если нет 'верхнего' значения то можно сворачивать только целиком.
    -- например есть префиксы 1[0..9]->aaa то их можно свернуть в 1->aaa
    -- но если есть только 1[0..8]->aaa и для 1 нет значения и не определено invalid_value
    -- то свертка 1->aaa невозможна
    -- но если определен еще префикс 19->bbb то возможно 1->aaa 19->bbb
    if (new_pfx_count > 0) and not val then
      return
    end

    -- если нет 'верхнего' префикса то нужно создать еще один
    -- Здесь не проверяется префикс, а не значение потому что
    --  1 -> a
    --  11[0..8] -> b
    -- У нас есть верхнее значениеим для `11`, но префикса нет поэтому
    -- нам нужно его создать
    -- 1 -> a
    -- 11 -> b
    -- 119 -> a
    if not t[true] then new_pfx_count = new_pfx_count + 1 end

    --Если свертка не целесообразна
    if remove_pfx_count <= new_pfx_count then
      return nil
    end

    -- удалям префикс т.к. значение более кототкого имеет тоже значение.
    -- Это делает `pack_dup`, но можно это сделать и сдесьб чтобы не
    -- вызывать его после.
    if upval == max_val then
      t[true] = nil
    else
      t[true] = max_val
    end

    -- Это значение для полного соответствия префиксу
    t[false] = val

    --свертка
    for _, key in ipairs(char_set) do repeat

      -- Нет поддерева - создаем
      if t[key] == nil then
        t[key] = {}
      end

      -- Нет значения - присваиваем значение более короткого префикса
      if t[key][true] == nil then
        assert(val ~= nil)
        t[key][true] = val
        break --continue
      end

      --Удаляем префиксы с максимальным количеством повторений
      if compare_value(t[key][true], max_val) then
        t[key][true] = nil;
      end

    until true end

    return true
  end

  do_work (t, nil, invalid_value)

  return t
end

local function pack(t, allow_create_prefix, invalid_value, compare_value, char_set)
  pack_dup(t, compare_value)
  if allow_create_prefix then
    pack_roll(t, invalid_value, compare_value, char_set)
  end
  pack_empty(t)
  return t
end

-- Возвращает поддерево
local function sub_tree(t, key)
  for i = 1, #key do
    local b = string.sub(key, i, i)
    t = t[b]
    if not t then return nil end
  end
  return t
end

-- Итератор
local function for_each(t, func)
  if type(func) ~= 'function' then
    return 
  end

  local do_work 
  do_work = function (t, name)
    if t[true] ~= nil then
      func(name, t[true], true)
    end
    if t[false] ~= nil then
      func(name, t[false], false)
    end
    for k, r in pairs(t) do
      if type(k) ~= 'boolean' then
        do_work(r, name .. k)
      end
    end
  end
  do_work(t, '')
end

-- Итератор
local function for_each_sort(t, char_set, func)
  
  if (type(char_set) == 'function')and(func == nil) then
    func = char_set 
    char_set = default_char_set
  end

  if type(func) ~= 'function' then
    return 
  end

  local do_work 
  do_work = function (t, name)
    if t[true] ~= nil then
      func(name, t[true], true)
    end
    if t[false] ~= nil then
      func(name, t[false], false)
    end

    for _, k in ipairs(char_set) do
      assert(type(k) ~= 'boolean')
      local r = t[k]
      if r then
        assert(type(r) == 'table')
        do_work(r, name .. k)
      end
    end
  end
  do_work(t, '')
end

-- Итератор
local function transform(t, func)
  if type(func) ~= 'function' then
    return 
  end

  local do_work 
  do_work = function (t, name)
    if t[true] ~= nil then
      t[true] = func(name, t[true], true)
    end
    if t[false] ~= nil then
      t[false] = func(name, t[false], false)
    end
    for k, r in pairs(t) do
      if type(k) ~= 'boolean' then
        do_work(r, name .. k)
      end
    end
  end
  do_work(t, '')
end

-- 
local function find(t, key , use_false)
  if use_false == nil then use_false = true end

  local real_key, flag, value = '', true, t[true]

  for i = 1, #key do
    local b = string.sub(key, i, i)
    t = t[b]
    if not t then break end

    if use_false and i == #key and t[false] ~= nil then
      value, flag, real_key = t[false], false, key
      break
    elseif t[true] ~= nil then
      value, flag, real_key = t[true], true, string.sub(key, 1, i)
    end
  end

  return value, real_key, flag
end

---
-- Добавление префикса и значения
-- существующее значение перезаписывается
-- flag - true - значение для префикса
--      - false - префикс это не префикс а полная строка
local function add_element(t, key, val, flag )
  if flag == nil then flag = true end
  assert(type(flag) == 'boolean')

  for i = 1, #key do
    local b = string.sub(key, i, i)
    if not t[b] then
      t[b] = {}
    end
    t = t[b]
  end
  t[flag] = val

  return t
end

local function remove(t,  key)
  t = sub_tree(t, key)
  if not t then return false end
  t[true], t[false] = nil
  return true
end

-- Тест
--
local function build_tree(data)
  local t = {}
  for _, e in ipairs(data) do
    add_element(t, e[1], e[2])
  end
  return t
end

local function is_equal_tree(etalon, t, msg)
  local s = {}
  for_each_sort(t, function(prefix, value, flag)
    s[#s + 1] = prefix .. '/' .. value .. '/' .. tostring(flag)
  end)

  for i = 1, #s do
    if s[i] ~= etalon[i] then
      return false, string.format("Expected `%s` but got `%s`", tostring(etalon[i]), tostring(s[i]))
    end
  end

  for i = 1, #etalon do
    if s[i] ~= etalon[i] then
      return false, string.format("Expected `%s` but got `%s`", tostring(etalon[i]), tostring(s[i]))
    end
  end

  return true
end

local function test_pack_roll(enabled, t, e, ...)
  if not enabled then return end

  local t = build_tree(t)
  local ok, msg = is_equal_tree(e, pack(t, ...))
  if not ok then
    print("Expected:")
    for _, v in ipairs(e) do print('', v) end
    print("Got:")
    for_each_sort(t, function(prefix, value, flag)
      print('', prefix .. '/' .. value .. '/' .. tostring(flag))
    end)
  end
  assert(ok, msg)
end

local function self_test()

  local E = true
  local FIXME = false

  test_pack_roll(E, 
  {
    {'10', 'a'};
    {'11', 'a'};
    {'12', 'a'};
    {'13', 'a'};
    {'14', 'a'};
  },
  {
    '10/a/true',
    '11/a/true',
    '12/a/true',
    '13/a/true',
    '14/a/true',
  },
  true, '----'
  )

  test_pack_roll(E, 
  {
    {'1',  'b'};
    {'10', 'a'};
    {'11', 'a'};
    {'12', 'a'};
    {'13', 'a'};
    {'14', 'a'};
  },
  {
    '1/b/true',
    '10/a/true',
    '11/a/true',
    '12/a/true',
    '13/a/true',
    '14/a/true',
  },
  true, '----'
  )

  test_pack_roll(E, 
  {
    {'10', 'a'};
    {'11', 'a'};
    {'12', 'a'};
    {'13', 'a'};
    {'14', 'a'};
    {'15', 'a'};
  },
  {
    '1/a/true',
    '1/----/false',
    '16/----/true',
    '17/----/true',
    '18/----/true',
    '19/----/true',
  },
  true, '----'
  )

  test_pack_roll(E, 
  {
    {'1',  'b'};
    {'10', 'a'};
    {'11', 'a'};
    {'12', 'a'};
    {'13', 'a'};
    {'14', 'a'};
    {'15', 'a'};
  },
  {
    '1/a/true',
    '1/b/false',
    '16/b/true',
    '17/b/true',
    '18/b/true',
    '19/b/true',
  },
  true, '----'
  )

  test_pack_roll(E, 
  {
    {'10', 'a'};
    {'11', 'a'};
    {'12', 'a'};
    {'13', 'a'};
    {'14', 'a'};
    {'15', 'a'};
    {'16', 'b'};
    {'17', 'b'};
    {'18', 'b'};
    {'19', 'b'};
  },
  {
    '1/a/true',
    '1/----/false',
    '16/b/true',
    '17/b/true',
    '18/b/true',
    '19/b/true',
  },
  true, '----'
  )

  test_pack_roll(E, 
  {
    {'1',  'c'};
    {'10', 'a'};
    {'11', 'a'};
    {'12', 'a'};
    {'13', 'a'};
    {'14', 'a'};
    {'15', 'a'};
    {'16', 'b'};
    {'17', 'b'};
    {'18', 'b'};
    {'19', 'b'};
  },
  {
    '1/a/true',
    '1/c/false',
    '16/b/true',
    '17/b/true',
    '18/b/true',
    '19/b/true',
  },
  true
  )

  test_pack_roll(E, 
  {
    {'10', 'a'};
    {'11', 'a'};
    {'12', 'a'};
    {'13', 'a'};
    {'14', 'a'};
    {'15', 'a'};
    {'16', 'b'};
    {'17', 'b'};
    {'18', 'b'};
    {'19', 'b'};
  },
  {
    '1/a/true',
    '16/b/true',
    '17/b/true',
    '18/b/true',
    '19/b/true',
  },
  true
  )

  test_pack_roll(E, 
  {
    {'10', 'a'};
    {'11', 'a'};
    {'12', 'a'};
    {'13', 'a'};
    {'14', 'a'};
    {'15', 'a'};
    {'16', 'b'};
    {'17', 'b'};
    {'18', 'b'};
    {'19', 'b'};
  },
  {
    '1/a/true',
    '1/----/false',
    '16/b/true',
    '17/b/true',
    '18/b/true',
    '19/b/true',
  },
  true, '----'
  )

  test_pack_roll(E, 
  {
    {'1',   'a'};
    {'110', 'b'};
    {'111', 'b'};
    {'112', 'b'};
    {'113', 'b'};
    {'114', 'b'};
    {'115', 'b'};
    {'116', 'b'};
    {'117', 'b'};
    {'118', 'b'};
  },
  {
    '1/a/true',
    '11/b/true',
    '11/a/false',
    '119/a/true',
  },
  true, '----'
  )

  test_pack_roll(E, 
  {
    {'100', 'b'};
    {'101', 'b'};
    {'102', 'b'};
    {'103', 'b'};
    {'104', 'b'};
    {'105', 'b'};
    {'106', 'b'};
    {'107', 'b'};
    {'108', 'b'};
    {'109', 'b'};

    {'110', 'b'};
    {'111', 'b'};
    {'112', 'b'};
    {'113', 'b'};
    {'114', 'b'};
    {'115', 'b'};
    {'116', 'b'};
    {'117', 'b'};
    {'118', 'b'};
    {'119', 'b'};

    {'120', 'b'};
    {'121', 'b'};
    {'122', 'b'};
    {'123', 'b'};
    {'124', 'b'};
    {'125', 'b'};
    {'126', 'b'};
    {'127', 'b'};
    {'128', 'b'};
    {'129', 'b'};

    {'130', 'b'};
    {'131', 'b'};
    {'132', 'b'};
    {'133', 'b'};
    {'134', 'b'};
    {'135', 'b'};
    {'136', 'b'};
    {'137', 'b'};
    {'138', 'b'};
    {'139', 'b'};

    {'140', 'b'};
    {'141', 'b'};
    {'142', 'b'};
    {'143', 'b'};
    {'144', 'b'};
    {'145', 'b'};
    {'146', 'b'};
    {'147', 'b'};
    {'148', 'b'};
    {'149', 'b'};

    {'150', 'b'};
    {'151', 'b'};
    {'152', 'b'};
    {'153', 'b'};
    {'154', 'b'};
    {'155', 'b'};
    {'156', 'b'};
    {'157', 'b'};
    {'158', 'b'};
    {'159', 'b'};

  },
  {
    '1/b/true',
    '1/----/false',
    '10/----/false',
    '11/----/false',
    '12/----/false',
    '13/----/false',
    '14/----/false',
    '15/----/false',
    '16/----/true',
    '17/----/true',
    '18/----/true',
    '19/----/true',
  },
  true, '----'
  )

  test_pack_roll(E, 
  {
    {'10', 'a'};
    {'11', 'a'};
    {'12', 'a'};
    {'13', 'a'};
    {'14', 'a'};
    {'15', 'a'};
    {'16', 'a'};
    {'17', 'a'};
    {'18', 'a'};
    {'19', 'a'};
  },
  {
    '10/a/true',
    '11/a/true',
    '12/a/true',
    '13/a/true',
    '14/a/true',
    '15/a/true',
    '16/a/true',
    '17/a/true',
    '18/a/true',
    '19/a/true',
  },
  false
  )

  test_pack_roll(E,
  {
    {'1876',    'mob'};
    {'18762',   'fix'};
    {'187621',  'mob'};
    {'187626',  'mob'};
    {'187627',  'mob'};
    {'187628',  'mob'};
    {'187629',  'mob'};
  },
  {
    '1876/mob/true',
    '18762/fix/false',
    '187620/fix/true',
    '187622/fix/true',
    '187623/fix/true',
    '187624/fix/true',
    '187625/fix/true',
  },
  true
  )

  -- Не уверен что это возможно на рекурсивном подъеме
  test_pack_roll(FIXME,
  {
    {'1876',    'fix'};
    {'187621',  'mob'};
    {'187626',  'mob'};
    {'187627',  'mob'};
    {'187628',  'mob'};
    {'187629',  'mob'};
    {'18763',   'mob'};
    {'18764',   'mob'};
    {'187650',  'mob'};
    {'187652',  'mob'};
    {'187653',  'mob'};
    {'187654',  'mob'};
    {'187655',  'mob'};
    {'187656',  'mob'};
    {'187657',  'mob'};
    {'187658',  'mob'};
    {'187659',  'mob'};
    {'187661',  'mob'};
    {'187662',  'mob'};
    {'187663',  'mob'};
    {'187664',  'mob'};
    {'18767',   'mob'};
    {'18768',   'mob'};
    {'1876909', 'mob'};
    {'1876919', 'mob'};
    {'1876990', 'mob'};
    {'1876995', 'mob'};
    {'1876997', 'mob'};
    {'1876999', 'mob'};
  },
  {
    '1876/mob/true',
    '1876/fix/false',
    '18760/fix/true',
    '18761/fix/true',
    '18762/fix/false',
    '187620/fix/true',
    '187622/fix/true',
    '187623/fix/true',
    '187624/fix/true',
    '187625/fix/true',
    '187651/fix/true',
    '18766/fix/true',
    '187661/mob/true',
    '187662/mob/true',
    '187663/mob/true',
    '187664/mob/true',
    '18769/fix/true',
    '1876909/mob/true',
    '1876919/mob/true',
    '1876990/mob/true',
    '1876995/mob/true',
    '1876997/mob/true',
    '1876999/mob/true',
  },
  true
  )

end

local tree = {
  __self_test   = self_test;
  add           = add_element;
  find          = find;
  pack          = pack;
  sub_tree      = sub_tree;
  for_each      = for_each;
  for_each_sort = for_each_sort;
  transform     = transform;

  INVALID_VALUE_ALWAYS_NIL = INVALID_VALUE_ALWAYS_NIL;
  default_char_set         = default_char_set;
  default_compare          = default_compare;

}

return tree
