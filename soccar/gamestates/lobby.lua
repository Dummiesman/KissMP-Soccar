local M = {}
M.name = "Lobby"

local readyTimer = 0
local lobbyTeamMap = {}

-- team related stuff
local function getFirstIdOnTeam(team)
  for client_id, team2 in pairs(lobbyTeamMap) do
    if team2 == team then return client_id end
  end
  return nil
end

local function getTeamMemberCount(team)
  local c = 0
  for _,team2 in pairs(lobbyTeamMap) do
    if team2 == team then c = c + 1 end
  end
  return c
end

local function allClientsOnTeams()
  local cc = 0
  local ctc = 0
  for client_id, connection in pairs(getConnections()) do
    if lobbyTeamMap[client_id] then ctc = ctc + 1 end
    cc = cc + 1
  end
  return cc == ctc
end

local function getClientsTableWithoutTeam()
  local t = {}
  for client_id, connection in pairs(getConnections()) do
    if not lobbyTeamMap[client_id] then table.insert(t, client_id) end
  end
  return t
end

local function checkTeamFull(team)
  local limit = TEAM_LIMITS[team]
  if not limit then return true end
  if limit < 0 then return false end
  return getTeamMemberCount(team) >= limit
end

local function setTeam(client, team)
    local currentTeam = lobbyTeamMap[client:getID()]
    local newTeamName = TEAM_NAMES[team]
    lobbyTeamMap[client:getID()] = team
    
    if currentTeam and currentTeam ~= team then
      local currentTeamName = TEAM_NAMES[currentTeam]
      sendChatMessage(client, "Changed team from " .. currentTeamName .. " to " .. newTeamName .. ".", {r=1,g=1})
    elseif currentTeam and currentTeam == team then
      sendChatMessage(client, "You're already on the " .. newTeamName .. " team.", {r=1,g=1})
    else
      sendChatMessage(client, "Set team to " .. newTeamName .. ".", {r=1,g=1})
    end
end

-- game start function
local function startGame()
  -- first off, move someone off their team if 
  -- the other team is empty
  local cc = getConnectionCount()
  if cc > 1 then
    local rc = getTeamMemberCount(TEAM_RED)
    local bc = getTeamMemberCount(TEAM_BLUE)
    if rc == cc or bc == cc then
      -- We must reassign someone
      if rc == cc then
        local id = getFirstIdOnTeam(TEAM_RED)
        lobbyTeamMap[id] = TEAM_BLUE
        sendChatMessage(getConnection(id), "*** Your team has been reassigned because everyone was on one team. Your new team is Blue ***", {r=1,g=1})
      else
        local id = getFirstIdOnTeam(TEAM_BLUE)
        lobbyTeamMap[id] = TEAM_RED
        sendChatMessage(getConnection(id), "*** Your team has been reassigned because everyone was on one team Your new team is Red ***", {r=1,g=1})
      end
    end
  end

  -- clear existing game participants leftover from any previous runs
  GameData.reset()
  
  -- add everyone to participants list
  for client_id, _ in pairs(getConnections()) do
    local participant = GameData.createPlayer(client_id)
    GameData.participants[client_id] = participant
    GameData.teams[lobbyTeamMap[client_id]].participants[client_id] = participant
    GameData.participants[client_id].team = lobbyTeamMap[client_id]
  end
  
  -- remove players 2nd+ vehicles
  local removeVehiclesTable = {}
  for client_id, _ in pairs(getConnections()) do
    local vc = 0
    for vehicle_id, vehicle in pairs(vehicles) do
      if vehicle:getData():getOwner() == client_id and vehicle:getData():getID() ~= GameData.ballVehicleId then
        vc = vc + 1
        if vc > 1 then
          table.insert(removeVehiclesTable, vehicle)
        end
      end
    end
  end
  for _, vehicle in pairs(removeVehiclesTable) do
    vehicle:remove()
  end
  
  -- move to running state
  StateManager.switchToState(GAMESTATE_RUNNING)
end

-- state stuff
local function onPlayerDisconnected(client_id)
  lobbyTeamMap[client_id] = nil
end

local function onEnterState()
  lobbyTeamMap = {}
  readyTimer = 0
