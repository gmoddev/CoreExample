--[[
Author: Not_Lowest#0317
Description: A better version of my previous bank system that was for Simple Studios LTD
]]

ServerStorage = game:GetService("ServerStorage")
ServerScriptService = game:GetService("ServerScriptService")
ReplicatedStorage = game:GetService("ReplicatedStorage")
TweenService = game:GetService("TweenService")

--== Door System ==--

BankSystem = workspace.Banksystem

VaultDoorSystem = BankSystem.VaultDoor
Movements = VaultDoorSystem.DoorMovements
VaultDoor = VaultDoorSystem.Door
SoundPart = BankSystem.SoundPart

HackingSystem = BankSystem.HackingSystem
HackingDevice = HackingSystem.HackingDevice
HackingReader = HackingSystem.Reader


--== BOOLS ==--

IsHacking = false
IsOpen = false
Detected = false

--== Code ==--

DoorOpenTweenTime = TweenInfo.new(5)

--== Functions ==--

function TeleportPlayers()
	
end

function OpenDoors()
	for _,Door in pairs(VaultDoor:GetChildren()) do
		local e = TweenService:Create(
			Door,
			DoorOpenTweenTime,
			{Position = Vector3.new(Movements.Open[Door.Name].CFrame.X, Movements.Open[Door.Name].CFrame.Y, Movements.Open[Door.Name].CFrame.Z)}
		)

		e:Play()
		SoundPart.OpenDoor:Play()
	end
end

function CloseDoors()
	for _,Door in pairs(VaultDoor:GetChildren()) do
		local e = TweenService:Create(
			Door,
			DoorOpenTweenTime,
			{Position = Vector3.new(Movements.Open[Door.Name].CFrame.X, Movements.Open[Door.Name].CFrame.Y, Movements.Open[Door.Name].CFrame.Z)}
		)

		e:Play()
		SoundPart.CloseDoor:Play()
	end
end




function Reset()
	CloseDoors()
	IsHacking = false
	IsOpen = false
	Detected = false
	
	HackingDevice.ScreenPart.SurfaceGui.Frame.Detected.Visible = false
	HackingDevice.ScreenPart.SurfaceGui.Frame.Complete.Visible = false
	HackingDevice.ScreenPart.SurfaceGui.Frame.HackBack.Green.Size = UDim2.new(0,0,1,0)
	
	for _,v in pairs(HackingDevice:GetChildren()) do
		v.Transparency = 1
		if v:FindFirstChild("SurfaceGui") then
			v.SurfaceGui.Enabled = false
		end
	end
end
function Detect()
	if Detected == false then
		coroutine.resume(coroutine.create(function()
			SoundPart.Alarm:Play()
			Detected = true
			HackingDevice.ScreenPart.SurfaceGui.Frame.Detected.Visible = true		
			wait(50)
			SoundPart.Alarm:Stop()
		end))
	end
end

function StartBankRobbery()
	OpenDoors()
	wait(10)
	Detect()
	wait(50)
	SoundPart.Alarm:Stop()
	wait(140)
	Reset()
end



function StartHacking()
	IsHacking = true
	for _,v in pairs(HackingDevice:GetChildren()) do
		v.Transparency = 0
		if v:FindFirstChild("SurfaceGui") then
			v.SurfaceGui.Enabled = true
		end
	end
	local MovePart = HackingDevice.ScreenPart.SurfaceGui.Frame.HackBack.Green

	local HackingTime = 15
	local HackingTimeLeft = 0

	while wait(math.random(1/2,2)) do
		HackingTimeLeft += 1
		
		local RandomNumber = math.random(1,50)
		if RandomNumber == 14 then
			Detect()
			
		end
		
		MovePart:TweenSize(UDim2.new(HackingTimeLeft/HackingTime,0,1,0), Enum.EasingDirection.In, Enum.EasingStyle.Linear, 0.1)
		if HackingTimeLeft >= HackingTime then
			print("DONE!")
			break
		end
	end
	HackingDevice.ScreenPart.SurfaceGui.Frame.Complete.Visible = true
	StartBankRobbery()
	
end

function Kick(plr)
	plr:Kick("Hacking")
end

--== Hacking System ==--

function CheckDistance(HackingReader,plr)
	return (HackingReader.CFrame.p - plr.Character.HumanoidRootPart.CFrame.p).Magnitude > 15
end

HackingReader.ATT.ProximityPrompt.Triggered:Connect(function(plr)

	if CheckDistance(HackingReader,plr)  then
		Kick(plr)
	else
		if HackingReader.ATT.ProximityPrompt.Enabled == true then
			if IsHacking == false then
				HackingReader.ATT.ProximityPrompt.Enabled = false
				StartHacking()
			end

		else
			Kick(plr)
		end
	end
end)
