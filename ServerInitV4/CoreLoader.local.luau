local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = ReplicatedStorage:FindFirstChild("Core")
local Client = ServerScriptService:FindFirstChild("Client")

if not Core then
	error("Core module not found in ReplicatedStorage")
end

if not Client then
	error("Client root not found in ReplicatedStorage")
end

local success, CoreModule = pcall(require, Core)

if not success then
	warn("Failed to require Core module: ", debug.traceback(tostring(CoreModule), 5))
	return
end

local success, Runtime = pcall(CoreModule, Client)

if not success then
	warn("Failed to initialize Core module: ", debug.traceback(tostring(Runtime), 5))
	return
end