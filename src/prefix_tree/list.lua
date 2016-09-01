-------------------------------------------------------------------
-- Реализация декодирования строки префиксов
-------------------------------------------------------------------

local lpeg = require 'lpeg'
local re   = require 're'
local ut   = require 'prefix_tree.utils'

---
-- Уменьшает диапазон удаляя последние символы из префиксов
-- если они покрывают весь диапазон
--
-- 12345678900-12345678999 -> 123456789
--
local function pack_range(be, en, first_cahr, last_cahr)
  if #be ~= #en then
    return be, en
  end
  first_cahr = first_cahr or '0'
  last_cahr  = last_cahr  or '9'
  local last_be, last_en = string.sub(be, -1, -1), string.sub(en, -1, -1)
  while last_be == first_cahr do
    if last_en == last_cahr then
      be, en = string.sub(be, 1, -2), string.sub(en, 1, -2)
      last_be, last_en = string.sub(be, -1, -1), string.sub(en, -1, -1)
    else
      break
    end
  end
  return be, en
end

local DecodeAppend, DecodePrefixList do

local function list(t)
  t.subprefix=nil
  return {
    name = "list";
    value = t;
  }
end

local function append(t)
  t.subprefix=nil
  return {
    name = "append";
    value = t;
  }
end

local function append_tst(t)
  t.subprefix=nil
  return {
    name = "append";
    value = t;
  }
end
function serialize(...)
  require "sys"
  sys.serialize({...},"SERIALIZE")
end

local PrefixList_pat = re.compile(
[=============================================================================[
  mian     <- <sp>* <str> <sp>* <eos>                                          
  str      <- (<list> (<lstdelim> <list>)*)                    ->{}            
  list     <- <list1>                                          ->{}            
  list1    <- (                                                                
                <applist>                                      ->{} ->append   
                <listelem>                                     ->{} ->list     
              )                                                              /  -- 7 4 9 5,6 -> append{7,4,9} list{5,6}
              (<applist> <elem>)                               ->{} ->append /  -- 7 495 -> append{7,495}
              <listelem>                                       ->{} ->list   /  -- 7,495 -> list{7,495}
              <elem>                                           ->{} ->list      -- 7495  -> list{7495}
                                                                               
  applist  <- ( <elem>  <appdelim>)+                                            -- список главных префиксов. может существовать
                                                                                --   только при наличии подчененных элементов
  listelem  <- ('('<sp>* <listelem1> <sp>*')') /  <listelem1>                   -- список элементов
  listelem1 <- ((<elem> <elmdelim>)+ <elem>)                                   
                                                                               
  elem     <- ('(' <sp>* <elem1> <sp>* ')') / <elem1>                                       -- элемент списка диапазон или одиночный элемент
  elem1    <-  <range>  / <single>                                             
                                                                               
  range    <- {:subprefix: %a+(%d+%a+)+ / (%a*) :}                             
              (                                                                
                {:beg:%d+:}                                                    
                <sp>* [-] <sp>*                                                
                {:sub:=subprefix:} {:en:%d+:}                                  
               )  -> {}                                                        
                                                                               
  single   <- {%w*}                                                            
  appdelim <- <sp> !(<elmdelim> / <lstdelim> / <eos>)                          -- Отделяет главные префиксы
  lstdelim <- (<sp>* [;] <sp>*)                                                -- Отделяет независимые списки
  elmdelim <- (<sp>* [,] <sp>*)                                                -- Отделяет элементы списка
  sp       <- ' '+                                                             
  eos      <- !.                                                               
]=============================================================================],
{list=list,append=append,appendtst=append_tst,print=serialize})

function DecodePrefixList(str)
  local t = lpeg.match(PrefixList_pat, str)
  if t then
    for i = 1,#t do
      for j = 1, #t[i] do
        local name  = t[i][j].name
        local value = t[i][j].value
        t[i][name]  = value;
        t[i][j]     = nil
      end
    end
  end
  return t
end

