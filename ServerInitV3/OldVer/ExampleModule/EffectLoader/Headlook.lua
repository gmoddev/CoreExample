--[[
Not_Lowest
Delinquent Studios
Inspired from various headlook scripts, I just did it better :p
]]

return function(helpers,services)
	local Players           = services.Players
	local RunService        = services.RunService
	local TweenService      = services.TweenService

	local HeadLookRE = helpers.Directory.Remotes:FindFirstChild("HeadLook")

	local player            = Players.LocalPlayer

	local SmoothSpeed       = 8                          -- lower = smoother
	local MaxPitchAngle     = math.rad(50)               -- clamp up/down
	local ReplicateRate     = 1.5                        -- times per second

	local clamp             = math.clamp
	local asin              = math.asin

	local camera            = workspace.CurrentCamera
	local character         = player.Character or player.CharacterAdded:Wait()
	local root, neck        = character:WaitForChild("HumanoidRootPart"), character:FindFirstChild("Neck", true)
	local yOffset           = neck and neck.C0.Y or 0

	local function onCharacterAdded(char)
		character = char
		root      = char:WaitForChild("HumanoidRootPart")
		neck      = char:FindFirstChild("Neck", true)
		yOffset   = neck and neck.C0.Y or 0
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	
	HeadLookRE.OnClientEvent:Connect(function(Plr, c0)
		local OtherNeck = Plr.Character and Plr.Character:FindFirstChild("Neck", true)
		if OtherNeck then
			TweenService:Create(
				OtherNeck,
				TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ C0 = c0 }
			):Play()
		end
	end)

	local timeSinceLastReplicate = 0
	RunService:BindToRenderStep("HeadLook", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if _G["Cloaked"] then return end
		if not neck or not root or not camera then return end

		-- 1) local head‐tracking
		local LookVec     = root.CFrame:ToObjectSpace(camera.CFrame).LookVector
		local BaseOffset  = CFrame.new(0, yOffset, 0)
		local yaw, pitch

		-- yaw
		if character.Humanoid.RigType == Enum.HumanoidRigType.R15 then
			yaw = CFrame.Angles(0, -asin(LookVec.X), 0)
		else
			yaw = CFrame.Angles(3*math.pi/2, 0, math.pi) * CFrame.Angles(0, 0, -asin(LookVec.X))
		end

		-- pitch
		pitch = CFrame.Angles(clamp(asin(LookVec.Y), -MaxPitchAngle, MaxPitchAngle), 0, 0)

		-- interpolate
		local targetC0 = BaseOffset * yaw * pitch
		neck.C0 = neck.C0:Lerp(targetC0, clamp(SmoothSpeed * dt, 0, 1))

		-- 2) rate-limited replicate
		timeSinceLastReplicate += dt
		if timeSinceLastReplicate >= (1/ReplicateRate) then
			timeSinceLastReplicate -= (1/ReplicateRate)
			HeadLookRE:FireServer(neck.C0)
		end
	end)

end