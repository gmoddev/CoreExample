--[[
Not_Lowest
Zone System
]]

local ZoneClass = {}
ZoneClass.__index = ZoneClass

function ZoneClass.new(Config)
	local self = setmetatable({}, ZoneClass)

	self.Players = Config.Players
	self.RunService = Config.RunService
	self.RegionSystem = Config.RegionSystem

	self.Folder = Config.Folder
	self.Attribute = Config.Attribute
	self.TimerAttribute = Config.TimerAttribute or (self.Attribute .. "Timer")
	self.EnterDelay = Config.EnterDelay or 0

	self.CanEnterFunction = Config.CanEnterFunction

	self.Zones = {}
	self.Timers = {}

	self:Initialize()

	return self
end

function ZoneClass:Initialize()
	self._Connections = {}

	self:RefreshZones()

	for _,v in ipairs(self.Folder:GetChildren()) do
		if v:IsA("BasePart") then
			table.insert(self.Zones, v)
		end
	end

	table.insert(self._Connections, self.Folder.ChildAdded:Connect(function(Child)
		table.insert(self.Zones, Child)
	end))

	table.insert(self._Connections, self.Folder.ChildRemoved:Connect(function(Child)
		for i, Zone in ipairs(self.Zones) do
			if Zone == Child then
				table.remove(self.Zones, i)
				break
			end
		end
	end))

	table.insert(self._Connections, self.RunService.Heartbeat:Connect(function()
		self:UpdatePlayers()
	end))

	table.insert(self._Connections, self.Players.PlayerRemoving:Connect(function(Player)
		self.Timers[Player] = nil
	end))
end

function ZoneClass:RefreshZones()
	self.Zones = self.Folder:GetChildren()
end

function ZoneClass:CanEnter(Player)
	if not self.CanEnterFunction then
		return true
	end

	local Success, Result = pcall(self.CanEnterFunction, Player)
	if not Success then
		warn(Result)
		return false
	end

	return Result == true
end

function ZoneClass:IsPlayerInZone(Player)
	local Character = Player.Character
	if not Character then warn("No Character") return false end

	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not Root then warn("No root") return false end

	for _, Zone in ipairs(self.Zones) do
		if Zone:IsA("BasePart") then
			local Distance = (Root.Position - Zone.Position).Magnitude
			local MaxDistance = math.max(Zone.Size.X, Zone.Size.Y, Zone.Size.Z) / 2
			if Distance > MaxDistance then
				continue
			end
		end

		if self.RegionSystem.IsPlayerInRegion(Zone, Player) then
			return true
		end
	end

	return false
end

function ZoneClass:UpdatePlayers()
	for _, Player in ipairs(self.Players:GetPlayers()) do
		local Character = Player.Character
		if not Character then continue end

		local InZone = self:IsPlayerInZone(Player)
		local Active = Character:GetAttribute(self.Attribute)

		if InZone and self:CanEnter(Player) then
			if not Active then
				self:HandleEnter(Player, Character)
			end
		else
			self:HandleExit(Player, Character)
		end
	end
end

function ZoneClass:HandleEnter(Player, Character)
	if self.EnterDelay <= 0 then
		Character:SetAttribute(self.Attribute, true)
		return
	end

	local StartTime = self.Timers[Player]

	if not StartTime then
		self.Timers[Player] = os.clock()
		Character:SetAttribute(self.TimerAttribute, self.EnterDelay)
	else
		local Elapsed = os.clock() - StartTime
		local Remaining = math.max(0, self.EnterDelay - Elapsed)
		Character:SetAttribute(self.TimerAttribute, Remaining)

		if Elapsed >= self.EnterDelay then
			Character:SetAttribute(self.Attribute, true)
			Character:SetAttribute(self.TimerAttribute, nil)
			self.Timers[Player] = nil
		end
	end
end

function ZoneClass:HandleExit(Player, Character)
	self.Timers[Player] = nil

	if Character:GetAttribute(self.Attribute) then
		Character:SetAttribute(self.Attribute, false)
	end

	if Character:GetAttribute(self.TimerAttribute) then
		Character:SetAttribute(self.TimerAttribute, nil)
	end
end

function ZoneClass:Destroy()
	if self._Destroyed then
		return
	end
	self._Destroyed = true

	if self._Connections then
		for _, Connection in ipairs(self._Connections) do
			if Connection.Connected then
				Connection:Disconnect()
			end
		end
	end

	for _, Player in ipairs(self.Players:GetPlayers()) do
		local Character = Player.Character
		if Character then
			if Character:GetAttribute(self.Attribute) then
				Character:SetAttribute(self.Attribute, false)
			end
			if Character:GetAttribute(self.TimerAttribute) then
				Character:SetAttribute(self.TimerAttribute, nil)
			end
		end
	end

	table.clear(self.Zones)
	table.clear(self.Timers)
	table.clear(self._Connections)

	self.Zones = nil
	self.Timers = nil
	self._Connections = nil

	self.Folder = nil
	self.RegionSystem = nil
	self.RunService = nil
	self.Players = nil
end


return ZoneClass
