--[[Type = Module
 
 I didn't make all of this, one of my friends gave me this script as an example, and it was modified a little bit and used because i didnt know how to use motorangles at the time
 
 And for that reason im also not going to give out all of the code particularly the init function because he still uses this
]]

local API = {}
local DoorsEvent = game:GetService("ReplicatedStorage").ServerRemotes.Doors
local TweenService = game:GetService("TweenService")
local SoundService = {
	DoorOpen = "rbxassetid://212709219";
	DoorClose = "rbxassetid://212709232";
}

function IsTeam(Player, Door)
	for i, ListedTeams in pairs(Door:FindFirstChild("InteractionInfo").AllowedTeams:GetChildren()) do
		if Player.Team == ListedTeams.Name or Player.TeamColor == ListedTeams.Value or ListedTeams.Name == "All" then
			return true
		end
	end
end

function Orientation(DoorType, Face)
	if Face == "front" and DoorType == "Single" then
		return -1.7
	elseif Face == "back" and DoorType == "Single" then
		return 1.7
	elseif Face == "back" and DoorType == "Double" then
		return {1.7, -1.7}
	elseif Face == "front" and DoorType == "Double" then
		return {-1.7, 1.7}
	else
		warn("Nil instance")
		return 0
	end
end

function OpenDoor(DoorObject, Value)
	if Value == true then
		local CFrameValue = Instance.new('CFrameValue')
		CFrameValue.Value = DoorObject.Object.DoorModel.MovementPart.CFrame

		local TweenInstance = TweenService:Create(CFrameValue, TweenInfo.new(DoorObject.InteractionInfo.TweenTime.Value), {Value = DoorObject.MoveToPart.CFrame})

		-- Move the model
		CFrameValue.Changed:Connect(function()
			DoorObject.Object.DoorModel:SetPrimaryPartCFrame(CFrameValue.Value)
		end)
		TweenInstance:Play()
		
		-- Ensure cf can get garbagecollected
		TweenInstance.Completed:Connect(function()
			TweenInstance:Destroy()
			CFrameValue:Destroy()
			
			return true
		end)
	elseif Value == false then
		local CFrameValue = Instance.new('CFrameValue')
		CFrameValue.Value = DoorObject.Object.DoorModel.MovementPart.CFrame

		local TweenInstance = TweenService:Create(CFrameValue, TweenInfo.new(DoorObject.InteractionInfo.TweenTime.Value), {Value = DoorObject.Object.OriginalPos.CFrame})

		-- Move the model
		CFrameValue.Changed:Connect(function()
			DoorObject.Object.DoorModel:SetPrimaryPartCFrame(CFrameValue.Value)
		end)
		TweenInstance:Play()

		-- Ensure cf can get garbagecollected
		TweenInstance.Completed:Connect(function()
			TweenInstance:Destroy()
			CFrameValue:Destroy()

			return true
		end)
	end
end

function IsRange(Player, DoorObject)
	local Distance = Player:DistanceFromCharacter(DoorObject.Center.Position) > DoorObject.InteractionInfo.Range.Value + 5 
	if not Distance then
		return true
	else
		return false
	end
end

