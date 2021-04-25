-- clear require cache
local packageClear = {}
for k,v in pairs(package.loaded) do
  table.insert(packageClear, k)
end
for _,v in pairs(packageClear) do
  package.loaded[v] = nil
end

-- requires 
require("addons/soccar/globals")
 
-- scheduler
Scheduler = require("addons/soccar/scheduler")

-- state manager
StateManager = require("addons/soccar/statemgr")

StateManager.loadStateLua(GAMESTATE_LOBBY, "lobby")
StateManager.loadStateLua(GAMESTATE_RUNNING, "running")
StateManager.loadStateLua(GAMESTATE_POSTGAME, "postgame")
StateManager.loadStateLua(GAMESTATE_NONE, "dummy")

-- Client maps
local hasSpawnedMap = {}

-- GLOBAL GAMEDATA TABLE
GameData = {
  DEBUG_MODE = false,
  enableWinning = true,
  limitType = LIMITTYPE_TIME,
  timeLimit = 60 * 5,
  scoreLimit = 3,
  teams = {},
  participants = {},
  redSpawnpoints = {},
  blueSpawnpoints = {},
  redNetPlane = {pos={58.652, 129.572, 79.022}, dir={1, 0, 0}},
  blueNetPlane = {pos={-8.765, 129.572, 79.022}, dir={-1, 0, 0}},
  ballSpawnpoint = {25.128, 128.979, 80},
  winningTeam = TEAM_NOBODY,
  ballVehicleId = -1
}

GameData.teams[TEAM_RED] = {participants={},score=0}
GameData.teams[TEAM_BLUE] = {participants={},score=0}

--Spawns
GameData.redSpawnpoints = {
  { pos = {48.256, 112.831512451175, 79.8}, rot = {-0.0037029010709375, 0.0042938203550875, 0.87610691785812, 0.48208355903625} },
  { pos = {48.256, 146.19310760498, 79.8}, rot = {-0.0043562110513449, 0.0023561185225844, 0.41652184724808, 0.90911221504211} },
  { pos = {53.756, 128.816146850585, 79.8}, rot = {-0.0056724539026618, 0.0052379164844751, 0.72910284996033, 0.68436068296432} } 
}

GameData.blueSpawnpoints = {
  { pos = {-3.5, 128.816146850585, 79.8}, rot = {-0.0047647133469582, -0.0031621882226318, -0.70126289129257, 0.7128798365593} },
  { pos = {2, 146.19310760498, 79.8}, rot = {-0.0055739423260093, -0.0026658994611353, -0.48810976743698, 0.87276041507721} },
  { pos = {2, 112.831512451175, 79.8}, rot = {0.0026601643767208, 0.0041617965325713, 0.87210351228714, -0.48929646611214} }
}

-- GameData functions
GameData.hideBall = function()
  local ballVehicle = vehicles[GameData.ballVehicleId]
  if ballVehicle then
    ballVehicle:setPositionRotation(GameData.ballSpawnpoint[1],  GameData.ballSpawnpoint[2], GameData.ballSpawnpoint[3] - 100, 0, 0, 0, 0)
    ballVehicle:reset()  
  end
end

GameData.respawnBall = function()
  local ballVehicle = vehicles[GameData.ballVehicleId]
  if ballVehicle then
    ballVehicle:setPositionRotation(GameData.ballSpawnpoint[1], GameData.ballSpawnpoint[2], GameData.ballSpawnpoint[3], 0, 0, 0, 0)
    ballVehicle:reset()  
  end
end

GameData.getBallPosition = function()
  local ballVehicle = vehicles[GameData.ballVehicleId]
  if ballVehicle then
    local transform = ballVehicle:getTransform()
    local pos = transform:getPosition()
    return pos
  else
    return {0,0,0}
  end
end

GameData.reset = function()
  GameData.teams[TEAM_RED].score = 0
  GameData.teams[TEAM_BLUE].score = 0
  GameData.teams[TEAM_RED].participants = {}
  GameData.teams[TEAM_BLUE].participants = {}
  GameData.participants = {}
end

GameData.deletePlayer = function(client_id)
  GameData.participants[client_id] = nil
  for _,team in pairs(GameData.teams) do
    team.participants[client_id] = nil
  end
end

