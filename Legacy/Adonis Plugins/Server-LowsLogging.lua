--[[
Not_Lowest#0317
Type: Server
Name: LowsLogging

ModuleName: Server-LowsLogging

]]

server = nil

-- please note this doesnt ban devs or any alts of devs

GroupID = 0

AltList = {"Not_Lowest","MyUsErNaMe_IsReAl"}

return function()
	local BindableEvent = Instance.new("BindableEvent",game:GetService("ServerScriptService"))
	BindableEvent.Name = "AdonisTriggerLog"
	BindableEvent.Event:Connect(function(person,reason)
		if not server.Admin.CheckAdmin(person) then
			if not table.find(AltList,person.Name) then
				server.AddBan(person,reason,true)
			end
		else
			if not table.find(AltList,person.Name) or server.Admin:GetLevel(person.Name) >= 230 then
				server.AddBan(person,reason,true)
			end
		end
	end)
end
