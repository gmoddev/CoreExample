--[[
Not_Lowest
Library for core script, so it can be used as a base for other scripts

3/24/25 - Made LoadManagers NeverNested
6/8/25 - Made LoadManagers use a makeshift promise to prevent race conditions
2/9/26 - Made LoadServices lazyload. Rewrote type defs to apply (And are now a lot less complicated)
2/10/26- Move to XPCall (And rewrote managers)
4/4/26 - Implemented Promise, added built-in player manager, still deciding if I like the centralization
4/4/26 - Removed built in player manager, now shipped as a helper or SyncModule
]]

local DoLogStage = script.Parent.DoPrintSuccess.Value

--// Services Loading // TODO: Integrate this with lazy loading
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService('Players')

local Promise = require(script.Promise)

local Client_Or_Server = RunService:IsServer()
local COSText = Client_Or_Server and "Server" or "Client"

local oldprint = print
local oldwarn = warn
local olderror = error

local HelpersVar = nil

--// Type Defs
-- Type for Services Table (loaded via LoadServices) // Made so Gummi could copy and paste
-- Now that i've replaced predefined services with lazy loading. This is effectively useless.
export type Services = {
	[string]: any
}
-- Type for Managers Table (Loaded via LoadManagers)
export type Managers = {
	[string]: any 
}
-- Type for Helper Functions (Loaded via LoadHelpers)
export type SyncModules = {
	[string]: any

}
-- Type for Helper Functions (HelperFuncs)
export type HelperFuncs = {
	print: (any) -> (),
	warn: (any) -> (),
	LogStage: (any) -> (),
	LoadManagers: (Instance, { [string]: any }, Services) -> { Managers: { [string]: any }, PlayerAdded: { [string]: (Player) -> () } },
	LoadHelpers: (Instance, Instance) -> { [string]: any },
	LoadServices: () -> Services
}
-- Type for Core System
export type CoreSystem = {
	__index: CoreSystem,
	Services: Services,
	Helpers: SyncModules,
	Managers: Managers,
	Settings: { [string]: any },
}

local function warn(...)
	oldwarn("["..COSText.." Error] ", ...)
end

local function print(...)
	oldprint("["..COSText.." Information]",...)
end

local function StageWarn(...)
	if not DoLogStage then
		return
	end

	oldwarn("["..COSText.." Warning] ", ...)
end

local function StagePrint(...)
	if not DoLogStage then
		return
	end

	oldprint("["..COSText.." Information]",...)
end


local function LogStage(...)
	if not DoLogStage then
		return
	end

	oldwarn("["..COSText.."]",...)
end

local function LoadHelpers(Location, ScriptRef): SyncModules
	local HelpersMap = {}

	local Promises = {}

	if not Location then
		return HelpersMap
	end

	if Location == ScriptRef:FindFirstChild("Helpers") then
		local Shared = ReplicatedStorage:FindFirstChild("Shared")
		if Shared then
			local SharedHelpers = LoadHelpers(Shared, ScriptRef)
			for Name, Module in pairs(SharedHelpers) do
				HelpersMap[Name] = Module
			end
		end
	end

	for _, HelperModule in ipairs(Location:GetChildren()) do
		if not HelperModule:IsA("ModuleScript") then
			--warn("Regular script found in Helpers:", HelperModule)
			continue
		end

		table.insert(Promises, Promise.new(function(resolve)
			LogStage("Loading helper", HelperModule.Name)
			local ModuleResult

			local Success = xpcall(function()
				ModuleResult = require(HelperModule)
			end, function(err)
				return debug.traceback(
					string.format("%s failed to load:\n%s", HelperModule.Name, tostring(err)),
					2
				)
			end)

			if not Success then
				--warn(ModuleResult)
				return resolve()
			end

			HelpersMap[HelperModule.Name] = ModuleResult
			LogStage("Successfully Loaded Helper:", HelperModule.Name)

			resolve()
		end))
	end

	Promise.all(Promises):await()

	return HelpersMap
end

