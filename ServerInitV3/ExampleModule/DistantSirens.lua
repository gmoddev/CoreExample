--[[
Not_Lowest
Delinquent Studios LLC
]]

return function(helpers, services)

	local Players = services.Players
	local RunService = services.RunService

	local DistanceSoundController = helpers.DistanceSoundController
	local LocalPlayer = Players.LocalPlayer

	local ValidSoundNames = {
		Airhorn = true,
		Manual = true,
		Wail = true,
		Yelp = true
	}

	local EffectFolders = {
		Airhorn = script:WaitForChild("AirhornDistant"),
		Manual = script:WaitForChild("ManualDistant"),
		Wail = script:WaitForChild("WailDistant"),
		Yelp = script:WaitForChild("YelpDistant")
	}

	local DistanceThresholdMultiplier = 0.5

	local ActiveControllers = {}

	local function HandleSound(Sound: Sound)
		if not Sound:IsA("Sound") then return end
		if not ValidSoundNames[Sound.Name] then return end
		if ActiveControllers[Sound] then return end

		local EffectFolder = EffectFolders[Sound.Name]
		if not EffectFolder then return end

		local ControllerInstance = DistanceSoundController.RegisterSound(Sound, {
			DistanceMultiplier = DistanceThresholdMultiplier,
			EffectFolder = EffectFolder
		})

		ActiveControllers[Sound] = ControllerInstance
	end

	local function CleanupSound(Sound: Sound)
		local Controller = ActiveControllers[Sound]
		if Controller then
			Controller:Destroy()
			ActiveControllers[Sound] = nil
		end
	end

	for _, Descendant in ipairs(workspace:GetDescendants()) do
		if Descendant:IsA("Sound") then
			HandleSound(Descendant)
		end
	end

	workspace.DescendantAdded:Connect(function(Descendant)
		if Descendant:IsA("Sound") then
			HandleSound(Descendant)
		end
	end)

	workspace.DescendantRemoving:Connect(function(Descendant)
		if Descendant:IsA("Sound") then
			CleanupSound(Descendant)
		end
	end)

end
