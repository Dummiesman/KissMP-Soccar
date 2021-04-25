local M = {}
M.name = "Playing"

local scoreFlag = false
local oneMinuteFlag = false
local overtimeFlag = false
local gameTimeElapsed = 0

-- substate types
local SUBSTATE_PLAYING = 0
local SUBSTATE_COUNTDOWN = 1
local SUBSTATE_POSTGOAL = 2

-- current substate
local substate = SUBSTATE_COUNTDOWN

-- countdown
local function doCountdownUi()
  Scheduler.schedule(function() showOnscreenMessageAll("3", 1) end, 1)
  Scheduler.schedule(function() showOnscreenMessageAll("2", 1) end, 2)
  Scheduler.schedule(function() showOnscreenMessageAll("1", 1) end, 3)
  Scheduler.schedule(function() showOnscreenMessageAll("GO", 1) end, 4)
end

-- helpers
local function areScoresSeven()
  local sc_red = GameData.teams[TEAM_RED].score
  local sc_blue = GameData.teams[TEAM_BLUE].score
  return sc_red == sc_blue
end

local function getWinningTeamInfo()
  local returnScore = -1
  local returnTeamId = TEAM_NOBODY
  
  for team_id, team_data in pairs(GameData.teams) do
    if team_data.score > returnScore then
      returnScore = team_data.score
      returnTeamId = team_id
    end
  end
  
  return {returnScore, returnTeamId}
end

local function checkWinConditions()
  -- no win conditions if this is set
  if GameData.DEBUG_MODE and not GameData.enableWinning then return false end
  
  -- check if it's game over (nobody on a team)
  if not GameData.DEBUG_MODE then
    for team_id, team_data in pairs(GameData.teams) do
      local pc = 0
      for _, participant in pairs(team_data.participants) do
        pc = pc + 1
      end
      
      -- 0 players on a team
      if pc == 0 then
        if team_id == TEAM_BLUE then GameData.winningTeam = TEAM_RED end
        if team_id == TEAM_RED then GameData.winningTeam = TEAM_BLUE end
        
        StateManager.switchToState(GAMESTATE_POSTGAME)
        return true
      end
    end
  end
  
  local tInfo = getWinningTeamInfo()
  local tScore = tInfo[1]
  local tId = tInfo[2]
  
  -- check if it's game over (timer condition)
  if GameData.limitType == LIMITTYPE_TIME then
    if gameTimeElapsed >= GameData.timeLimit then
      -- check if teams are tied
      -- if not, win condition passes
      if not areScoresSeven() then
        -- set winning team
        GameData.winningTeam = tId
        StateManager.switchToState(GAMESTATE_POSTGAME)
        return true
      end
    end
  end
  
  -- check if it's game over (score)
  if GameData.limitType == LIMITTYPE_SCORE then
    if tScore >= GameData.scoreLimit then
      GameData.winningTeam = tId
      StateManager.switchToState(GAMESTATE_POSTGAME)
      return true
    end
  end
  
  --
  return false
end

-- spawning
local function spawnParticipant(participant, spawnData)
  participant.setSpawn(spawnData["pos"], spawnData["rot"])
  participant.resetVehicle()
end

local function spawnParticipants()
  local blueParticipants = {}
  local redParticipants = {}
  
  for client_id, participant in pairs(GameData.participants) do
    local team = participant.team
    if team == TEAM_RED then table.insert(redParticipants, participant) end
    if team == TEAM_BLUE then table.insert(blueParticipants, participant) end
  end
  
  local shuffledRedSpawns = shuffleList(GameData.redSpawnpoints)
  local i = 1
  for _, spawnData in pairs(shuffledRedSpawns) do
    if i <= #redParticipants then
      spawnParticipant(redParticipants[i], spawnData)
    end
    i = i + 1
  end
  
  local shuffledBlueSpawns = shuffleList(GameData.blueSpawnpoints)
  i = 1
  for _, spawnData in pairs(shuffledBlueSpawns) do
    if i <= #blueParticipants then
      spawnParticipant(blueParticipants[i], spawnData)
    end
    i = i + 1
  end
  
  -- run out of spawns / no spawns
  local nullSpawnData = {pos={0,0,0},rot={0,0,0,0}}
  if #shuffledRedSpawns < #redParticipants then
    for xx=#shuffledRedSpawns + 1,#redParticipants,1 do
      spawnParticipant(redParticipants[i], nullSpawnData)
    end
  end
  if #shuffledBlueSpawns < #blueParticipants then
    for xx=#shuffledBlueSpawns + 1,#blueParticipants,1 do
      spawnParticipant(blueParticipants[i], nullSpawnData)
    end
  end
end

-- substates
local function enterRunningSubstate()
  substate = SUBSTATE_PLAYING
  scoreFlag = false
  setVehicleFreezeAll(false)
end

local function enterCountdownSubstate()
  substate = SUBSTATE_COUNTDOWN
  countdownSubstateElapsed = 0
  doCountdownUi()
  Scheduler.schedule(function() enterRunningSubstate() end, 4)
  
  -- freeze vehicles and respawn everything
  spawnParticipants()
  GameData.respawnBall()
  setVehicleFreezeAll(true)  
end

