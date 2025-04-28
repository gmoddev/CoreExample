--[[
Not_Lowest
Delinquent Studios
4/27/2025
]]

return function(helpers, services)
	local Players = services.Players
	local ContextActionService: ContextActionService = services.ContextActionService
	local TweenService: TweenService = services.TweenService
	
	local RunEvent: RemoteEvent = helpers.Directory.Remotes.Run
	
	local Player: Player = Players.LocalPlayer
	
	local Character = Player.Character
	
	local DefaultFOV = 70
	local SprintFOV = 85
	local TweenTime = 0.25
	
	local TweenInfo = TweenInfo.new(TweenTime,Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	local Camera = workspace:WaitForChild("CurrentCamera",10)
	
	local IsSprinting = false
	local CurrentTween = nil
	
	local function CharacterAdded(char)
		Character = Player.Character	
		Camera = workspace:WaitForChild("CurrentCamera",10)
	end
	
	if Character then
		CharacterAdded(Character)
	end
	
	Player.CharacterAdded:Connect(CharacterAdded)
	
	local function GetCharacterWeapon()
		return Character:FindFirstChildOfClass("Tool")
	end
	
	local function GetWeaponType()
		local tool: Tool? = GetCharacterWeapon()
		return tool:GetAttribute("Weapon") and "Weapon" or "Other"
	end
	
	local function SpecialEffects(state)
		if CurrentTween then
			CurrentTween:Cancel()
		end
		
		CurrentTween = TweenService:Create(Camera,TweenInfo,{FieldOfView = (state == Enum.UserInputState.End and DefaultFOV or SprintFOV)})
		CurrentTween:Play()
	end
	
	local function Binding (state: Enum.UserInputState, obj)
		local CharConfig = Character.Config
		local Stamina = CharConfig.Stamina
		
		if state == Enum.UserInputState.End then
			IsSprinting = false
			SpecialEffects()
			return RunEvent:FireServer(2)
		end
		
		if Stamina.Value > 10 then
			return
		end
		IsSprinting = true
		SpecialEffects()
		RunEvent:FireServer(1)
	end
	
	RunEvent.OnClientEvent:Connect(Binding)

	return {
		DefaultKey = {Enum.KeyCode.RightShift, Enum.KeyCode.Thumbstick2};
		Action = Binding
	}
end