function API:Initialize()
  -- removed for reasons
		if not IsRange(Player, DoorObject) then
			Player:Kick("Smh, Trying to exploit in my christian jail :(")
			return
		end
		
		if IsTeam(Player, DoorObject) then
			if DoorObject.InteractionInfo.DoorType.Value == "Single" then
				if DoorObject.InteractionInfo.IsOpen.Value == false and not DoorObject.InteractionInfo.InMotion.Value == true then
					local SoundInstance = Instance.new("Sound")
					SoundInstance.SoundId = SoundService.DoorOpen
					SoundInstance.Parent = DoorObject.Center
					
					DoorObject:FindFirstChild("InteractionInfo").IsOpen.Value = true
					DoorObject.Object.MotorPart.Motor.DesiredAngle = Orientation(DoorObject.InteractionInfo.DoorType.Value, WhatSide)
					DoorObject.InteractionInfo.InMotion.Value = true
					SoundInstance:Play()
					
					delay(DoorObject.InteractionInfo.IsOpenTime.Value, function()
						if DoorObject.InteractionInfo.IsAutoClose.Value == true then
							local SoundInstance1 = Instance.new("Sound")
							SoundInstance1.SoundId = SoundService.DoorClose
							SoundInstance1.Parent = DoorObject.Center
							SoundInstance1:Play()
							
							DoorObject.Object.MotorPart.Motor.DesiredAngle = 0
							DoorObject:FindFirstChild("InteractionInfo").IsOpen.Value = false
							
							wait(SoundInstance1.TimeLength + 0.1)
							SoundInstance1:Destroy()
						end
						
						DoorObject.InteractionInfo.InMotion.Value = false
						SoundInstance:Destroy()
					end)
				elseif DoorObject.InteractionInfo.InMotion.Value == false and DoorObject.InteractionInfo.IsOpen.Value == true then
					local SoundInstance1 = Instance.new("Sound")
					SoundInstance1.SoundId = SoundService.DoorClose
					SoundInstance1.Parent = DoorObject.Center
					SoundInstance1:Play()
					
					DoorObject.InteractionInfo.InMotion.Value = true
					DoorObject.Object.MotorPart.Motor.DesiredAngle = 0
					DoorObject:FindFirstChild("InteractionInfo").IsOpen.Value = false

					wait(SoundInstance1.TimeLength + 0.1)
					DoorObject.InteractionInfo.InMotion.Value = false
					SoundInstance1:Destroy()
				end
			elseif DoorObject.InteractionInfo.DoorType.Value == "Double" then
				if DoorObject.InteractionInfo.IsOpen.Value == false and not DoorObject.InteractionInfo.InMotion.Value == true then
					local SoundInstance = Instance.new("Sound")
					SoundInstance.SoundId = SoundService.DoorOpen
					SoundInstance.Parent = DoorObject.Center
					
					DoorObject:FindFirstChild("InteractionInfo").IsOpen.Value = true
					DoorObject.Object.MotorPart.Motor.DesiredAngle = Orientation(DoorObject.InteractionInfo.DoorType.Value, WhatSide)[1]
					DoorObject.Object1.MotorPart.Motor.DesiredAngle = Orientation(DoorObject.InteractionInfo.DoorType.Value, WhatSide)[2]
					DoorObject.InteractionInfo.InMotion.Value = true
					SoundInstance:Play()
		
					delay(DoorObject.InteractionInfo.IsOpenTime.Value, function()
						if DoorObject.InteractionInfo.IsAutoClose.Value == true then
							local SoundInstance1 = Instance.new("Sound")
							SoundInstance1.SoundId = SoundService.DoorClose
							SoundInstance1.Parent = DoorObject.Center
							SoundInstance1:Play()

							DoorObject.Object.MotorPart.Motor.DesiredAngle = 0
							DoorObject.Object1.MotorPart.Motor.DesiredAngle = 0
							DoorObject:FindFirstChild("InteractionInfo").IsOpen.Value = false

							wait(SoundInstance1.TimeLength + 0.1)
							SoundInstance1:Destroy()
						end
						
						DoorObject.InteractionInfo.InMotion.Value = false
						SoundInstance:Destroy()
					end)
				elseif DoorObject.InteractionInfo.InMotion.Value == false and DoorObject.InteractionInfo.IsOpen.Value == true then
					local SoundInstance1 = Instance.new("Sound")
					SoundInstance1.SoundId = SoundService.DoorClose
					SoundInstance1.Parent = DoorObject.Center
					SoundInstance1:Play()
					
					DoorObject.InteractionInfo.InMotion.Value = true
					DoorObject.Object.MotorPart.Motor.DesiredAngle = 0
					DoorObject.Object1.MotorPart.Motor.DesiredAngle = 0
					DoorObject:FindFirstChild("InteractionInfo").IsOpen.Value = false

					wait(SoundInstance1.TimeLength + 0.1)
					DoorObject.InteractionInfo.InMotion.Value = false
					SoundInstance1:Destroy()
				end
			elseif DoorObject.InteractionInfo.DoorType.Value == "Sliding" then
				if DoorObject.InteractionInfo.IsOpen.Value == false and not DoorObject.InteractionInfo.InMotion.Value == true then
					DoorObject.InteractionInfo.IsOpen.Value = true
					DoorObject.InteractionInfo.InMotion.Value = true
					OpenDoor(DoorObject, true)
					
					delay(DoorObject.InteractionInfo.IsOpenTime.Value, function()
						if DoorObject.InteractionInfo.IsAutoClose.Value == true then
							OpenDoor(DoorObject, false)
							wait(2)
							DoorObject.InteractionInfo.IsOpen.Value = false	
							DoorObject.InteractionInfo.InMotion.Value = false
						end
					end)
				elseif DoorObject.InteractionInfo.InMotion.Value == false and DoorObject.InteractionInfo.IsOpen.Value == true then

				end
			else
				warn("DoorType - "..DoorObject.InteractionInfo.DoorType.Value.."\nIs not a valid DoorType\n[1] Single\n[2] Double\n\nAre Supported Door Types")
			end
		end
	end)
end
return API