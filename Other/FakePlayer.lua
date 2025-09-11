--[[ 
Delinquent Studios
Not_Lowest

Simulates a player object for datastore use
]]

local Players = game:GetService("Players")

local FakePlayer = {}
FakePlayer.__index = function(self, key)
	if key == "Key" then
		return self:ToKey()
	end

	local value = rawget(self, key) or rawget(FakePlayer, key)
	if value ~= nil then
		return value
	end

	if self.Object then
		return self.Object[key]
	end

	return nil
end

function FakePlayer.new(UserId, name)
	local RealPlayer = Players:FindFirstChild(name)
	if RealPlayer then
		return RealPlayer
	end

	local self = setmetatable({}, FakePlayer)

	self.UserId = UserId or -1
	self.Name = name or "FakePlayer"
	self.DisplayName = self.Name

	self.Attributes = {}

	self.Object = Instance.new("Model")
	self.Object.Name = self.Name

	self.NilStorage = Instance.new("Model")
	self.NilStorage.Name = "_Ignore"
	self.NilStorage.Parent = self.Object

	self.ClassName = "Player"

	self.Character = nil

	self.PlayerGui = Instance.new("ScreenGui")
	self.PlayerGui.Name = "PlayerGui"

	self.Backpack = Instance.new("Folder")
	self.Backpack.Name = "Backpack"

	self.CharacterAdded = Instance.new("RemoteEvent")
	self.CharacterAdded.Name = "CharacterAdded"
	self.CharacterAdded.Parent = self.NilStorage

	self.Destroying = Instance.new("BindableEvent")
	self.Destroying.Name = "Destroying"
	self.Destroying.Parent = self.NilStorage

	self.AncestryChanged = Instance.new("BindableEvent")
	self.AncestryChanged.Name = "AncestryChanged"
	self.AncestryChanged.Parent = self.NilStorage

	return self
end

function FakePlayer:GetAttribute(key)
	return self.Object:GetAttribute(key)
end

function FakePlayer:SetAttribute(key, value)
	self.Object:SetAttribute(key, value)
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
	if not self.Object then
		return false
	end
	return self.Object:IsDescendantOf(parent)
end

function FakePlayer:ToKey()
	return string.format("Player_%d", self.UserId)
end

function FakePlayer:Destroy()
	if self.Destroying then
		self.Destroying:Fire()
	end

	if self.Object then
		self.Object:Destroy()
		self.Object = nil
	end

	if self.PlayerGui then
		self.PlayerGui:Destroy()
		self.PlayerGui = nil
	end

	if self.Backpack then
		self.Backpack:Destroy()
		self.Backpack = nil
	end

	self.Attributes = nil
	self.Character = nil
	self.CharacterAdded = nil
	self.Destroying = nil
	self.AncestryChanged = nil
	self.NilStorage = nil

	setmetatable(self, nil)
end

function FakePlayer:__tostring()
	return string.format("FakePlayer: %s (%d)", self.Name, self.UserId)
end

return FakePlayer
