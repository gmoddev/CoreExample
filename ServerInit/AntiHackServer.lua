--[[ Type = Module ]]

local API = {}
local PlayerService = game:GetService("Players")
local RemoteEvents = game:GetService("ReplicatedStorage").ServerRemotes
AnticheatEmote = RemoteEvents.NotifAnticheat
AnticheatWebhook = "Removed for security purposes"
DatastoreService = game:GetService("DataStoreService")

function GetPlayerKey(plr)
	return _G[plr.UserId.."-ackey"]
end
function SetPlayerKey(plr,key)
	_G[plr.UserId.."-ackey"] = tostring(key)
end

local CD = coroutine.wrap(function(plr)
	_G[plr.UserId.."-responsetimer"] = 15
	while wait(1) do
		_G[plr.UserId.."-responsetimer"] -= 1
		if _G[plr.UserId.."-responsetimer"] == 0 then
			plr:Kick("Client response timer froze")
		end
	end
end)

--== The following is a bunch of ids that is in modules for public use, prebanned plrs
local LeakingServer = require(7784069110)

local Hacking = require(7784079118)

local BannedStrings = {
	"st4rving","yeah_alt"
}

function GetBanned(plr)
	if table.find(LeakingServer,plr.UserId) or table.find(Hacking,plr.UserId) then
		return true
	end
	
	for _,v in pairs(BannedStrings) do
		if string.find(string.lower(plr.Name),v) then
			return true
		end
	end
end

AnticheatEmote.OnServerEvent:Connect(function(plr,a1,a2)
	if a1 ~= "ResponseTimer" then
		plr:Kick("Your username has been logged :)")
	else
		if GetPlayerKey(plr) == "" then
			if a2 then
				SetPlayerKey(plr,a2)
				CD(plr)
			else
				plr:KicK("Anticheat")
			end
			
		else
			if a2 ~= GetPlayerKey(plr) then
				print(GetPlayerKey(plr))
				plr:Kick("Player response key invalid")
			else
				if _G[plr.UserId.."-responsetimer"] <= 7 then
					_G[plr.UserId.."-responsetimer"] = 15
				else
					print(_G[plr.UserId.."-responsetimer"])
					plr:Kick("Suspicious response send")
				end
			end
		end
	end
end)

function API:Initialize()
	PlayerService.PlayerAdded:Connect(function(plr)
		
		if GetBanned(plr) then
			plr:Kick("You've been blacklisted for one of multiple reasons, contact a developer if you believe this is a mistake")
		end
	end)
	
end
return API