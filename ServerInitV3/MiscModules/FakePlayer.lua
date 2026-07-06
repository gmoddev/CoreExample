--[[ 
Delinquent Studios
Not_Lowest
Simulates a player object for datastore use
]]
local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")

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

function FakePlayer.new(UserId, name)
	local RealPlayer = Players:FindFirstChild(name)

	if RealPlayer then
		return RealPlayer
	end

	local self = setmetatable({}, FakePlayer)
	self.UserId = UserId or 0
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
	self.AccountAge = 0
	self.Team = nil
	self.TeamColor = BrickColor.new("White")
	self.Neutral = true

	self.MembershipType = Enum.MembershipType.None
	self.AutoJumpEnabled = true
	self.CameraMaxZoomDistance = 128
	self.CameraMinZoomDistance = 0.5
	self.CameraMode = Enum.CameraMode.Classic
	self.CanLoadCharacterAppearance = true
	self.CharacterAppearanceId = UserId or 0
	self.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
	self.DevComputerCameraMode = Enum.DevComputerCameraMode.UserChoice
	self.DevComputerMovementMode = Enum.DevComputerMovementMode.UserChoice
	self.DevEnableMouseLock = true
	self.DevTouchCameraMode = Enum.DevTouchCameraMode.UserChoice
	self.DevTouchMovementMode = Enum.DevTouchMovementMode.UserChoice
	self.HealthDisplayDistance = 100
	self.NameDisplayDistance = 100
	self.ReplicationFocus = nil
	self.RespawnLocation = nil

	self.leaderstats = Instance.new("Folder")
	self.leaderstats.Name = "leaderstats"
	self.leaderstats.Parent = self.Object

	self.PlayerGui = Instance.new("ScreenGui")
	self.PlayerGui.Name = "PlayerGui"
	self.PlayerGui.Parent = self.Object

	self.Backpack = Instance.new("Folder")
	self.Backpack.Name = "Backpack"
	self.Backpack.Parent = self.Object

	-- Player Scripts folder
	self.PlayerScripts = Instance.new("Folder")
	self.PlayerScripts.Name = "PlayerScripts"
	self.PlayerScripts.Parent = self.Object

	-- Events
	self.CharacterAdded = Instance.new("BindableEvent")
	self.CharacterAdded.Parent = self.NilStorage

	self.CharacterRemoving = Instance.new("BindableEvent")
	self.CharacterRemoving.Parent = self.NilStorage

	self.Chatted = Instance.new("BindableEvent")
	self.Chatted.Parent = self.NilStorage

	return self
end

function FakePlayer:GetAttribute(key)
	return self.Attributes[key]
end

function FakePlayer:SetAttribute(key, value)
	self.Attributes[key] = value
end

function FakePlayer:GetAttributes()
	return self.Attributes
end

function FakePlayer:FindFirstChild(childName, recursive)
	if recursive then
		return self.Object:FindFirstChild(childName, true)
	end
	return self.Object:FindFirstChild(childName)
end

function FakePlayer:WaitForChild(childName, timeout)
	return self.Object:WaitForChild(childName, timeout)
end

function FakePlayer:FindFirstChildOfClass(className)
	return self.Object:FindFirstChildOfClass(className)
end

function FakePlayer:FindFirstChildWhichIsA(className)
	return self.Object:FindFirstChildWhichIsA(className)
end

function FakePlayer:GetChildren()
	return self.Object:GetChildren()
end

function FakePlayer:GetDescendants()
	return self.Object:GetDescendants()
end

function FakePlayer:IsA(className)
	return className == "Player" or className == "Instance"
end

function FakePlayer:IsDescendantOf(parent)
	return self.Object:IsDescendantOf(parent)
end

function FakePlayer:IsAncestorOf(descendant)
	return self.Object:IsAncestorOf(descendant)
end

function FakePlayer:GetFullName()
	return "Players." .. self.Name
end

function FakePlayer:ToKey()
	return string.format("Player_%d", self.UserId)
end

function FakePlayer:LoadCharacter()
	if self.Character then
		self.CharacterRemoving.Event:Fire(self.Character)
		self.Character:Destroy()
		self.Character = nil
	end

	local character

	if self.CanLoadCharacterAppearance and self.CharacterAppearanceId > 0 then
		local success, result = pcall(function()
			return Players:CreateHumanoidModelFromUserIdAsync(self.CharacterAppearanceId)
		end)

		if success and result then
			character = result
		end
	end

	if not character then
		character = Instance.new("Model")
		character.Name = self.Name

		local humanoid = Instance.new("Humanoid")
		humanoid.Name = "Humanoid"
		humanoid.Parent = character

		local RootPart = Instance.new("Part")
		RootPart.Name = "HumanoidRootPart"
		RootPart.Size = Vector3.new(2, 2, 1)
		RootPart.Transparency = 1
		RootPart.CanCollide = false
		RootPart.Anchored = true
		RootPart.Parent = character

		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(2, 1, 1)
		head.Parent = character

		local face = Instance.new("Decal")
		face.Name = "face"
		face.Texture = "rbxasset://textures/face.png"
		face.Parent = head

		local neck = Instance.new("Motor6D")
		neck.Name = "Neck"
		neck.Part0 = RootPart
		neck.Part1 = head
		neck.C0 = CFrame.new(0, 1, 0)
		neck.C1 = CFrame.new(0, -0.5, 0)
		neck.Parent = RootPart

		local torso = Instance.new("Part")
		torso.Name = "Torso"
		torso.Size = Vector3.new(2, 2, 1)
		torso.Parent = character

		local waist = Instance.new("Motor6D")
		waist.Name = "Root"
		waist.Part0 = RootPart
		waist.Part1 = torso
		waist.Parent = RootPart

		character.PrimaryPart = RootPart

		local bodyColors = Instance.new("BodyColors")
		bodyColors.Parent = character
	end

	character.Name = self.Name

	if self.RespawnLocation then
		if character.PrimaryPart then
			character:SetPrimaryPartCFrame(self.RespawnLocation.CFrame + Vector3.new(0, 5, 0))
		end
	end

	character.Parent = workspace

	self.Character = character

	if character.PrimaryPart then
		character.PrimaryPart.Anchored = false
	end

	self.CharacterAdded.Event:Fire(character)

	return character
end

function FakePlayer:Kick(message)
	warn(string.format("FakePlayer %s was kicked: %s", self.Name, message or ""))
	self:Destroy()
end

function FakePlayer:Destroy()
	if self.Character then
		self.CharacterRemoving.Event:Fire(self.Character)
		self.Character:Destroy()
		self.Character = nil
	end

	if self.Object then
		self.Object:Destroy()
	end

	setmetatable(self, nil)
end

function FakePlayer:__tostring()
	return string.format("FakePlayer: %s (%d)", self.Name, self.UserId)
end

return FakePlayer