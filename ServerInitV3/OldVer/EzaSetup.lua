--[[Run in your command bar]]

local ses = game.ScriptEditorService

local function Update(script,source)
	ses:UpdateSourceAsync(script, function() return source end)
end

local ClientCore = Instance.new("Folder",game.ReplicatedStorage)
local CManager = Instance.new("Folder",ClientCore)
local CHelper = Instance.new("Folder",ClientCore)

local Shared = Instance.new("Folder",game.ReplicatedStorage)

local ServerCore = Instance.new("Folder",game.ServerScriptService)
local SManager = Instance.new("Folder",ServerCore)
local SHelper = Instance.new("Folder",ServerCore)

ClientCore.Name = "ClientCore"
CManager.Name = "Managers"
CHelper.Name = "Helpers"

if game.ReplicatedStorage:FindFirstChild("Shared") then
	game.ReplicatedStorage.Shared.Name = "_OldShared"
end

Shared.Name = "Shared"

if workspace:FindFirstChild("Server") then
	workspace.Server.Name = "_Server"
end

ServerCore.Name = "Server"
SManager.Name = "Managers"
SHelper.Name = "Helpers"

local ServerScript = Instance.new("Script",game.ServerScriptService)
local ClientScript = Instance.new("Script",game.StarterPlayer.StarterPlayerScripts)

local ExampleManager = Instance.new("ModuleScript",SManager)

Update(ClientScript,[[
	-- Not_Lowest
	-- 1/29/2025
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Core = ReplicatedStorage:FindFirstChild("Core")

	if Core then
		local RequiredCore = require(Core)
		if type(RequiredCore) == "function" then
			RequiredCore(ReplicatedStorage.ClientCore)
		end
	end
]])

Update(ServerScript,[[
	-- Not_Lowest
	-- 1/29/2025
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local Core = ReplicatedStorage:FindFirstChild("Core")

	if Core then
		local RequiredCore = require(Core)
		if type(RequiredCore) == "function" then
			RequiredCore(ServerScriptService.Server)
		end
	end
]])

Update(ExampleManager, [[
	return function(helpers,services)
		local ReplicatedStorage: ReplicatedStorage = services.ReplicatedStorage
		
		
		-- Both of these are optional
		local function PlayerAdded(plr)
		
		end
		
		local function CharacterAdded(char,plr)
		
		end
		
		return {
			PlayerAdded = PlayerAdded
			CharacterAdded = CharacterAdded
		}
	end
	
]])