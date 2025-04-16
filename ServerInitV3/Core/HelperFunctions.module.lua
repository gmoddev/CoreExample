--[[
Not_Lowest
Library for core script, so it can be used as a base for other scripts

3/24/25 - Made LoadManagers NeverNested
]]

local DoLogStage = script.Parent.DoPrintSuccess.Value

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
-- Type for a single service
export type GameService<T> = T

-- Type for Services Table (loaded via LoadServices)
export type Services = {
	CollectionService: GameService<CollectionService>,
	Players: GameService<Players>,
	RunService: GameService<RunService>,
	ReplicatedStorage: GameService<ReplicatedStorage>,
	ReplicatedFirst: GameService<ReplicatedFirst>,
	Lighting: GameService<Lighting>,
	TextChatService: GameService<TextChatService>,
	TweenService: GameService<TweenService>,
	StarterGui: GameService<StarterGui>,
	GuiService: GameService<GuiService>,
	MarketplaceService: GameService<MarketplaceService>,
	ProximityPromptService: GameService<ProximityPromptService>,
	PathfindingService: GameService<PathfindingService>,
	TextService: GameService<TextService>,
	SoundService: GameService<SoundService>,

	-- Client-specific services
	StarterPack: GameService<StarterPack>?,
	ContentProvider: GameService<ContentProvider>?,
	UserInputService: GameService<UserInputService>?,
	ContextActionService: GameService<ContextActionService>?,

	-- Server-specific services
	PhysicsService: GameService<PhysicsService>?,
	ServerStorage: GameService<ServerStorage>?,
	ServerScriptService: GameService<ServerScriptService>?,
	GroupService: GameService<GroupService>?,
	HttpService: GameService<HttpService>?,
	DataStoreService: GameService<DataStoreService>?,
	BadgeService: GameService<BadgeService>?,
	TeleportService: GameService<TeleportService>?
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

-- Type for Managers Table (Loaded via LoadManagers)
export type Managers = {
	[string]: any  -- Dynamic table for manager instances
}

export type Helpers = {
	[string]: any
	
}

-- Type for Core System
export type CoreSystem = {
	__index: CoreSystem,
	Services: Services,
	Helpers: { [string]: any },
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

local function LoadManagers(managersInst,helpers,services): Managers
	local PlayerAdded = {}
	local managers = {}
	for _, manager in pairs(managersInst:GetChildren()) do
		if not manager:IsA("ModuleScript") then
			warn("Unexpected object found in Managers: " .. manager.Name)
			return
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
					PlayerAdded[manager.Name] = PlayerAddFunc
				end
			end
			LogStage("Successfully Loaded Manager: ",manager.Name)

		end)
	end
	return {Managers = managers, PlayerAdded = PlayerAdded}
end

local function LoadServices(): Services
	local BaseServices = {
		"CollectionService", "Players", "RunService", "ReplicatedStorage",
		"ReplicatedFirst", "Lighting", "TextChatService", "TweenService",
		"StarterGui", "GuiService", "MarketplaceService", "ProximityPromptService",
		"PathfindingService","TextService","SoundService"
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

	--// Generic Services
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
end

local function SetHelpers(helpers)
	helpersVar = helpers
end

return {
	--// Debug
	warn= warn,
	print = print,
	--// Debug dependant on DoPrintSuccess == true
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