GameData.createPlayer = function(client_id)
  local blPlayerPrototype = {
    client_id = client_id,
    team = TEAM_NOBODY,
    stuckTime = 0,
    updateCount = 0,
    updateCounter = 0,
    lastPosition = {0,0,0},
    position = {0,0,0},
    velocity = {0,0,0},
    angVelocity = {0,0,0,0},
    spawnPosition = {0,0,0},
    spawnRotation = {0,0,0,0}
  }
  
  blPlayerPrototype.getConnection = function()
    return getConnection(blPlayerPrototype.client_id)
  end
  
  blPlayerPrototype.getName = function()
    return blPlayerPrototype.getConnection():getName()
  end
  
  blPlayerPrototype.getName = function()
    return blPlayerPrototype.getConnection():getName()
  end
  
  blPlayerPrototype.getVehicle = function()
    local rVehicles = {}
    for vehicle_id, vehicle in pairs(vehicles) do
      if vehicle:getData():getOwner() == blPlayerPrototype.client_id and vehicle_id ~= GameData.ballVehicleId then
        return vehicle
      end
    end
    return nil
  end
  
  blPlayerPrototype.setSpawn = function(pos, rot)
    blPlayerPrototype.spawnPosition = pos
    blPlayerPrototype.spawnRotation = rot
  end
  
  blPlayerPrototype.resetVehicle = function()
    local vehicle = blPlayerPrototype.getVehicle()
    if vehicle == nil then return end
    
    local x = blPlayerPrototype.spawnPosition[1]
    local y = blPlayerPrototype.spawnPosition[2]
    local z = blPlayerPrototype.spawnPosition[3]
    local rx = blPlayerPrototype.spawnRotation[1]
    local ry = blPlayerPrototype.spawnRotation[2]
    local rz = blPlayerPrototype.spawnRotation[3]
    local rw = blPlayerPrototype.spawnRotation[4]
    
    vehicle:setPositionRotation(x, y, z, rx, ry, rz, rw)
    vehicle:reset()
  end
  
  blPlayerPrototype.distance = function(otherPlayer)
    local vehicle1 = blPlayerPrototype.getVehicle()
    local vehicle2 = otherPlayer.getVehicle()
    
    if vehicle1 ~= nil and vehicle2 ~= nil then
      return vehicleDistance(vehicle1, vehicle2)
    else
      return math.huge
    end
  end
  
  blPlayerPrototype.getVehicles = function()
    local rVehicles = {}
    for _, vehicle in pairs(vehicles) do
      if vehicle:getData():getOwner() == client_id then table.insert(rVehicles, vehicle) end
    end
    return rVehicles
  end
  
  blPlayerPrototype.setVehicleFocus = function()
    local vehicle = blPlayerPrototype.getVehicle()
    if vehicle == nil then return end
    
    local ingameId = vehicle:getData():getInGameID()
    blPlayerPrototype.getConnection():sendLua("local veh = be:getObjectByID(" .. tostring(ingameId) .. ") be:enterVehicle(0, veh)")
  end

  blPlayerPrototype.zeroVehicleThings = function()
    blPlayerPrototype.stuckTime = 0
    blPlayerPrototype.velocity = {0, 0, 0}
    blPlayerPrototype.angVelocity = {0, 0, 0}
    blPlayerPrototype.position = {0, 0, 0}
    blPlayerPrototype.lastPosition = {0, 0, 0}
    blPlayerPrototype.predictedPosition = {0, 0, 0}
  end
  
  blPlayerPrototype.update = function(dt)
    local lastUpdateCounter = blPlayerPrototype.updateCounter
    blPlayerPrototype.updateCounter = lastUpdateCounter + dt
    local updateTimeDifference = blPlayerPrototype.updateCounter - lastUpdateCounter
    
    local client_id = blPlayerPrototype.client_id
    local client = blPlayerPrototype.getConnection()
    local vehicleId = vehicleIdWrapper(getConnection(client_id):getCurrentVehicle())
    
    if not vehicleId then 
      blPlayerPrototype.zeroVehicleThings()
      return
    end
    
    local vehicle = vehicles[vehicleId]
    if not vehicle then 
      blPlayerPrototype.zeroVehicleThings()
      return 
    end
    
    -- Do the updates
    local transform = vehicle:getTransform()
    if not transform then
      blPlayerPrototype.zeroVehicleThings()
      return 
    end

    local vel = transform:getVelocity()
    local angVel = transform:getAngularVelocity()
    local pos = transform:getPosition()
    
    local lastPosition = blPlayerPrototype.position
    
    blPlayerPrototype.velocity = vel
    blPlayerPrototype.position = pos
    blPlayerPrototype.angVelocity = angVel
    
    if blPlayerPrototype.updateCount == 0 then
      blPlayerPrototype.lastPosition = pos
    else 
      blPlayerPrototype.lastPosition = lastPosition
    end
    
    local velocityMagnitude = vecLen(vel)
    if velocityMagnitude < 2.2 then
      blPlayerPrototype.stuckTime = blPlayerPrototype.stuckTime + dt
    else
      blPlayerPrototype.stuckTime = 0
    end  
    
    blPlayerPrototype.updateCount = blPlayerPrototype.updateCount + 1
  end
  
  return blPlayerPrototype
end

