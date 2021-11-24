--[[ Type = Module ]]

local module = {}
RunService = game:GetService("RunService")

function module:Initialize()
	game:GetService("Players").PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function(char)
			for _,v in pairs(char:GetDescendants()) do
				if v:IsA("CharacterMesh") then
					v:Destroy()
					if RunService:IsStudio() then
						print(v.Name .. "" .. type(v))
					end
						
				end
			end
		end)
	end)
end

return module
