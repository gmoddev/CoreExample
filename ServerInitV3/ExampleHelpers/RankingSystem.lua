--[[
Not_Lowest
Delinquent Studios
Ranking System indended for CMDR
]]

local Players = game:GetService("Players")

local Group_ID = 17263559

local GroupMappings = {
	DefaultUtil = "Developer",
	DefaultAdmin = "Developer",
	DefaultDebug = "Developer",
	Development = "Developer",
	Moderator = "Mod";
	Aliases = "TrialMod";
}


local CommandOverride = {
	

}

local function RemoveEmojisAndSpaces(text)
	if text == '🛠️ Studio Staff' then text = 'StudioStaff' end
	if text == '🛠️ Developer' then text = 'Developer' end
	text = text:gsub("[\240-\244][\128-\191][\128-\191][\128-\191]", "")
	text = text:gsub("%s+", "")
	text = text:gsub("🛡️","")

	return text
end

local function ParseGroup(Group)
	if type(Group) == "table" then
		local newGroup = {}
		local seen = {}

		for _, v in ipairs(Group) do
			local mappedValue = GroupMappings[v] or v
			if not seen[mappedValue] then
				seen[mappedValue] = true
				table.insert(newGroup, mappedValue)
			end
		end

		return newGroup
	end

	return GroupMappings[Group] or Group
end

local AllPermsUserid = {
	[81718700] = true;
	[-1] = true; -- test users
	[-2] = true;
	[-3] = true;
}

local AllPerms = {
	Owner = true;
	Management = true;
	['StudioStaff'] = true;
	['Developer'] = true;
}

local Hierarchy = {
	"Founder";
	"ProjectLead";
	"Management";
	"StudioStaff";
	"SeniorAdmin";
	"Admin";
	"Mod";
	"TrialMod";
}

local function GetRoleIndex(Role)
	Role = Role:match("^%s*(.-)%s*$") 
	Role = Role:lower()

	for Index, Name in ipairs(Hierarchy) do
		if Name:lower() == Role then
			return Index
		end
	end
	return #Hierarchy
end

local function CanAccessHierarchy(role)
	role = RemoveEmojisAndSpaces(role)
	local index = GetRoleIndex(role)
	return index < #Hierarchy or Hierarchy[#Hierarchy]:lower() == role:lower()
end

local function CanAccess(plr: Player)
	local role = plr:GetRoleInGroup(Group_ID)
	return table.find(Hierarchy, ParseGroup(role)) ~= nil
end

local function GetRole(plr: Player)
	return plr:GetRoleInGroup(Group_ID)
end

local function CanRun(Context)
	local Player = Context.Executor
	if not Player or not Player:IsA("Player") then
		return "Invalid executor."
	end

	local CommandGroup = Context.Group
	local GroupRole = RemoveEmojisAndSpaces(Player:GetRoleInGroup(Group_ID))
	local CanUse = false

	if (CommandGroup == "PrivateServer" or (type(CommandGroup) == "table" and table.find(CommandGroup, "PrivateServer"))) and Player:GetAttribute("IsPrivateServerOwner") == true then
		CanUse = true
	end
	local CommandIndex
	if type(CommandGroup) == "table" then
		CommandIndex = 253
		for _, role in ipairs(CommandGroup) do
			local ParsedRole = ParseGroup(role)
			local Index = GetRoleIndex(ParsedRole)
			if Index and Index < CommandIndex then
				CommandIndex = Index
			end
		end
	else
		CommandIndex = GetRoleIndex(ParseGroup(CommandGroup))
	end
	local RoleIndex = GetRoleIndex(GroupRole)
	if not RoleIndex or not CommandIndex then
		warn(RoleIndex,CommandIndex,CommandGroup,Player)
		warn("Invalid role or command group:", RoleIndex, CommandIndex)
		return "An error occurred: Invalid role or command group."
	end

	local Override = CommandOverride[Context.Alias]
	if Override then
		if Override[Player.UserId] then
			CanUse = true
		end
	end
	if AllPermsUserid[Player.UserId] then
		CanUse = true
	end

	if AllPerms[GroupRole] or RoleIndex <= CommandIndex then
		CanUse = true
	end

	if not CanUse then
		return "DO: You do not have access to this command."
	end

end

local function IsStaff(plr: Player)
	local Role = GetRole(plr)
	return CanAccessHierarchy(Role)
	
	
end

return {
	CanRun = CanRun,
	GetRoleIndex = GetRoleIndex,
	Hierarchy = Hierarchy,
	CanAccess = CanAccess,
	GetRole = GetRole,
	Group_ID = Group_ID;
	IsStaff = IsStaff
}