-- CONFIG
local function loadOrCreateConfig()
  local config = readJsonFile("ballgame_config.json")
  local configExists = config ~= nil
  
  if not configExists then
    config = {["Limit Type"] = "Time", ["Time Limit"] = 300, ["Goal Limit"] = 3}
    writeJsonFile("ballgame_config.json", config)
  end
  
  -- apply values
  local limitTypeLower = (config["Limit Type"] or "None"):lower()
  if limitTypeLower == "time" then
    GameData.limitType = LIMITTYPE_TIME
  elseif limitTypeLower == "score" or limitTypeLower == "goals" or limitTypeLower == "goal" then
    GameData.limitType = LIMITTYPE_SCORE
  elseif limitTypeLower == "none" then
    GameData.limitType = LIMITTYPE_NONE
  else
    print("[Soccar] Unknown Limit Type: " .. limitTypeLower)
  end
  
  local timeLimit = tonumber(config["Time Limit"] or "0")
  GameData.timeLimit = timeLimit
  
  local scoreLimit = tonumber(config["Goal Limit"] or "0")
  GameData.scoreLimit = scoreLimit
  
  print("[Soccar] Config loaded")
end

-- HELPERS
local function sendInstructions(client)
  local helpMsg = "Welcome to BeamNG Car Soccer!\n\n" ..
  "How to play:\n"..
  "ONE PLAYER must spawn a ball, and type /setball, as well as spawning their vehicle normally.\n"..
  "Spawn your vehicle, and set your team by doing /team red or /team blue..\n\n"
  
  if GameData.limitType == LIMITTYPE_TIME then
    helpMsg = helpMsg .. "The game ends once " .. tostring(GameData.timeLimit) .. " seconds have passed.\n\n"
  elseif GameData.limitType == LIMITTYPE_SCORE then
    helpMsg = helpMsg .. "The game ends once " .. tostring(GameData.scoreLimit) .. " goals are reached for one team.\n\n"
  else
    helpMsg = helpMsg .. "The game never ends.\n\n"
  end
  
  helpMsg = helpMsg .. "The game will start once everyone has assigned a team."
  sendChatMessage(client, helpMsg)
end

-- MISC
local function onVehicleFirstSpawned(vehicle_id, client_id)
  -- Send instructions
  local connection = getConnection(client_id)
  sendInstructions(connection)
end

local function onVehicleSpawned(vehicle_id, client_id)
  StateManager.onVehicleSpawned(vehicle_id, client_id)
end

-- HOOKS
hooks.register("OnPlayerConnected", "CSC_ConnectedHook", function(client_id)
  StateManager.onPlayerConnected(client_id)
end)

hooks.register("OnPlayerDisconnected", "CSC_DisconnectedHook", function(client_id)
  hasSpawnedMap[client_id] = nil
  GameData.deletePlayer(client_id)
  StateManager.onPlayerDisconnected(client_id)
end)

hooks.register("OnVehicleSpawned", "CSC_SpawnedHook", function(vehicle_id, client_id)
  if not hasSpawnedMap[client_id] then
    hasSpawnedMap[client_id] = true
    StateManager.onVehicleFirstSpawned(vehicle_id, client_id)
    onVehicleFirstSpawned(vehicle_id, client_id)
  end
  onVehicleSpawned(vehicle_id, client_id)
end)

hooks.register("OnVehicleRemoved", "CSC_DeSpawnedHook", function(vehicle_id, client_id)
  if vehicle_id == GameData.ballVehicleId then
    GameData.ballVehicleId = -1
  end
  StateManager.onVehicleRemoved(vehicle_id, client_id)
end)

hooks.register("OnVehicleResetted", "CSC_ResetHook", function(vehicle_id, client_id)
  StateManager.onVehicleReset(vehicle_id, client_id)
end)

hooks.register("Tick", "CSC_Tick", function()
  local dt = 1 / SERVER_TICKRATE
  Scheduler.update(dt)
  StateManager.update(dt)
end)

hooks.register("OnStdIn", "CSC_Debug", function(str)
    if str == "/debug_on" or str == "debug_on" then GameData.DEBUG_MODE = true end
    if str == "/debug_off" or str == "debug_off" then GameData.DEBUG_MODE = false end
    if str == "reload" or str == "/reload" then loadOrCreateConfig() end
end)

hooks.register("OnChat", "CSC_Chat", function(client_id, message)
  if GameData.DEBUG_MODE then
    if message == "/debug_off" then GameData.DEBUG_MODE = false return "" end
    if message == "/pg" then StateManager.switchToState(GAMESTATE_POSTGAME) return "" end
    if message == "/l" then StateManager.switchToState(GAMESTATE_LOBBY) return ""  end
    if message == "/nogame" then StateManager.switchToState(GAMESTATE_NONE) return "" end
  end
  
  local chatMessageRetVal = StateManager.onChatMessage(client_id, message)
  if chatMessageRetVal then return chatMessageRetVal end
  
  local messageLower = message:lower()
  if messageLower == "/help" or messageLower == "/instructions" then
    sendInstructions(getConnection(client_id))
    return ""
  end
end)

-- ON SCRIPT LOAD
StateManager.switchToState(GAMESTATE_LOBBY)
loadOrCreateConfig()
broadcastChatMessage("=== Soccar Addon reloaded, if you're in the lobby, you must reassign a team ===")