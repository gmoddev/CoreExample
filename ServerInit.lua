local ServerCooldownEvents = {}
local InvalidModules = {"Datastore2"}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = game:GetService("ReplicatedStorage").ServerRemotes
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Service = require(ReplicatedStorage.Modules.Services)

Players.PlayerAdded:Connect(function(plr)
	_G[plr.UserId.."-ackey"] = ""
	_G[plr.UserId.."-responsetimer"] = 10
end)

local function ServerStart()
	for i, StartModule in pairs(script:GetChildren()) do
		if InvalidModules[StartModule.Name] then else
			local Success, ErrorMsg = pcall(function()
				require(StartModule):Initialize()
			end)
			
			if not Success then
				warn(ErrorMsg)
			end
		end
	end
end

local function ConnectCooldown(UserId, Indicator, Preasure)
	if not ServerCooldownEvents[Indicator] then
		ServerCooldownEvents[Indicator] = {}
	end 
	if ServerCooldownEvents[Indicator][UserId] then
		return true
	else
		ServerCooldownEvents[Indicator][UserId] = true
		delay(Preasure, function()
			ServerCooldownEvents[Indicator][UserId] = false
		end)
		return false
	end
end

--[[
RemoteName.OnServerEvent:Connect(function(Player, Name, TLDRTitle, BoxIntel)
	if ConnectCooldown(Player.UserId, Name, 120) then
		return
	end
	
end)
]]

ServerStart()