function LiteLoadManager(LiteManagersInst, Helpers, Services)
	if Services == nil and type(Helpers) == "table" and Helpers.Helpers ~= nil and Helpers.Services ~= nil then
		Services = Helpers.Services
		Helpers = Helpers.Helpers
	end

	local LiteManagersMap = {}
	local Promises = {}

	local PlayerAdded = {}
	local CharacterAdded = {}

	if not LiteManagersInst then
		warn("No lite managers folder provided")
		return {
			Managers = LiteManagersMap,
			PlayerAdded = PlayerAdded,
			CharacterAdded = CharacterAdded
		}
	end

	for _, child in ipairs(LiteManagersInst:GetChildren()) do
		if not child:IsA("ModuleScript") then
			continue
		end

		table.insert(Promises, Promise.new(function(resolve)
			local Result

			local Success = xpcall(function()
				local ModuleFunc = require(child)
				Result = ModuleFunc(Helpers, Services)
			end, function(err)
				return debug.traceback(
					string.format("%s lite load failed:\n%s", child.Name, tostring(err)),
					2
				)
			end)

			if not Success then
				warn(Result)
				return resolve()
			end

			LiteManagersMap[child.Name] = Result

			--// Hook PlayerAdded
			if type(Result) == "table" then
				if Result.PlayerAdded then
					PlayerAdded[child.Name] = Result.PlayerAdded
				end

				if Result.CharacterAdded then
					CharacterAdded[child.Name] = Result.CharacterAdded
				end
			end

			LogStage("Loaded:", child.Name)

			resolve()
		end))
	end

	Promise.all(Promises):await()

	return {
		Managers = LiteManagersMap,
		PlayerAdded = PlayerAdded,
		CharacterAdded = CharacterAdded
	}
end

--// Main Loader Function
local function LoadManagers(ManagersInst, Helpers, Services): Managers
	if Services == nil and type(Helpers) == "table" and Helpers.Helpers ~= nil and Helpers.Services ~= nil then
		Services = Helpers.Services
		Helpers = Helpers.Helpers
	end

	local PlayerAdded = {}
	local CharacterAdded = {}
	local ManagersMap = {}

	local Promises = {}

	if not ManagersInst then
		warn("No Managers folder provided")
		return {
			Managers = ManagersMap,
			PlayerAdded = PlayerAdded,
			CharacterAdded = CharacterAdded,
		}
	end

	local Development = ManagersInst:FindFirstChild("Development")

	for _, Child in ipairs(ManagersInst:GetChildren()) do
		if not Child:IsA("ModuleScript") or Child.Name == "Development" then
			continue
		end

		table.insert(Promises, Promise.new(function(resolve)
			local ManagerModule = Child :: ModuleScript

			if Development then
				local DevOverride = Development:FindFirstChild(Child.Name)
				if DevOverride then
					ManagerModule = DevOverride
				end
			end

			local Result

			local Success = xpcall(function()
				local ModuleFunc = require(ManagerModule)
				Result = ModuleFunc(Helpers, Services)
			end, function(err)
				warn(err)
				warn(debug.traceback(
					string.format("%s boot failed:\n%s", ManagerModule.Name, tostring(err)),
					2
					))
				return 
			end)

			if not Success then
				warn(Result)
				return resolve()
			end

			ManagersMap[ManagerModule.Name] = Result

			if type(Result) == "table" then
				local PlayerAdd = Result.PlayerAdded
				if PlayerAdd then
					if type(PlayerAdd) == "table" then
						for Key, Func in pairs(PlayerAdd) do
							PlayerAdded[ManagerModule.Name .. "-" .. Key] = Func
						end
					else
						PlayerAdded[ManagerModule.Name] = PlayerAdd
					end
				end

				local CharAdd = Result.CharacterAdded
				if CharAdd then
					if type(CharAdd) == "table" then
						for Key, Func in pairs(CharAdd) do
							CharacterAdded[ManagerModule.Name .. "-" .. Key] = Func
						end
					else
						CharacterAdded[ManagerModule.Name] = CharAdd
					end
				end
			end

			LogStage("Successfully Loaded Manager:", ManagerModule.Name)

			resolve()
		end))
	end

	Promise.all(Promises):await()

	return {
		Managers = ManagersMap,
		PlayerAdded = PlayerAdded,
		CharacterAdded = CharacterAdded,
	}
end

--[[
Lazy loading services,
I just wanted to do it. In reality GetService is already cached but it really puts the core together.
]]
local function LoadServices(): Services
	local Cache = {}

	return setmetatable({
		Promise = Promise	 --// This is not a service. The only way I could avoid duplicate modules is this.
	}, {
		__index = function(_, key)
			if Cache[key] then
				return Cache[key]
			end

			local Success, Service = pcall(game.GetService, game, key)
			if Success and Service then
				Cache[key] = Service
				return Service
			end

			warn(("Invalid service requested: %s"):format(tostring(key)))
			return nil
		end;
		__newindex = function()
			return warn("Services table is read only") --// TODO: Implement custom service mutation. I.E Implement data directly into service
		end,
	})
end

local function SetHelpers(helpers)
	HelpersVar = helpers
end

return {
	--// Debug
	warn= warn,
	print = print,
	--// Debug dependant on DoPrintSuccess == true TODO: Make this easier to use in modules.
	LogStage = LogStage,
	StageWarn = StageWarn;
	StagePrint = StagePrint;
	--// Helpers
	LoadManagers = LoadManagers,
	LiteLoadManager = LiteLoadManager;
	LoadHelpers = LoadHelpers,
	LoadServices = LoadServices,
	
	--// Internal Services
	SetHelpers = SetHelpers
}
