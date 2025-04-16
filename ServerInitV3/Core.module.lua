--[[
Not_Lowest
Updated: 2/3/2025 8:13pm EST
Description: Handles all logic and loading on both the client and the server. Made to be extensible and safe while maintaining functionality.

Todo:

Redo helper functionality to be similar to managers, and passing services along with it
]]

local DoLogStage = script.DoPrintSuccess.Value
local HelperFuncs = require(script.HelperFunctions)

return function(script)
	local RunService = game:GetService("RunService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService('Players')

	local Client_Or_Server = RunService:IsServer()
	local COSText = Client_Or_Server and "Server" or "Client"
	local IsStudio = RunService:IsStudio()

	local Core = {}
	local PlayerAdded = {}
	
	Core.__index = Core

	local print = HelperFuncs.print
	local warn = HelperFuncs.warn
	local LogStage = HelperFuncs.LogStage

	local LoadManagers = HelperFuncs.LoadManagers
	local LoadHelpers = HelperFuncs.LoadHelpers
	local LoadServices = HelperFuncs.LoadServices

	local function Init()
		if _G["GameLoaded"] then
			warn("Trying to load game when its already loaded on ", COSText)
			return
		end
		
		LogStage("Initalizing")
		LogStage("Loading Services")
		Core.Services = LoadServices()
		LogStage("Loading Helpers")
		local Helpers = script:FindFirstChild("Helpers")
		Core.Helpers = {}
		if Helpers then
			Core.Helpers = LoadHelpers(Helpers,script)
		end
		
		Core.Helpers.CoreService = HelperFuncs
		
		LogStage("Loading Managers")
		local ManagersReturn = LoadManagers(script:FindFirstChild("Managers"),Core.Helpers,Core.Services)
		
		Core.Managers = ManagersReturn.Managers
		PlayerAdded = ManagersReturn.PlayerAdded
		Core.Settings = {}
		
		--// Insert print and warn into core
		Core.Helpers.print = print
		Core.Helpers.warn = warn
		--// Set a global value of GameLoaded to true, so certain things relying on it can finish loading
		_G["GameLoaded"] = true
		LogStage("Successfully completed load")
		return setmetatable(Core, Core)
	end
	
	local function PlayerAddedFunc(plr)
		for i,v in pairs(PlayerAdded) do
			v(plr)
		end
		
	end
	
	Init()

	if RunService:IsServer() then
		for i,v in ipairs(Players:GetPlayers()) do
			PlayerAddedFunc(v)
		end
		
		Players.PlayerAdded:Connect(PlayerAddedFunc)
	end

	return Core

end