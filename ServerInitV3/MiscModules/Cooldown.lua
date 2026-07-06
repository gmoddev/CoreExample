--[[
Not_Lowest
Delinquent Studios

cooldown module, revamp of old cooldown system
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Remotes = ReplicatedStorage.Remotes
local Effect: RemoteEvent = Remotes.Effect

local CooldownModule = {}
local PlayerCooldowns = {}

local CooldownMeta = {}
CooldownMeta.__index = CooldownMeta

function CooldownMeta:Clear()
	for Name in pairs(self.ActiveCooldowns) do
		if self.Instance then
			CollectionService:RemoveTag(self.Instance, Name .. "CD")
		end
	end
	table.clear(self.ActiveCooldowns)
end

function CooldownMeta:CheckCD(Name: string): boolean
	return self.ActiveCooldowns[Name] == true
end

function CooldownMeta:Cooldown(Name: string, Time: number)
	if self:CheckCD(Name) then
		return false
	end

	self.ActiveCooldowns[Name] = true
	CollectionService:AddTag(self.Instance, Name .. "CD")

	--// backwards compatibility, some things cross modules do it themselves
	if not string.find(Name, "Service") and self.Player then
		Effect:FireClient(self.Player, "VisualCD", { Name = Name, Time = Time })
	end

	task.delay(Time, function()
		if self.ActiveCooldowns[Name] then
			self:EndCooldown(Name)
		end
	end)

	return true
end

function CooldownMeta:EndCooldown(Name: string)
	if not self.ActiveCooldowns[Name] then
		return false
	end

	self.ActiveCooldowns[Name] = nil

	if self.Instance then
		CollectionService:RemoveTag(self.Instance, Name .. "CD")
	end

	return true
end

function CooldownModule.Get(Player: Player)
	if PlayerCooldowns[Player] then
		return PlayerCooldowns[Player]
	end

	local Obj = setmetatable({
		Player = Player,
		Instance = nil,
		ActiveCooldowns = {}
	}, CooldownMeta)

	PlayerCooldowns[Player] = Obj

	Player.CharacterAdded:Connect(function(Char)
		Obj.Instance = Char
	end)

	Player.CharacterRemoving:Connect(function()
		Obj:Clear()
		Obj.Instance = nil
	end)

	Player.AncestryChanged:Connect(function(_, parent)
		if not parent then
			Obj:Clear()
			PlayerCooldowns[Player] = nil
		end
	end)

	return Obj
end

return CooldownModule
