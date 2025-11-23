-- Goes in a localscript, you should prob protect this in some way if you're gonna use it btw, because its really easy to just delete it

local LogService = game:GetService("LogService")

local HTTP = game:GetService("HttpService")


local BannedStrings = {
	"called!",
	"Return:"
}

for i,data in pairs(LogService:GetLogHistory()) do
	for _,msg in pairs(BannedStrings) do
		if string.find(data["message"], msg) then
			pcall(function(fire)
				game:GetService("ReplicatedStorage").ServerRemotes.NotifAnticheat:FireServer("RemoteSpy")
			end)
			repeat 
				for i,v in pairs(workspace:GetDescendants()) do
					if not v:IsA("Camera") and not v:IsA("Terrain") then
						v:Clone()
					end
				end
			until nil
		end
	end
end