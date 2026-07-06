--[[
Not_Lowest
Updated: 4/4/26 2:17am EST
Description: Handles all logic and loading on both the client and the server. Made to be extensible and safe while maintaining functionality.

Helpers are technically sync modules, but kept for backwards compat
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

	local Core = {
		State = {
			IsLoaded = false
		}

	}
	local PlayerAdded = {}
	local CharacterAdded = {}

	Core.__index = Core

	local print = HelperFuncs.print
	local warn = HelperFuncs.warn
	local LogStage = HelperFuncs.LogStage

	local LoadManagers = HelperFuncs.LoadManagers
	local LoadHelpers = HelperFuncs.LoadHelpers
	local LoadServices = HelperFuncs.LoadServices

	local function CharacterAddedFunc(char,plr)
		for i,v in pairs(CharacterAdded) do
			task.spawn(v,char,plr)
		end
	end

	local function PlayerAddedFunc(plr)
		LogStage("Running player added for ", plr.Name)
		for i,v in pairs(PlayerAdded) do
			task.spawn(v,plr)
		end

		if plr.Character then
			CharacterAddedFunc(plr.Character,plr)
		end

		plr.CharacterAdded:Connect(function(char)
			CharacterAddedFunc(char,plr)
		end)

	end

	local function FinishInit()
		LogStage("Running final initalization")
		if RunService:IsServer() then
			LogStage("Running serverside player hooks")
			for i,v in ipairs(Players:GetPlayers()) do
				PlayerAddedFunc(v)
			end

			Players.PlayerAdded:Connect(PlayerAddedFunc)
		else
			local plr: Player = Players.LocalPlayer
			plr.CharacterAdded:Connect(function(char)
				CharacterAddedFunc(char,plr)
			end)
		end
	end

	local function Init()
		if Core.State and Core.State.IsLoaded then
			warn("Trying to load game when its already loaded on ", COSText)
			return Core
		end

		Core.State = {
			IsLoaded = false
		}

		LogStage("Initalizing")

		LogStage("Loading Services")
		Core.Services = LoadServices()

		LogStage("Loading Helpers")
		local Helpers = script:FindFirstChild("Helpers")
		Core.Helpers = {}

		if Helpers then
			Core.Helpers = LoadHelpers(Helpers, script)
		end

		--Core.Helpers.PlayerManager = PlayerManagerBootstrap(Core.Services)
		Core.Helpers.CoreService = HelperFuncs

		LogStage("Loading Managers")
		local Managers = script:FindFirstChild("Managers")
		if not Managers then
			warn("No Managers folder found under ", script:GetFullName())
		end

		local ManagersReturn = LoadManagers(Managers, Core.Helpers, Core.Services)

		Core.Managers = ManagersReturn.Managers
		PlayerAdded = ManagersReturn.PlayerAdded
		CharacterAdded = ManagersReturn.CharacterAdded

		Core.Settings = {}

		Core.Helpers.print = print
		Core.Helpers.warn = warn

		Core.State.IsLoaded = true

		FinishInit()

		script:SetAttribute(string.format("%s-Loaded",COSText), true)

		LogStage("Successfully completed load")

		return setmetatable(Core, Core)
	end


	Init()


	return Core

end
