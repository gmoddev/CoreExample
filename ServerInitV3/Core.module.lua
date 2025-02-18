--[[
    Not_Lowest
    Updated: 2/17/2025 9:49pm EST
    Description: Handles all logic and loading on both the client and the server. 
    Made to be extensible and safe while maintaining functionality.

	Update 2/17/25
	- Re-organized script
	- Organized helper functions
	- Added caching to LoadServices
	
    Todo:
    - Redo helper functionality to be similar to managers, passing services along with it
--]]

local DoLogStage = script.DoPrintSuccess.Value
local HelperFuncs = require(script.HelperFunctions)

return function(script)
	--// Services
	local RunService = game:GetService("RunService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")

	--// Configuration
	local Client_Or_Server = RunService:IsServer()
	local COSText = Client_Or_Server and "Server" or "Client"
	local IsStudio = RunService:IsStudio()

	--// Core Table
	local Core = { Services = {}, Helpers = {}, Managers = {}, Settings = {} }
	local PlayerAdded = {}
	Core.__index = Core

	--// Logging Functions
	local print, warn, LogStage = HelperFuncs.print, HelperFuncs.warn, HelperFuncs.LogStage

	--// Loading Functions
	local LoadManagers, LoadHelpers, LoadServices = HelperFuncs.LoadManagers, HelperFuncs.LoadHelpers, HelperFuncs.LoadServices

	--// Initialization
	local function Init()
		if _G["GameLoaded"] then
			warn("Trying to load game when it's already loaded on", COSText)
			return
		end

		LogStage("Initializing")

		-- Load Services
		LogStage("Loading Services")
		Core.Services = LoadServices()

		-- Load Helpers
		LogStage("Loading Helpers")
		local HelpersFolder = script:FindFirstChild("Helpers")
		if HelpersFolder then
			Core.Helpers = LoadHelpers(HelpersFolder, script)
		end

		-- Load Managers
		LogStage("Loading Managers")
		local ManagersFolder = script:FindFirstChild("Managers")
		if ManagersFolder then
			Core.Managers = LoadManagers(ManagersFolder, Core.Helpers, Core.Services, PlayerAdded)
		end

		-- Insert print and warn into Core.Helpers
		Core.Helpers.print = print
		Core.Helpers.warn = warn

		-- Set global flag for GameLoaded
		_G["GameLoaded"] = true

		LogStage("Successfully completed load")

		return setmetatable(Core, Core)
	end

	--// PlayerAdded Handling
	local function PlayerAddedFunc(plr)
		for _, func in ipairs(PlayerAdded) do
			func(plr)
		end
	end

	-- Initialize Core
	Init()

	-- If running on the server, connect PlayerAdded event
	if RunService:IsServer() then
		for _, player in ipairs(Players:GetPlayers()) do
			PlayerAddedFunc(player)
		end

		Players.PlayerAdded:Connect(PlayerAddedFunc)
	end

	return Core
end
