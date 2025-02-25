--luacheck: no max line length
--*****************************************************************
-- Inside of this script, you will find helper functions
--*****************************************************************

--**************************************************************************
--**********************Start Global Scope *********************************
--**************************************************************************

local funcs = {}
-- Providing standard JSON functions
funcs.json = require('Sensors/IODDInterpreter/helper/Json')

--**************************************************************************
--********************** End Global Scope **********************************
--**************************************************************************
--**********************Start Function Scope *******************************
--**************************************************************************

-- Function to create a list from table
--@createStringListBySize(size:int):string
local function createStringListBySize(size)
  local list = "["
  if size >= 1 then
    list = list .. '"' .. tostring(1) .. '"'
  end
  if size >= 2 then
    for i=2, size do
      list = list .. ', ' .. '"' .. tostring(i) .. '"'
    end
  end
  list = list .. "]"
  return list
end
funcs.createStringListBySize = createStringListBySize

local function getTableSize(someTable)
  if not someTable then
    return 0
  end
  local size = 0
  for _,_ in pairs(someTable) do
    size = size + 1
  end
  return size
end
funcs.getTableSize = getTableSize

local function copy(origTable, seen)
  if type(origTable) ~= 'table' then return origTable end
  if seen and seen[origTable] then return seen[origTable] end
  local s = seen or {}
  local res = setmetatable({}, getmetatable(origTable))
  s[origTable] = res
  for k, v in pairs(origTable) do res[copy(k, s)] = copy(v, s) end
  return res
end
funcs.copy = copy

local function renameDatatype(dataPointInfo)
    if dataPointInfo.SimpleDatatype then
      dataPointInfo.Datatype = copy(dataPointInfo.SimpleDatatype)
      dataPointInfo.SimpleDatatype = nil
    elseif dataPointInfo.Datatype.SimpleDatatype then
      dataPointInfo.Datatype.Datatype = copy(dataPointInfo.Datatype.SimpleDatatype)
      dataPointInfo.Datatype.SimpleDatatype = nil
      if dataPointInfo.Datatype.Datatype["xsi:type"] then
        dataPointInfo.Datatype.Datatype.type = dataPointInfo.Datatype.Datatype["xsi:type"]
        dataPointInfo.Datatype.Datatype["xsi:type"] = nil
      end
    elseif dataPointInfo.Datatype.RecordItem then
      for recordItemID, recordItemInfo in ipairs(dataPointInfo.Datatype.RecordItem) do
        if recordItemInfo.SimpleDatatype then
          dataPointInfo.Datatype.RecordItem[recordItemID].Datatype = copy(recordItemInfo.SimpleDatatype)
          dataPointInfo.Datatype.RecordItem[recordItemID].SimpleDatatype = nil
          if recordItemInfo.Datatype["xsi:type"] then
            dataPointInfo.Datatype.RecordItem[recordItemID].Datatype.type = recordItemInfo.Datatype["xsi:type"]
            dataPointInfo.Datatype.RecordItem[recordItemID].Datatype["xsi:type"] = nil
          end
        end
      end
    end
    if dataPointInfo.Datatype["xsi:type"] then
      dataPointInfo.Datatype.type = dataPointInfo.Datatype["xsi:type"]
      dataPointInfo.Datatype["xsi:type"] = nil
    end
  return dataPointInfo
end
funcs.renameDatatype = renameDatatype

--- Function to convert a table into a Container object
---@param content auto[] Lua Table to convert to Container
---@return Container cont Created Container
local function convertTable2Container(content)
  local cont = Container.create()
  for key, value in pairs(content) do
    if type(value) == 'table' then
      cont:add(key, convertTable2Container(value), nil)
    else
      cont:add(key, value, nil)
    end
  end
  return cont
end
funcs.convertTable2Container = convertTable2Container


