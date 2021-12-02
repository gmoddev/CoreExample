--[[
Author: Not_Lowest
Description: Better version of the previous server init i uploaded, has a lot more customablity and easy to understand

]]
local warn,oldwarn = warn,warn
local error,olderror = error,error
local print,oldprint = print,print

Players = game:GetService("Players")
ReplicatedStorage = game:GetService("ReplicatedStorage")

Modules = script:FindFirstChild("Modules")
LoadedModules = {}

NonInitFunction = {"TweenService"} -- modules that wont run :Init()
RunPlrAddedFunction = {} -- Modules that will run :PlayerAdded(), should be automatically added


function print(str)
	if type(str) == "string" then
		oldprint(":: Server Core :: " .. str)
	else
		oldprint(":: Server Core Start ::")
		oldprint(str)
		oldprint(":: Server Core End ::")
	end
end

function error(str)
	if type(str) == "string" then
		olderror(":: Server Core :: " .. str)
	else
		olderror(":: Server Core Start ::")
		olderror(str)
		olderror(":: Server Core End ::")
	end
end

function warn(str)
	if type(str) == "string" then
		oldwarn(":: Server Core :: " .. str)
	else
		oldwarn(":: Server Core Start ::")
		oldwarn(str)
		oldwarn(":: Server Core End ::")
	end
end

for _, module in ipairs(Modules:GetChildren()) do
	coroutine.resume(coroutine.create(function()
		if not table.find(NonInitFunction,module.Name) then
			local success,err = pcall(function()
				local Module = require(module)

				if table.find(Module,"PlayerAdded") then
					table.insert(RunPlrAddedFunction,module.Name)
				end

				local s,e = pcall(function()
					Module:Init()
				end)
				if s then
					warn("Started module: " .. module.Name)
				else
					warn("Failed to start module: ".. module.Name .. " for the reason: ".. e)
				end
			end)
			if not success then
				warn("Module: ".. module.Name.. " failed to load because " .. err)
			end
		else
			local s,e = pcall(function()
				require(module)
			end)
			if s then
				warn("Started module: " .. module.Name)
			else
				warn("Failed to start module: ".. module.Name .. " for the reason: ".. e)
			end
		end
	end))
end
Players.PlayerAdded:Connect(function(plr)
	for _, Func in pairs(RunPlrAddedFunction) do
		require(Modules:FindFirstChild(Func)):PlayerAdded(plr)
	end
end)