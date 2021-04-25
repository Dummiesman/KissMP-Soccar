local M = {}
local tasks = {}
local timer = 0

local function schedule(fn, afterTime, killCondition)
	local task = {}
	task.callback = fn
	task.time = afterTime
  task.killCondition = killCondition
	table.insert(tasks, task)
end

local function clear()
  tasks = {}
end

local function update(dt)
	local kRemove = {}
	for k, task in pairs(tasks) do
		local killed = false
    task.time = task.time - dt
    if task.killCondition then
      if task.killCondition() then
        killed = true
        table.insert(kRemove, k)
      end
    end
		if task.time <= 0 and not killed then
			task.callback()
			table.insert(kRemove, k)
		end
	end
	
	for _, key in pairs(kRemove) do
		tasks[key] = nil
	end
end

M.clear = clear
M.schedule = schedule
M.update = update
return M