--- Function to convert a Container into a table
---@param cont Container Container to convert to Lua table
---@return auto[] data Created Lua table
local function convertContainer2Table(cont)
  local data = {}
  local containerList = Container.list(cont)
  local containerCheck = false
  if tonumber(containerList[1]) then
    containerCheck = true
  end
  for i=1, #containerList do

    local subContainer

    if containerCheck then
      subContainer = Container.get(cont, tostring(i) .. '.00')
    else
      subContainer = Container.get(cont, containerList[i])
    end
    if type(subContainer) == 'userdata' then
      if Object.getType(subContainer) == "Container" then

        if containerCheck then
          table.insert(data, convertContainer2Table(subContainer))
        else
          data[containerList[i]] = convertContainer2Table(subContainer)
        end

      else
        if containerCheck then
          table.insert(data, subContainer)
        else
          data[containerList[i]] = subContainer
        end
      end
    else
      if containerCheck then
        table.insert(data, subContainer)
      else
        data[containerList[i]] = subContainer
      end
    end
  end
  return data
end
funcs.convertContainer2Table = convertContainer2Table

-- Function to get content list
--@createContentList(data:table):string
local function createContentList(data)
  local sortedTable = {}
  for key, _ in pairs(data) do
    table.insert(sortedTable, key)
  end
  table.sort(sortedTable)
  return table.concat(sortedTable, ',')
end
funcs.createContentList = createContentList

-- Function to get content list
--@createContentList(data:table):string
local function createJsonList(data)
  local sortedTable = {}
  for key, _ in pairs(data) do
    table.insert(sortedTable, key)
  end
  table.sort(sortedTable)
  return funcs.json.encode(sortedTable)
end
funcs.createJsonList = createJsonList

-- Function to create a list from table
--@createStringListBySimpleTable(content:table):string
local function createStringListBySimpleTable(content)
  local list = "["
  if #content >= 1 then
    list = list .. '"' .. content[1] .. '"'
  end
  if #content >= 2 then
    for i=2, #content do
      list = list .. ', ' .. '"' .. content[i] .. '"'
    end
  end
  list = list .. "]"
  return list
end
funcs.createStringListBySimpleTable = createStringListBySimpleTable

local function getDatatypeBitlength(datatypeInfo)
  if datatypeInfo.type == "BooleanT" then
    return 1
  elseif datatypeInfo.type == "IntegerT" or datatypeInfo.type == "UIntegerT" or datatypeInfo.type == "RecordT" then
    return tonumber(datatypeInfo.bitLength)
  elseif datatypeInfo.type == "Float32T" then
    return 32
  elseif datatypeInfo.type == "StringT" or datatypeInfo.type == "OctetStringT" then
    return tonumber(datatypeInfo.fixedLength)
  elseif datatypeInfo.type == "ArrayT" then
    return tonumber(datatypeInfo.count)*getDatatypeBitlength(datatypeInfo.SimpleDatatype)
  end
end

local defaultValueForSimpleType = {
  ['BooleanT'] = false,
  ['UIntegerT'] = 1,
  ['IntegerT'] = -1,
  ['StringT'] = 'text',
  ['OctetStringT'] = 'text',
  ['Float32T'] = 0.01
}

local function makeExpectedPayload(compiledTable)
  local expectedTable = {}
  for dataPointId, dataPointInfo in pairs(compiledTable) do
    if dataPointInfo.subindeces then
      expectedTable[dataPointId] = {}
      for subindexId, subindexInfo in pairs(dataPointInfo.subindeces) do
        expectedTable[dataPointId][subindexId] = {
          value = defaultValueForSimpleType[subindexInfo.info.type]
        }
      end
    else
      expectedTable[dataPointId] = {
        value = defaultValueForSimpleType[dataPointInfo.info.type]
      }
    end
  end
  return expectedTable
end
funcs.makeExpectedPayload = makeExpectedPayload

