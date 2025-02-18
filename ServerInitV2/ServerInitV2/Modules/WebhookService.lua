--[[
Type = ModuleScript
]]

Core = script.Parent.Parent
Modules = Core.Modules
ServerResources = Core.ServerResources

WebhookEvent = ServerResources.Webhook

StartServerWebhook = ""

JSON = game:GetService("HttpService")

function sendwebhook(data,webhook)
	local data = JSON:JSONEncode(data)
	print(data)
	JSON:PostAsync(webhook,data)
end

function getHex(num)
	local chars = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"}
	local hex = ""
	local x = num / 16
	local y = num % 16

	hex = chars[math.floor(x) + 1] .. chars[math.floor(y) + 1]

	return hex
end

function color3ToHex(color3)
	if not color3["r"] then return "#000000" end

	local r, g, b = color3.r * 255, color3.g * 255, color3.b * 255
	return "#" .. getHex(r) .. getHex(g) .. getHex(b)
end

Default_Avatar_URL = "https://cdn.discordapp.com/attachments/914692090846380062/914692227492642857/Aidens.png"

return {
	Init = function()
		wait(2)
		local data = 
		{
			["username"] = "Server Started",
			["avatar_url"] = Default_Avatar_URL,
			["content"] = ( "JobID: " .. tostring(game.JobId) .. " / ".. "Joined Players: ".. tostring(table.unpack(game.Players:GetChildren())) ),

		}
		sendwebhook(data,StartServerWebhook)


	end,

}