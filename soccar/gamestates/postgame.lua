local M = {}
M.name = "PostGame"

local function onLeaveState()
  -- set everyone's UI back to normal
  setNormalUiAll()
end

local function update(dt)
  local nextTimeInState = StateManager.timeInState + dt
  if math.floor(StateManager.timeInState) ~= math.floor(nextTimeInState) and math.floor(nextTimeInState) == 1 then
    local winningTeamName = TEAM_NAMES[GameData.winningTeam]
    showOnscreenMessageAll(winningTeamName .. " Wins", 4)
    broadcastToast(winningTeamName .. " Wins")
  end
  
  if StateManager.timeInState >= 10 then
    broadcastChatMessage("Game over. Changing game state back to lobby mode.", {r=1,g=1})
    StateManager.switchToState(GAMESTATE_LOBBY)
  end
end

M.onLeaveState = onLeaveState
M.update = update

return M