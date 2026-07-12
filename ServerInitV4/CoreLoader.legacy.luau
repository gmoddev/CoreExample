local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Core = ReplicatedStorage:FindFirstChild("Core")
local Server = ServerScriptService:FindFirstChild("Server")

if not Core then
	error("Core module not found in ReplicatedStorage")
end

if not Server then
	error("Server root not found in ServerScriptService")
end

local success, CoreModule = pcall(require, Core)

if not success then
	warn("Failed to require Core module: ", debug.traceback(tostring(CoreModule), 5))
	return
end

local runtimeSuccess, Runtime = pcall(CoreModule, Server)

if not runtimeSuccess then
	warn("Failed to initialize Core module: ", debug.traceback(tostring(Runtime), 5))
	return
end