end

local function onChatMessage(client_id, message)
  local messageLower = message:lower()
  
  -- debug
  if GameData.DEBUG_MODE then
    if message == "/s" then  startGame() return ""  end
  end
  
  -- team assignment
  if messageLower == "/team blue" or messageLower == "/blue" then
    if not checkTeamFull(TEAM_BLUE) then
      setTeam(getConnection(client_id), TEAM_BLUE)
    else
      sendChatMessage(getConnection(client_id), "This team is full", {r=1})
    end
    return ""
  end
  if messageLower == "/team red" or messageLower == "/red" then
    if not checkTeamFull(TEAM_RED) then
      setTeam(getConnection(client_id), TEAM_RED)
    else
      sendChatMessage(getConnection(client_id), "This team is full", {r=1})
    end
    return ""
  end
  if messageLower == "/random" then
    local r = math.random()
    local attemptTeam = nil
    local alternateTeam = nil
    if r > 0.5 then
      attemptTeam = TEAM_RED
      alternateTeam = TEAM_BLUE
    else
      attemptTeam = TEAM_BLUE
      alternateTeam = TEAM_RED
    end
    
    if checkTeamFull(attemptTeam) then
      attemptTeam = alternateTeam
    end
    
    if checkTeamFull(attemptTeam) then
      -- can't assign any team?
      sendChatMessage(getConnection(client_id), "All teams are full", {r=1})
    else
      sendChatMessage(getConnection(client_id), "The randomizer assigns you to the " .. TEAM_NAMES[attemptTeam] .. " team.", {r=1, g=1})
      setTeam(getConnection(client_id), attemptTeam)
    end 
    return ""
  end
  
  -- ball assignment
  if messageLower == "/setball" or messageLower == "/ball" then
    -- get clients active vehicle and set it as ballVehicleId
    local client = getConnection(client_id)
    local vehicleId = vehicleIdWrapper(client:getCurrentVehicle())
    if not vehicleId then
      sendChatMessage(getConnection(client_id), "Failed to set ball vehicle", {r=1})
      return ""
    end
    
    local vehicle = vehicles[vehicleId]
    if not vehicle then 
      sendChatMessage(getConnection(client_id), "Failed to set ball vehicle", {r=1})
      return ""
    end 
    
    sendChatMessage(getConnection(client_id), "Ball vehicle set", {g=1})
    GameData.ballVehicleId = vehicle:getData():getID()
    return ""
  end
end

local function update(dt)
  local ready = allClientsOnTeams()
  local connectionCount = getConnectionCount()
  if ready and connectionCount >= 2 then
    -- if the timer is 0, we've just entered ready state. Notify clients.
    local startTime = GameData.DEBUG_MODE and 5 or 10
    if readyTimer == 0 then
      broadcastChatMessageAndToast("The game will start in " .. tostring(startTime) .. " second(s)", {r=1,g=1})
    end
    readyTimer = readyTimer + dt
    
    -- start game after timer ends
    if readyTimer > startTime then
      startGame()
    end
  else
    -- if the timer is not 0, we *were* in ready state, and something happened
    if readyTimer ~= 0 then
      broadcastChatMessageAndToast("Start timer interrupted. All clients are no longer ready.")
    end
    
    -- notify players that they need a team
    local lobbyNotifTimer = StateManager.timeInState % 60
    local lobbyNotifTimerNext = (StateManager.timeInState + dt) % 60
    if lobbyNotifTimerNext < lobbyNotifTimer then 
      broadcastChatMessage("In lobby mode. Waiting for all players to assign a team.")
      
      -- get the players who have no team
      local noTeamMap = getClientsTableWithoutTeam()
      local noTeamNameMap = {}
      for _,id in pairs(noTeamMap) do
        table.insert(noTeamNameMap, getConnection(id):getName())
      end
      broadcastChatMessage("The following players have not assigned a team yet: " .. strTableToStr(noTeamNameMap), {r=1})
    end
    
    --
    readyTimer = 0
  end
end

M.onEnterState = onEnterState
M.onChatMessage = onChatMessage
M.onPlayerDisconnected = onPlayerDisconnected
M.update = update

return M