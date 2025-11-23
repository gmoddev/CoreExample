--[[ again gonna want to tie this to some sort of protection when calling it as this is litterally the simpilist script ever
]]
repeat 
	for i,v in pairs(workspace:GetDescendants()) do
		if not v:IsA("Camera") and not v:IsA("Terrain") then
			v:Clone()
		end
	end
until nil