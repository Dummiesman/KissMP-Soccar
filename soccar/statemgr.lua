local M = {}

-- Exported
M.timeInState = 0
M.currentStateId = nil

-- Locals
local currentState = nil
local currentStateId = nil

local states = {}
local timeInState = 0

local function export()
  M.timeInState = timeInState
  M.currentStateId = currentStateId
  M.currentStateName = STATE_NAMES[currentStateId]
end

-- Use this carefully and DO NOT modify the result
local function getStateReference(stateId)
  return states[stateId]
end

local function switchToState(stateId) 
  -- call leave
  if currentState ~= nil and currentState.onLeaveState then
    currentState.onLeaveState()
  end
  
  currentState = states[stateId]
  currentStateId = stateId
  if currentState.onEnterState then
    currentState.onEnterState()
  end
  
  timeInState = 0
  export()
  
  print("=== switchToState(" .. M.currentStateName .. ") ===")
end

local function loadStateLua(stateId, stateName)
	local tbl = require("addons/soccar/gamestates/" .. stateName)
  states[stateId] = tbl
  return tbl
end

local function onVehicleReset(vehicle_id, client_id)
  if currentState ~= nil and currentState.onVehicleReset then
    currentState.onVehicleReset(vehicle_id, client_id)
  end
end

local function onVehicleRemoved(vehicle_id, client_id)
  if currentState ~= nil and currentState.onVehicleRemoved then
    currentState.onVehicleRemoved(vehicle_id, client_id)
  end
end

local function onVehicleSpawned(vehicle_id, client_id)
  if currentState ~= nil and currentState.onVehicleSpawned then
    currentState.onVehicleSpawned(vehicle_id, client_id)
  end
end

local function onVehicleFirstSpawned(vehicle_id, client_id)
  if currentState ~= nil and currentState.onVehicleFirstSpawned then
    currentState.onVehicleFirstSpawned(vehicle_id, client_id)
  end
end

local function onChatMessage(client_id, message)
  if currentState ~= nil and currentState.onChatMessage then
    return currentState.onChatMessage(client_id, message)
  end
end

local function onPlayerConnected(client_id)
  if currentState ~= nil and currentState.onPlayerConnected then
    currentState.onPlayerConnected(client_id)
  end
end

local function onPlayerDisconnected(client_id)
  if currentState ~= nil and currentState.onPlayerDisconnected then
    currentState.onPlayerDisconnected(client_id)
  end
end

local function update(dt)
  timeInState = timeInState + dt
  if currentState ~= nil and currentState.update then
    currentState.update(dt)
  end
  
  -- exports
  export()
end

M.loadStateLua = loadStateLua
M.switchToState = switchToState
M.getStateReference = getStateReference

M.onVehicleSpawned = onVehicleSpawned
M.onVehicleFirstSpawned = onVehicleFirstSpawned
M.onVehicleRemoved = onVehicleRemoved
M.onVehicleReset = onVehicleReset

M.onPlayerConnected = onPlayerConnected
M.onPlayerDisconnected = onPlayerDisconnected

M.onChatMessage = onChatMessage
M.update = update

return M