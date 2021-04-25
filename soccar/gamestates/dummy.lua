local M = {}
M.name = "Devmode"

local function printPositionRotation(client_id)
  local vehicleId = vehicleIdWrapper(getConnection(client_id):getCurrentVehicle())
  if not vehicleId then return end
  
  local vehicle = vehicles[vehicleId]
  if not vehicle then return end
  
  local transform = vehicle:getTransform()
  local pos = transform:getPosition()
  local rot = transform:getRotation()
  
  local output = "{ pos = {" .. pos[1] .. ", " .. pos[2] .. ", " .. pos[3] .. "}, rot = {" .. rot[1] .. ", " .. rot[2] .. ", " .. rot[3] .. ", " ..rot[4] .. "} }"
  print(output)
end

local function printPosition(client_id)
  local vehicleId = vehicleIdWrapper(getConnection(client_id):getCurrentVehicle())
  if not vehicleId then return end
  
  local vehicle = vehicles[vehicleId]
  if not vehicle then return end
  
  local transform = vehicle:getTransform()
  local pos = transform:getPosition()
  
  local output = "{" .. pos[1] .. ", " .. pos[2] .. ", " .. pos[3] .. "}"
  print(output)
end

local function onEnterState()
  broadcastChatMessage("=== Developer Mode Activated ===")
end

local function onChatMessage(client_id, message)
  local messageLower = message:lower()
  if messageLower == "/ppr" then printPositionRotation(client_id) return ""  end
  if messageLower == "/pp" then printPosition(client_id) return ""  end
  if messageLower == "/dw" then GameData.enableWinning = false return ""  end
  if messageLower == "/ew" then GameData.enableWinning = true return "" end
end

M.onEnterState = onEnterState
M.onChatMessage = onChatMessage
return M