--[[ 
Delinquent Studios
Not_Lowest

Simulates a player object for datastore use
]]

local Players = game:GetService("Players")

local FakePlayer = {}
FakePlayer.__index = function(self, key)
	if key == "Key" then
		return string.format("Player_%d", self.UserId)
	end
	
	local value = rawget(self, key) or FakePlayer[key]
	if value ~= nil then
		return value
	end

	if self.Object then
		return self.Object[key]
	end

	return nil
end

function FakePlayer.new(userId, name)
	local RealPlayer = Players:FindFirstChild(name)
	
	if RealPlayer then
		return RealPlayer
	end
	
	local self = setmetatable({}, FakePlayer)
	self.UserId = userId or 0
	self.Name = name or "FakePlayer"
	self.DisplayName = self.Name

	self.Attributes = {}

	self.Object = Instance.new("Model")
	self.Object.Name = name or "FakePlayer"
	self.Object.Parent = game:GetService("ServerStorage")

	self.NilStorage = Instance.new("Model")
	self.NilStorage.Name = "_Ignore"
	self.NilStorage.Parent = self.Object

	self.ClassName = "Player"
	
	self.Character = nil
	
	self.PlayerGui = Instance.new("ScreenGui")
	self.PlayerGui.Name = "PlayerGui"
	self.PlayerGui.Parent = self.Object
	
	self.Backpack = Instance.new("Folder")
	self.Backpack.Name = "Backpack"
	self.Backpack.Parent = self.Object

	self.CharacterAdded = Instance.new("RemoteEvent")
	self.CharacterAdded.Parent = self.NilStorage

	return self
end

function FakePlayer:GetAttribute(key)
	return self.Attributes[key]
end

function FakePlayer:SetAttribute(key, value)
	self.Attributes[key] = value
end

function FakePlayer:FindFirstChild(childName)
	return self.Object:FindFirstChild(childName)
end

function FakePlayer:WaitForChild(childName)
	return self.Object:WaitForChild(childName)
end

function FakePlayer:IsA(className)
	return className == "Player"
end

function FakePlayer:IsDescendantOf(parent)
	return true
end

function FakePlayer:ToKey()
	return string.format("Player_%d", self.UserId)
end

function FakePlayer:Destroy()
	if self.Object then
		self.Object:Destroy()
	end
	self = nil
end

function FakePlayer:__tostring()
	return string.format("FakePlayer: %s (%d)", self.Name, self.UserId)
end

return FakePlayer