local function getSingleInfoTable(rawInfoTable)
  local info = copy(rawInfoTable)
  if rawInfoTable.Datatype then
    for key, value in pairs(rawInfoTable.Datatype) do
      info[key] = value
    end
  end
  if rawInfoTable.SimpleDatatype then
    for key, value in pairs(rawInfoTable.SimpleDatatype) do
      info[key] = value
    end
  end
  info.type = info["xsi:type"]
  info["xsi:type"] = nil
  info.RecordItem = nil
  info.Datatype = nil
  info.SimpleDatatype = nil
  return info
end

local function compileDataPointTable(dataInfo, selectedTable)
  if not dataInfo then
    return nil
  end
  local compiledTable = {}
  if dataInfo.Datatype["xsi:type"] == "ArrayT" or dataInfo.Datatype["xsi:type"] == "RecordT" then
    for subindex, selected in pairs(selectedTable) do
      if selected == true and subindex ~= "0" and subindex ~= "subindexAccessSupported" then
        if not compiledTable[dataInfo.Name] then
          local info = copy(dataInfo)
          for key, value in pairs(dataInfo.Datatype) do
            info[key] = value
          end
          info.type = info["xsi:type"]
          info["xsi:type"] = nil
          if dataInfo.Datatype["xsi:type"] == "ArrayT" then
            info.SimpleDatatype.type = info.SimpleDatatype["xsi:type"]
          end
          info.BitLength = getDatatypeBitlength(info)
          info.RecordItem = nil
          info.SimpleDatatype = nil
          compiledTable[dataInfo.Name] = {
            info = info,
            subindeces = {}
          }
        end
        if dataInfo.Datatype["xsi:type"] == "ArrayT" then
          local singleProcessDatatype = copy(dataInfo.Datatype.SimpleDatatype)
          singleProcessDatatype.subindex = subindex
          singleProcessDatatype.type = singleProcessDatatype["xsi:type"]
          singleProcessDatatype.bitOffset = (tonumber(subindex)-1) * getDatatypeBitlength(singleProcessDatatype)
          singleProcessDatatype.Name = dataInfo.Name.. '_element' .. tostring(subindex)
          compiledTable[dataInfo.Name].subindeces[singleProcessDatatype.Name] = {
            info = singleProcessDatatype
          }

        elseif dataInfo.Datatype["xsi:type"] == "RecordT" then
          local subindexMap = {}
          for i, subindexInfo in ipairs(dataInfo.Datatype.RecordItem) do
            subindexMap[subindexInfo.subindex] = i
          end
          local singleProcessDatatype = copy(dataInfo.Datatype.RecordItem[subindexMap[subindex]])
          singleProcessDatatype.subindex = subindex
          if not singleProcessDatatype.Name then
            singleProcessDatatype.Name = "Null parameter"
          end
          compiledTable[dataInfo.Name].subindeces[singleProcessDatatype.Name] = {
            info = getSingleInfoTable(singleProcessDatatype)
          }
        end
      end
    end
  elseif selectedTable["0"] == true then
    compiledTable[dataInfo.Name] = {
      info = getSingleInfoTable(dataInfo)
    }
  end
  if getTableSize(compiledTable) == 0 then
    return nil
  end
  return compiledTable
end
funcs.compileProcessDataTable = compileDataPointTable

local function compileParametersTable(iodd, selectedTable)
  local compiledTable = {}
  for index, subindeces in pairs(selectedTable) do
    for subindex, selected in pairs(subindeces) do
      if selected == true then
        local ioddIndexdata = iodd:getParameterInfoFromIndex(index)
        local compiledDataPointTable = compileDataPointTable(ioddIndexdata, subindeces)
        if compiledDataPointTable then
          for key, value in pairs(compiledDataPointTable) do
            compiledTable[key] = value
          end
        end
        break
      end
    end
  end
  if getTableSize(compiledTable) == 0 then
    return nil
  end
  return compiledTable
end
funcs.compileParametersTable = compileParametersTable

return funcs

--**************************************************************************
--**********************End Function Scope *********************************
--**************************************************************************