local function enterPostGoalSubstate()
  substate = SUBSTATE_POSTGOAL
  setBulletTime(0.25)
  
  local schedulerFunction = function()
    -- check win conditions before entering countdown
    -- prevents "3 2 1 X Team wins!" for overtime and goals limit
    if checkWinConditions() then return end
    
    enterCountdownSubstate()
    setBulletTime(1)
  end
  
  Scheduler.schedule(schedulerFunction, 6)
end

-- score event
local function onBallScored(team)
  if scoreFlag then return end
  scoreFlag = true
  
  -- add score to teamData
  local teamData = GameData.teams[team]
  teamData.score = teamData.score + 1
  
  -- show message
  local newScoreMsg = "Red score: " .. tostring(GameData.teams[TEAM_RED].score) .. ", Blue Score: " .. tostring(GameData.teams[TEAM_BLUE].score)
  local newScoreMsgCompact = "R: " .. tostring(GameData.teams[TEAM_RED].score) .. ", B: " .. tostring(GameData.teams[TEAM_BLUE].score)
  
  showOnscreenMessageAll(TEAM_NAMES[team] .. " Scored", 3)
  Scheduler.schedule(function() showOnscreenMessageAll(newScoreMsgCompact, 3) end, 3)

  broadcastChatMessage(TEAM_NAMES[team] .. " Scored")
  broadcastChatMessage(newScoreMsg)  
  
  -- enter post goal substate
  enterPostGoalSubstate()
end

-- statemgr stuff
local function onLeaveState()
  Scheduler.clear()
  setBulletTime(1.0)
end

local function onEnterState()
  setVehicleFocusAll()
  setScenarioUiAll()
  
  -- reset things
  oneMinuteFlag = false
  overtimeFlag = false
  scoreFlag = false
  gameTimeElapsed = 0

  --
  broadcastChatMessageAndToast("The game has started!", {r=1,g=1})
  
  -- do initial countdown
  enterCountdownSubstate()
end


local function onVehicleSpawned(vehicle_id, client_id)
   -- vehicle spawned while game running, freeze it..
   setVehicleFreeze(vehicle, true)
end

local function updateRunningSubstate_updateBall(dt)
   local ballPos = GameData.getBallPosition()
   
   -- function planeSide(vec, planePos, planeDir)
   local s1 = planeSide(ballPos, GameData.redNetPlane.pos, GameData.redNetPlane.dir)
   local s2 = planeSide(ballPos, GameData.blueNetPlane.pos, GameData.blueNetPlane.dir)
   local ballMinPenetration = 0.94
   
   if s1 then -- red net
    -- get how far the ball is in the goal
    local penetration = math.abs(planeDist(ballPos, GameData.redNetPlane.pos, GameData.redNetPlane.dir))
    if penetration >= ballMinPenetration then
      onBallScored(TEAM_BLUE)
    end
   end
   if s2 then -- blue net
    -- get how far the ball is in the goal
    local penetration = math.abs(planeDist(ballPos, GameData.blueNetPlane.pos, GameData.blueNetPlane.dir))
    if penetration >= ballMinPenetration then
      onBallScored(TEAM_RED)
    end
   end
end

local function updateRunningSubstate(dt)
  -- update participants
  for client_id, participant in pairs(GameData.participants) do
    participant.update(dt)
  end
  
  -- main game logic 
  checkWinConditions()
  updateRunningSubstate_updateBall(dt)
  
  -- 1 minute remaining on screen text
  if GameData.limitType == LIMITTYPE_TIME then
    local timeLeft = GameData.timeLimit - gameTimeElapsed
    if timeLeft <= 60 and not oneMinuteFlag then
      broadcastChatMessageAndToast("One minute remains!", {r=1,g=1})
      showOnscreenMessageAll("1 MIN", 3)
      oneMinuteFlag = true
    end
  end
  
  -- 5 second countdown on screen text
  if GameData.limitType == LIMITTYPE_TIME then
    local timeLeft = GameData.timeLimit - gameTimeElapsed
    local timeLeftNext = GameData.timeLimit - (gameTimeElapsed + dt)
    if timeLeft < 6 and timeLeft > 1 and math.floor(timeLeft) ~= math.floor(timeLeftNext) then
      local onScreenStr = tostring(math.floor(timeLeft))
      broadcastChatMessageAndToast(onScreenStr, {r=1,g=1})
      showOnscreenMessageAll(onScreenStr, 1)
    end
  end
  
  -- overtime handler
  if GameData.limitType == LIMITTYPE_TIME then
    if gameTimeElapsed > GameData.timeLimit and not overtimeFlag and areScoresSeven() then
      broadcastChatMessageAndToast("Overtime!", {r=1,g=1})
      showOnscreenMessageAll("Overtime", 3)
      GameData.hideBall()
      overtimeFlag = true
      enterPostGoalSubstate()
    end
  end
  
  -- update time elapsed
  gameTimeElapsed = gameTimeElapsed + dt
end

local function update(dt)
  if substate == SUBSTATE_PLAYING then
    updateRunningSubstate(dt)
  end
end

M.onLeaveState = onLeaveState
M.onEnterState = onEnterState
M.onVehicleSpawned = onVehicleSpawned
M.update = update

return M