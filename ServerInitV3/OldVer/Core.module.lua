--[[
Not_Lowest
Updated: 11/22/2025 8:28pm EST
Description: Handles all logic and loading on both the client and the server. Made to be extensible and safe while maintaining functionality.
]]

local DoLogStage = script.DoPrintSuccess.Value
local HelperFuncs = require(script.HelperFunctions)

local GameLoaded = false

return function(script)
	local RunService = game:GetService("RunService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService('Players')

	local Client_Or_Server = RunService:IsServer()
	local COSText = Client_Or_Server and "Server" or "Client"
	local IsStudio = RunService:IsStudio()

	local Core = {}
	local PlayerAdded = {}
	local CharacterAdded = {}

	Core.__index = Core

	local print = HelperFuncs.print
	local warn = HelperFuncs.warn
	local LogStage = HelperFuncs.LogStage

	local LoadManagers = HelperFuncs.LoadManagers
	local LoadHelpers = HelperFuncs.LoadHelpers
	local LoadServices = HelperFuncs.LoadServices

	local function Init()
		if GameLoaded then
			warn("Trying to load game when its already loaded on ", COSText)
			return
		end
		
		local self = setmetatable({}, Core)
		
		self.Loaded = false
		self.LoadEvent = Instance.new("BindableEvent")
		
		LogStage("Initalizing")
		LogStage("Loading Services")
		self.Services = LoadServices()
		LogStage("Loading Helpers")
		local Helpers = script:FindFirstChild("Helpers")
		self.Helpers = {}
		if Helpers then
			self.Helpers = LoadHelpers(Helpers,script,self.Services)
		end

		self.Helpers.CoreService = HelperFuncs

		LogStage("Loading Managers")
		local ManagersInst = script:FindFirstChild("Managers")
		if not ManagersInst then
			LogStage("Failed to load managers, instance doesnt exist")
			return 
		end
		
		local ManagersReturn = LoadManagers(ManagersInst,self)

		self.Managers = ManagersReturn.Managers
		PlayerAdded = ManagersReturn.PlayerAdded
		CharacterAdded = ManagersReturn.CharacterAdded

		self.Settings = {}

		self.Helpers.print = print
		self.Helpers.warn = warn
		
		GameLoaded = true
		_G["GameLoaded"] = true --// Backwards compatibility for legacy scripts
		self.LoadEvent:Fire()
		
		LogStage("Successfully completed load")
		return self
	end

	local function CharacterAddedFunc(char,plr)
		for i,v in pairs(CharacterAdded) do
			task.spawn(v,char,plr)
		end
	end

	local function PlayerAddedFunc(plr)
		for i,v in pairs(PlayerAdded) do
			task.spawn(v,plr)
		end

		plr.CharacterAdded:Connect(function(char)
			CharacterAddedFunc(char,plr)
		end)

	end

	local ToReturn = Init()

	if RunService:IsServer() then
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


	return ToReturn

end