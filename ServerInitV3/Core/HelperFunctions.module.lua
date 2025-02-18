--[[
    Not_Lowest
    Library for core script, so it can be used as a base for other scripts
--]]

--// Dependencies
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--// Configuration
local DoLogStage = script.Parent.DoPrintSuccess.Value
local Client_Or_Server = RunService:IsServer()
local COSText = Client_Or_Server and "Server" or "Client"

--// Caching
local CachedServices

--// Original Logging Functions
local oldprint = print
local oldwarn = warn
local olderror = error

--// Logging Wrappers
local function warn(...)
	oldwarn("[" .. COSText .. " Error] ", ...)
end

local function print(...)
	oldprint("[" .. COSText .. " Information]", ...)
end

local function LogStage(...)
	if not DoLogStage then return end
	oldwarn("[" .. COSText .. "]", ...)
end

--// Load Helpers
local function LoadHelpers(location, script)
	warn(location, script)

	local helpers = (location == script:FindFirstChild("Helpers")) and LoadHelpers(ReplicatedStorage.Shared, script) or {}

	for _, helper in pairs(location:GetChildren()) do
		if helper:IsA("ModuleScript") then
			local success, module = pcall(require, helper)
			if success then
				helpers[helper.Name] = module
				LogStage("Successfully Loaded Helper: ", helper.Name)
			else
				warn("Failed to load Helper module: " .. helper.Name .. ". Error: " .. module)
			end
		else
			warn("Regular script found in Helpers: ", helper)
		end
	end

	return helpers
end

--// Load Managers
local function LoadManagers(managersInst, helpers, services, PlayerAdded)
	local managers = {}

	for _, manager in pairs(managersInst:GetChildren()) do
		if manager:IsA("ModuleScript") then
			task.spawn(function()
				local success, func = pcall(require, manager)
				if success then
					local InitSuccess, result = pcall(func, helpers, services)
					if InitSuccess then
						managers[manager.Name] = result

						-- Register PlayerAdded function if applicable
						if type(result) == "table" and type(PlayerAdded) == "table" then
							local PlayerAddFunc = result["PlayerAdded"]
							if PlayerAddFunc then
								PlayerAdded[manager.Name] = PlayerAddFunc
							end
						end

						LogStage("Successfully Loaded Manager: ", manager.Name)
					else
						warn("Failed to initialize Manager: " .. manager.Name .. ". Error: " .. result, debug.traceback())
					end
				else
					warn("Failed to load Manager script: " .. manager.Name .. ". Error: " .. func)
				end
			end)
		else
			warn("Unexpected object found in Managers: " .. manager.Name)
		end
	end

	return managers
end

--// Loads services based on IsServer
local function LoadServices()
	if CachedServices then
		return CachedServices
	end


	local BaseServices = {
		"Players", "RunService", "ReplicatedStorage", "ReplicatedFirst",
		"Lighting", "TextChatService", "TweenService", "StarterGui"
	}

	local SpecificServices = {
		Client = { "StarterPack", "SoundService", "ContentProvider" },
		Server = { "PhysicsService", "ServerStorage", "ServerScriptService", "GroupService", "HttpService" }
	}

	local Services = {}

	for _, v in ipairs(BaseServices) do
		local Service = game:GetService(v)
		if Service then
			Services[v] = Service
		end
	end

	for _, v in ipairs(SpecificServices[COSText]) do
		local Service = game:GetService(v)
		if Service then
			Services[v] = Service
		end
	end
	
	CachedServices = setmetatable(Services, {
		__newindex = function(_, key, _)
			error("Attempt to modify read-only CachedServices: " .. tostring(key), 2)
		end,
		__metatable = "Locked"
	})

	return CachedServices
end



--// Return Helpers
return {
	warn = warn,
	print = print,
	LogStage = LogStage,
	LoadManagers = LoadManagers,
	LoadHelpers = LoadHelpers,
	LoadServices = LoadServices,
}
