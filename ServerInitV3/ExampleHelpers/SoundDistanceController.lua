--[[
Not_Lowest
Client DistanceSoundController
]]

return function(services)
	local Players = services.Players
	local RunService = services.RunService

	local LocalPlayer = Players.LocalPlayer

	local DistanceSoundController = {}
	DistanceSoundController.__index = DistanceSoundController

	local ActiveControllers = {}
	local EffectCache = {}

	local function GetListenerPosition()
		local Character = LocalPlayer.Character
		if not Character then return nil end

		local Root = Character:FindFirstChild("HumanoidRootPart")
		return Root and Root.Position or nil
	end

	function DistanceSoundController.new(Sound: Sound, Config)
		assert(Sound and Sound:IsA("Sound"), "Invalid Sound")

		local self = setmetatable({}, DistanceSoundController)

		self.Sound = Sound
		self.DistanceMultiplier = Config.DistanceMultiplier or 0.5
		self.EffectFolder = Config.EffectFolder
		self.Connection = nil

		return self
	end

	function DistanceSoundController:AttachEffects()
		if EffectCache[self.Sound] then return end
		if not self.EffectFolder then return end

		local Effects = {}

		for _, Effect in ipairs(self.EffectFolder:GetChildren()) do
			if Effect:IsA("SoundEffect") then
				local Clone = Effect:Clone()
				Clone.Parent = self.Sound
				table.insert(Effects, Clone)
			end
		end

		EffectCache[self.Sound] = Effects
	end

	function DistanceSoundController:RemoveEffects()
		local Cached = EffectCache[self.Sound]
		if not Cached then return end

		for _, Effect in ipairs(Cached) do
			Effect:Destroy()
		end

		EffectCache[self.Sound] = nil
	end

	function DistanceSoundController:Update()
		if not self.Sound.IsPlaying then return end
		if not self.Sound.Parent then return end

		local ListenerPosition = GetListenerPosition()
		if not ListenerPosition then return end

		if not self.Sound.Parent:IsA("BasePart") then return end

		local Distance = (self.Sound.Parent.Position - ListenerPosition).Magnitude
		local MaxDistance = self.Sound.RollOffMaxDistance
		if MaxDistance <= 0 then return end

		if Distance >= (MaxDistance * self.DistanceMultiplier) then
			self:AttachEffects()
		else
			self:RemoveEffects()
		end
	end

	function DistanceSoundController:Start()
		if self.Connection then return end

		self.Connection = RunService.Heartbeat:Connect(function()
			self:Update()
		end)
	end

	function DistanceSoundController:Stop()
		if self.Connection then
			self.Connection:Disconnect()
			self.Connection = nil
		end

		self:RemoveEffects()
	end

	function DistanceSoundController:Destroy()
		self:Stop()
		ActiveControllers[self.Sound] = nil
	end

	local Controller = {}

	function Controller.RegisterSound(Sound: Sound, Config)
		if ActiveControllers[Sound] then return end

		local Instance = DistanceSoundController.new(Sound, Config)
		ActiveControllers[Sound] = Instance

		local PlayingConnection = Sound:GetPropertyChangedSignal("IsPlaying"):Connect(function()
			if Sound.IsPlaying then
				Instance:Start()
			else
				Instance:Stop()
			end
		end)

		if Sound.IsPlaying then
			Instance:Start()
		end

		-- Cleanup hook
		Sound.AncestryChanged:Connect(function(_, Parent)
			if not Parent then
				PlayingConnection:Disconnect()
				Instance:Destroy()
			end
		end)
		return Instance
	end

	return Controller
end
