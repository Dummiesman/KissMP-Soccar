-- Constants
TEAM_NAMES = { [0] = "Red", [1] = "Blue", [2] = "Nobody" }
STATE_NAMES = { [0] = "Lobby", [1] = "Starting", [2] = "Running", [3] = "Post Game", [4] = "None"}
TEAM_LIMITS = { [0] = 3, [1] = 3, [2] = -1 }

-- LIMITTYPE
LIMITTYPE_NONE = 0
LIMITTYPE_TIME = 1
LIMITTYPE_SCORE = 2

-- TEAMS
TEAM_RED = 0
TEAM_BLUE = 1
TEAM_NOBODY = 2

-- GAME STATES
GAMESTATE_LOBBY = 0
GAMESTATE_RUNNING = 2
GAMESTATE_POSTGAME = 3
GAMESTATE_NONE = 4

-- IO
function readFile(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

function fileExists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function readJsonFile(file)
  if not fileExists(file) then return nil end
  return decode_json(readFile(file))
end

function writeJsonFile(filepath, content)
  local fileContent = encode_json_pretty(content)
  if not fileContent then return false end
  
  local file = io.open(filepath, "w")
  if not file then return false end
  
  file:write(fileContent)
  file:close()
  return true
end

-- Vector math functions
function vecDot(vec1, vec2)
	return (vec1[1]  * vec2[1]) + (vec1[2] * vec2[2]) + (vec1[3] * vec2[3])
end

function vecLenSqr(vector)
  return vector[1] * vector[1] + vector[2] * vector[2] + vector[3] * vector[3]
end

function vecLen(vector)
  return math.sqrt(vecLenSqr(vector))
end

function vecNormalize(vec)
  local m = vecLen(vec)
  if m == 0 then
    return {0,0,0}
  else
    return {vec[1] / m, vec[2] / m, vec[3] / m}
  end
end

function vecDistSqr(vec1, vec2)
  local xd = vec2[1] - vec1[1]
  local yd = vec2[2] - vec1[2]
  local zd = vec2[3] - vec1[3]
  return vecLenSqr({xd, yd, zd})
end

function vecDist(vec1, vec2)
  return math.sqrt(vecDistSqr(vec1, vec2))
end

function vehicleDistanceSqr(veh1, veh2)
  if not veh1 or not veh2 then return math.huge end

  local v1t = veh1:getTransform()
  local v2t = veh2:getTransform()
  
  if not v1t or not v2t then return math.huge end
  
  local v1p = v1t:getPosition()
  local v2p = v2t:getPosition()
  
  return vecDistSqr(v1p, v2p)
end

function vehicleDistance(veh1, veh2)
  return math.sqrt(vehicleDistanceSqr(veh1, veh2))
end

-- Plane math functions
function planeDist(vec, planePos, planeDir)
  local xd = planePos[1] - vec[1]
  local yd = planePos[2] - vec[2]
  local zd = planePos[3] - vec[3]

  return vecDot(planeDir, {xd,yd,zd});
end

function planeSide(vec, planePos, planeDir)
  local tx = vec[1] - planePos[1]
  local ty = vec[2] - planePos[2]
  local tz = vec[3] - planePos[3]

  -- get normalized direction
  local vecDir = vecNormalize({tx,ty,tz})
  local dot = vecDot(vecDir, planeDir)
  return dot > 0
end

-- Functions
function getConnections()
  return connections or {}
end

function getConnection(client_id)
  local l_connections = getConnections()
  return l_connections[client_id]
end

function getConnectionCount()
  local c = 0
  for _,_ in pairs(getConnections()) do
    c = c + 1
  end
  return c
end

function strTableToTableStr(tbl, quotechar)
  if tbl == nil then return "{}" end
  quotechar = quotechar or '"'
  local r = "{"  
  for _,v in pairs(tbl) do
    r = r..quotechar..tostring(v)..quotechar..","
  end
  r = r:sub(1,r:len() - 1) .. "}"
  return r
end

function strTableToStr(tbl)
  if tbl == nil then return "" end
  local r = ""  
  for _,v in pairs(tbl) do
    r = r..tostring(v)..","
  end
  r = r:sub(1,r:len() - 1)
  return r
end

function luaStrEscape(str, q)
  local escapeMap = { ["\n"] = [[\n]], ["\\"] = [[\]] }

  local qOther = nil
  if not q then q = "'" end
  if q == "'" then qOther = '"' else qOther = "'" end
  
  local serializedStr = q
  for i=1,str:len(),1 do
    local c = str:sub(i,i)
    if c == q then
      serializedStr = serializedStr .. q .. " .. " .. qOther .. c .. qOther .. " .. " .. q
    elseif escapeMap[c] then
      serializedStr = serializedStr .. escapeMap[c]
    else
      serializedStr = serializedStr .. c
    end
  end
  serializedStr = serializedStr .. q
  return serializedStr
end

function shuffleList(x)
  local shuffled = {}
  for i, v in ipairs(x) do
    local pos = math.random(1, #shuffled+1)
    table.insert(shuffled, pos, v)
  end
  return shuffled
end

function setBulletTime(bt)
  for client_id, connection in pairs(getConnections()) do
    connection:sendLua("bullettime.pause(false) bullettime.set(" .. tostring(bt) .. ")")
  end
end

function setVehicleFreeze(vehicle, enabled)
  local value = enabled and 1 or 0
  if vehicle ~= nil then
    vehicle:sendLua("controller.setFreeze(" .. tostring(value) .. ")")
  end
end

function setVehicleFreezeAll(enabled)
  if vehicles == nil then return end
  for vehicle_id, vehicle in pairs(vehicles) do
    setVehicleFreeze(vehicle, enabled)
  end
end

function setVehicleFocusAll()
  for client_id, participant in pairs(GameData.participants) do
    participant.setVehicleFocus()
  end
end

function showOnscreenMessage(client, message, time)
  time = time or 3
  client:sendLua("guihooks.trigger('ScenarioFlashMessage', {{'" .. message .. "', " .. tostring(time) .. ", 0, true}})")
end

function setScenarioUi(client)
  client:sendLua("extensions.core_gamestate.setGameState(nil, 'proceduralScenario', nil, nil)")
end

function setNormalUi(client)
  client:sendLua("extensions.core_gamestate.setGameState(nil, 'freeroam', nil, nil)")
end

function showOnscreenMessageAll(message, time)
  for client_id, connection in pairs(getConnections()) do
    showOnscreenMessage(connection, message, time)
  end
end

function setScenarioUiAll()
  for client_id, connection in pairs(getConnections()) do
    setScenarioUi(connection)
  end
end

function setNormalUiAll()
  for client_id, connection in pairs(getConnections()) do
    setNormalUi(connection)
  end
end

function findClosestVehicleSqr(vehicle)
  if not vehicle then return math.huge end
  
  local id = vehicle:getData():getID()
  local distance = math.huge
  
  for vid, otherVehicle in pairs(vehicles) do
    local oid = otherVehicle:getData():getID()
    if id ~= oid then
      local dist = vehicleDistanceSqr(vehicle, otherVehicle)
      if dist < distance then distance = dist end
    end
  end
  
  return distance
end

function findClosestVehicle(vehicle)
   return math.sqrt(findClosestVehicleSqr(vehicle))
end

function vehicleIdWrapper(vid)
  if vid == 0 then return nil end
  return vid
end

function getClientVehicle(client)
  local vehicleId = vehicleIdWrapper(client:getCurrentVehicle())
  if not vehicleId then return nil end
  
  local vehicle = vehicles[vehicleId]
  return vehicle
end

function removeVehicle(vehicle)
    if vehicle == nil then return end
   local ingameId = vehicle:getData():getInGameID()
   for client_id, connection in pairs(getConnections()) do
    connection:sendLua("local veh = be:getObjectByID(" .. tostring(ingameId) .. ") if veh then veh:delete() end")
   end
end

-- Chat Functions
function cmd_parse(cmd)
  local parts = {}
  local len = cmd:len()
  local escape_sequence_stack = 0
  local in_quotes = false

  local cur_part = ""
  for i=1,len,1 do
     local char = cmd:sub(i,i)
     if escape_sequence_stack > 0 then escape_sequence_stack = escape_sequence_stack + 1 end
     local in_escape_sequence = escape_sequence_stack > 0
     if char == "\\" then
        escape_sequence_stack = 1
     elseif char == " " and not in_quotes then
        table.insert(parts, cur_part)
        cur_part = ""
     elseif char == '"'and not in_escape_sequence then
        in_quotes = not in_quotes
     else
        cur_part = cur_part .. char
     end
     if escape_sequence_stack > 1 then escape_sequence_stack = 0 end
  end
  if cur_part:len() > 0 then
    table.insert(parts, cur_part)
  end
  return parts
end

function sendToast(connection, message)
  connection:sendLua("ui_message('" .. message .. "',3,'kissmp',nil)")
end

function sendChatMessage(connection, message, color)
  local hasColor = color ~= nil and type(color) == 'table'
  if not hasColor then
    connection:sendChatMessage(message)
  else
    connection:sendLua('extensions.kissui.add_message(' .. luaStrEscape(message) .. ', {r=' .. tostring(color.r or 0) .. ",g=" .. tostring(color.g or 0) .. ",b=" .. tostring(color.b or 0) .. ",a=" .. tostring(color.a or 1) .. "})")
  end
end

function sendChatMessageAndToast(connection, message, color)
  sendChatMessage(connection, message, color)
  sendToast(connection, message)
end

function broadcastChatMessage(message, color)
  for client_id, connection in pairs(getConnections()) do
    sendChatMessage(connection, message, color)
  end
end

function broadcastToast(message)
  for client_id, connection in pairs(getConnections()) do 
    sendToast(connection, message)
  end
end

function broadcastChatMessageAndToast(message, color)
  broadcastChatMessage(message, color)
  broadcastToast(message)
end