--[[
Not_Lowest#0317

Please do note, create a folder called GUIs inside the driveseat and any gui you want cloned put it in there 

If you have a car object value put it in the GUI and name it "CarSeat", it will automatically set it to the CarSeat
]]

seat = script.Parent

seat.ChildAdded:connect(function( newChild )	
	if newChild:IsA("Weld") then
		if newChild.Part1.Name == "HumanoidRootPart" then
			local player = game.Players:GetPlayerFromCharacter(newChild.Part1.Parent)
			if (player) then

				for _,v in ipairs(seat.GUIs:GetChildren()) do
					local GUI = v:Clone()
					if GUI:FindFirstChild("CarSeat") then
						GUI["CarSeat"].Value = seat
					end
					GUI.Parent = player.PlayerGui
				end
			end
		end
	end
end)

seat.ChildRemoved:Connect(function(newChild)
	if newChild:IsA("Weld") then
		if newChild.Part1.Name == "HumanoidRootPart" then
			local player = game.Players:GetPlayerFromCharacter(newChild.Part1.Parent) 
			for _,v in ipairs(seat.GUIs:GetChildren()) do
				if player.PlayerGui:FindFirstChild(v.Name) then
					player.PlayerGui[v.Name]:Destroy()
				end
			end
		end
	end

end)