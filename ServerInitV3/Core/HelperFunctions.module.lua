--[[
Not_Lowest
Library for core script, so it can be used as a base for other scripts

3/24/25 - Made LoadManagers NeverNested
6/8/25 - Made LoadManagers use a makeshift promise to prevent race conditions
2/9/26 - Made LoadServices lazyload. Rewrote type defs to apply (And are now a lot less complicated)
]]

local DoLogStage = script.Parent.DoPrintSuccess.Value

--// Services Loading // TODO: Integrate this with lazy loading
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService('Players')

local Client_Or_Server = RunService:IsServer()
local COSText = Client_Or_Server and "Server" or "Client"

local oldprint = print
local oldwarn = warn
local olderror = error

local helpersVar = nil

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
export type Helpers = {
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
	Helpers: Helpers,
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

local function LoadHelpers(location,script): Helpers
	local helpers = (location == script:FindFirstChild("Helpers") and LoadHelpers(ReplicatedStorage.Shared,script) or {})

	for _, helper in pairs(location:GetChildren()) do
		if helper:IsA("ModuleScript") then
			task.spawn(function()
				local success, module = pcall(require, helper)
				if success then
					helpers[helper.Name] = module
					LogStage("Successfully Loaded Helper: ",helper.Name)
				else
					warn("Failed to load Helper module: " .. helper.Name .. ". Error: " .. module)
					warn(debug.traceback())
				end
			end)
		else
			warn("Regular script found in Helpers: ", helper)
		end
	end
	return helpers
end

--[[
local function LoadManagers(managersInst,helpers,services): Managers
	local PlayerAdded = {}
	local CharacterAdded = {}
	local managers = {}
	for _, manager in pairs(managersInst:GetChildren()) do
		if not manager:IsA("ModuleScript") then
			warn("Unexpected object found in Managers: " .. manager.Name)
			continue --// accidentally set this as return instead of continue, returns the function with nil managers
		end
		task.spawn(function()
			local success, func = pcall(require, manager)
			if not success then
				return warn("Failed to load Manager script: " .. manager.Name .. ". Error: " .. func)
			end
			local InitSuccess, result = pcall(func, helpers,services)
			if not InitSuccess then
				return warn("Failed to initialize Manager: " .. manager.Name .. ". Error: " .. result,debug.traceback())
			end

			managers[manager.Name] = result
			if type(result) == "table" and type(PlayerAdded) == "table" then
				local PlayerAddFunc = result["PlayerAdded"]
				if PlayerAddFunc then
					if type(PlayerAddFunc) == "table" then
						for i,v in pairs(PlayerAddFunc) do
							PlayerAdded[manager.Name.."-"..i] = v 
						end
					else
						PlayerAdded[manager.Name] = PlayerAddFunc
					end	
				end
				local CharacterAddedFunc = result["CharacterAdded"]
				if CharacterAddedFunc then
					if type(CharacterAddedFunc) == "table" then
						for i,v in pairs(CharacterAddedFunc) do
							CharacterAdded[manager.Name.."-"..i] = v 
						end
					else
						CharacterAdded[manager.Name] = CharacterAddedFunc
					end	
				end
			end
			LogStage("Successfully Loaded Manager: ",manager.Name)

		end)
	end
	return {Managers = managers, PlayerAdded = PlayerAdded, CharacterAdded = CharacterAdded}
end

]]

--// Main Loader Function
local function LoadManagers(ManagersInst, Helpers, Services): Managers
	local PlayerAdded = {}
	local CharacterAdded = {}
	local ManagersMap = {}

	local Remaining = #ManagersInst:GetChildren()
	local Done = Instance.new("BindableEvent")
	local Development = ManagersInst:FindFirstChild("Development")

	-- Track completion to avoid multiple calls
	local Completed = false

	local function TryFinish()
		if Remaining == 0 and not Completed then
			Completed = true
			--warn("Done")
			Done:Fire()
		end
	end
	--// Main Managers Loop
	for _, Child in ipairs(ManagersInst:GetChildren()) do

		if not Child:IsA("ModuleScript") or Child.Name == "Development" then
			Remaining -= 1
			--warn("Unexpected object in Managers: " .. Child.Name)
			continue
		end

		task.spawn(function()
			local ManagerModule = Child

			if Development then
				local DevOverride = Development:FindFirstChild(Child.Name)
				if DevOverride then
					ManagerModule = DevOverride
				end
			end

			local Success, ModuleFunc = pcall(require, ManagerModule)
			if not Success then
				--warn("Failed to load Manager script: " .. ManagerModule.Name .. ". Error: " .. ModuleFunc)
				Remaining -= 1
				TryFinish()
				return
			end
			--// Final manager loading sequence, calls the manager with the services and helpers.
			--// Returns a table of optional PlayerAdded: function or CharacterAdded: function.
			local InitSuccess, Result = pcall(ModuleFunc, Helpers, Services)
			if not InitSuccess then
				--warn("Failed to initialize Manager: " .. ManagerModule.Name .. ". Error: " .. Result, debug.traceback())
			else
				ManagersMap[ManagerModule.Name] = Result

				if type(Result) == "table" then
					-- Handle PlayerAdded
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

					-- Handle CharacterAdded
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

				LogStage("Successfully Loaded Manager: ", ManagerModule.Name)
			end
			Remaining -= 1
			--warn(Remaining, indc)
			TryFinish()
		end)
	end

	if Remaining > 0 then
		--warn(Remaining)
		Done.Event:Wait()
	end
	--warn("=======DONE====")
	--warn(PlayerAdded)
	return {
		Managers = ManagersMap,
		PlayerAdded = PlayerAdded,
		CharacterAdded = CharacterAdded,
	}
end

--[[
Loads preset services, I should instead wrap this in a metatable

local function LoadServices(): Services
	local BaseServices = {
		"CollectionService", "Players", "RunService", "ReplicatedStorage",
		"ReplicatedFirst", "Lighting", "TextChatService", "TweenService",
		"StarterGui", "GuiService", "MarketplaceService", "ProximityPromptService",
		"PathfindingService","TextService","SoundService", "Workspace", "Teams",
	}

	local SpecificServices = {
		ClientServices = {
			"StarterPack", "ContentProvider", "UserInputService",
			"ContextActionService"
		};
		ServerServices = {
			"PhysicsService", "ServerStorage", "ServerScriptService", "GroupService",
			"HttpService", "DataStoreService", "BadgeService", "TeleportService"
		}
	}

	local Services: Services = {}

	--// Shared Services
	for _,v in ipairs(BaseServices) do
		local Service = game:GetService(v)
		if not Service then continue end

		Services[v] = Service
	end
	--// Client/Server Specific Services
	for _,v in ipairs(SpecificServices[COSText.."Services"]) do
		local Service = game:GetService(v)
		if not Service then continue end

		Services[v] = Service
	end

	return Services
end]]
--[[
Lazy loading services,
I just wanted to do it. In reality GetService is already cached but it really puts the core together.
]]
local function LoadServices(): Services
	local Cache = {}

	return setmetatable({}, {
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
	helpersVar = helpers
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
	LoadHelpers = LoadHelpers,
	LoadServices = LoadServices,
	--// Internal Services
	SetHelpers = SetHelpers
}