function DecodeAppend(append,pack_range)
  local new_append = {''}

  if append == nil then
    return new_append
  end

  for i,prefix in ipairs(append) do
    if type(prefix) == 'string' then 
      -- добавляем новый префикс ко всем предыдущим
      for k,v in ipairs(new_append) do
        new_append[k] = v .. prefix
      end
    else
      local sub_prefix, beg, en = assert(prefix.sub), assert(prefix.beg), assert(prefix.en)
      if pack_range and (append[i+1] == nil) then
        beg, en = pack_range(beg, en)
      end
      local len = math.max(#beg, #en)
      if len > 0 then
        local t = {}
        for i = tonumber(beg), tonumber(en) do
          local s = sub_prefix .. ut.fitstr(tostring(i), '0', len)
          for k,v in ipairs(new_append) do
            t[#t + 1] = v..s
          end
        end
        new_append = t
      end
    end
  end
  return new_append
end

end

local function ProcessPrefixes(functor, pack_range, t, prefix_str, ...)
  local c = 0
  for _, prefix in ipairs(t.list) do
    if type(prefix) == 'string' then 
      for _,main_prefix in ipairs(t.append) do
        c = c + 1
        functor(main_prefix .. prefix, prefix_str, ...)
      end
    else
      local sub_prefix, beg, en = assert(prefix.sub), assert(prefix.beg), assert(prefix.en)
      if pack_range then
        beg, en = pack_range(beg, en)
      end
      local len = math.max(#beg, #en)
      for i = tonumber(beg), tonumber(en) do
        for _,main_prefix in ipairs(t.append) do
          local s = main_prefix .. sub_prefix .. ut.fitstr(tostring(i), '0', len)
          c = c + 1
          functor(s, prefix_str, ...)
        end
      end
    end
  end
  return c
end

local function DecodePrefixString(functor, pack_range, prefixes, ...)
  local t = DecodePrefixList(prefixes)
  if not t then return end

  local c = 0
  for _,p in ipairs(t) do
    if p.list == nil then
      p.list   = {''}
      p.append = DecodeAppend(p.append, pack_range)
    else
      p.append = DecodeAppend(p.append)
    end
    c = c + ProcessPrefixes(functor, pack_range, p, prefixes, ...)
  end

  return c
end

local function self_test_pat()

local cmp_t

local function cmp_v(v1,v2)
  local flag = true
  if type(v1) == 'table' then
    if type(v2) == 'table' then
      flag = cmp_t(v1, v2)
    else
      flag = false
    end
  else
    flag = (v1 == v2)
  end
  return flag
end

function cmp_t(t1,t2)
  for k in pairs(t2)do
    if t1[k] == nil then
      return false
    end
  end
  for k,v in pairs(t1)do
    if not cmp_v(t2[k],v) then 
      return false 
    end
  end
  return true
end

local function dump (pat)
  local pp = require "pp"
  local t = DecodePrefixList(pat)
  pp(t,'"' .. pat .. '"')
  io.write"\n"
end

local function dump2 (pat)
  local pp = require "pp"
  local t = DecodePrefixList(pat)
  t = DecodeAppend(assert(t[1].append),pack_range)
  pp(t,'"' .. pat .. '"')
  io.write"\n"
end

-- dump"7 4 9 (5,6) 7"
-- dump2"999 1-5 7-8"

local tests = {}
local tests_index={}
local function tclone(t)
  local res = {}
  for k,v in pairs(t)do res[k]=v end
  return res
end

local test = function(str, result) 
  local t 
  if type(result) == 'string' then
    local res = assert(tests_index[str])
    t = {result, result = res.result}
    assert(result ~= str)
    tests_index[result] = t;
  else
    t = {str,result=result}
    tests_index[str] = t;
  end
  return table.insert(tests,t)
end

test("7 4 9 5,6",
  {{
    append = {"7","4","9"};
    list   = {"5","6"};
  }}
)
test("7 4 9 5,6",  "7 4 9 (5,6)"    )
test("7 4 9 5,6",  "7 4 9 (5 ,6)"   )
test("7 495",
  {{
   append = {"7","495"};
  }}
)
test("7495",
  {{
    list = {"7495"};
  }}
)
test("7,495",
  {{
    list   = {"7","495"};
  }}
)
test("749 5 - 6",
  {{
    append={
      [1]="749";
      [2]={
        beg="5";
        sub="";
        en="6";
      };
    };
  }}
)
test("749 a5 - a6",
  {{
    append={
      [1]="749";
      [2]={
        beg="5";
        sub="a";
        en="6";
      };
    };
  }}
)
test("749 5 - 6", "749 (5 - 6)")
test("749 5 - 6", "749 (5-6)"  )
test("749 5 - 6", "749 ( 5-6 )")
test("7 5 1-5 7-9", 
  {{
    append={
      [1]="7";
      [2]="5";
      [3]={
        sub="";
        en="5";
        beg="1";
      };
      [4]={
        sub="";
        en="9";
        beg="7";
      };
    };
  }}
);
test("7 5 1-5 7-9", "7 5 1- 5 7-9")
test("7 5 1-5 7-9", "7 5 1 -5 7-9")
test("7 5 1-5 7-9", "7 5 1 - 5 7-9")
test("7 5 1-5 7-9", "7 5 1 - 5 7 - 9")
test("7 5 1-5 7-9", "7 5 1-5 7 - 9")
test("7 5 1-5 7-9", "7 5 (1-5) 7-9")
test("7 5 1-5 7-9", "7 5 ( 1-5) 7-9")
test("7 5 1-5 7-9", "7 5 ( 1-5 ) 7-9")
test("7 5 1-5 7-9", "7 5 ( 1 - 5 ) 7-9")
test("7 5 1-5 7-9", "7 5 ( 1 - 5 ) (7-9)")

----------------------------------
test"7 4 9 (5,6) 7"         
test"7 4 9 (5,6),7"         


for _,test_case in ipairs(tests)do
  local t = DecodePrefixList(test_case[1])
  assert(cmp_v(t, test_case.result ), test_case[1])

  -- проверяем разделение на списки
  local str = test_case[1] .. ';' .. test_case[1]
  t = DecodePrefixList(str)
  local res
  if test_case.result ~= nil then
    local n = #test_case.result 
    res = {}
    for i = 1,n do
      res[i]   = test_case.result[i]
      res[2*i] = test_case.result[i]
    end
    assert(#res == 2*n)
  end
  assert(cmp_v(t, res ), str)
end

end

local function self_test()
  self_test_pat()
end

local list = {
  __self_test = self_test;
  decode      = DecodePrefixString;
  pack_range  = pack_range;
}

return list