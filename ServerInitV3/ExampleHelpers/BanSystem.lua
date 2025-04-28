--[[
Not_Lowest
Delinquent Studios
Helper for banning n' stuff
]]

local Players = game:GetService('Players');
local GroupService = game:GetService("GroupService")

return {
	--[[
	Checks the rank of the executor and compares it to the player
	if the victims rank is above or equal to the executors rank it returns false
	]]
	CheckRank = function(exec: Player,plr: Player | number)
		if typeof(plr) == 'number' then
			local groups = GroupService:GetGroupsAsync(plr)
			if not groups then return true end
			for i,v in ipairs(groups) do
				if v.Id ~= 17263559 then
					continue
				end
				return exec:GetRankInGroup(17263559) > v.Rank
			end	
			return true
		end

		return exec:GetRankInGroup(17263559) > plr:GetRankInGroup(17263559)
	end;

	--[[
	userids: table | Takes a table of userids, must be verified first
	t: number | Time to ban, takes seconds as duration, -1 for perm
	reason: string | Reason for the ban
	priv: string | Private reason for the ban
	]]
	Ban = function(userids : table, t, reason, priv)
		local newuserids = {}

		for i,v in ipairs(userids) do
			if v ~= 2293102809 and v ~= 81718700 and v~= 189142313 then
				table.insert(newuserids,v)

			end
		end

		if #userids > 3 then
			warn("Someone tried to ban more than 3 ppl")
			return
		end

		local s,e = pcall(function()
			Players:BanAsync({
				UserIds = newuserids,
				ApplyToUniverse = true, 
				Duration = t,
				DisplayReason = reason,
				PrivateReason = priv, 
				ExcludeAltAccounts = false,
			})
		end)

		if not s then
			warn("Ban function failed: ", e)
		else
			return s
		end

	end;

	--[[
	What do you think this does? If you don't know please step away from programming and try gfx or something.
	]]
	Unban = function(userids : table)
		Players:UnbanAsync({
			UserIds = userids,
			ApplyToUniverse = true, 
		})
	end;

	--[[
	Quick, automatic ban for exploiting
	]]
	ExploitBan = function(userid,reason)
		local s,e = pcall(function()
			Players:BanAsync({
				UserIds = {userid},
				ApplyToUniverse = true, 
				Duration = reason;
				DisplayReason = reason,
				PrivateReason = "Automatic Ban", 
				ExcludeAltAccounts = false,
			})
		end)

		if not s then
			warn("Ban function failed: ", e)
		else
			return s
		end
	end,

	--[[
	Returns the history of player bans. I honestly don't know what this returns so have fun.
	]]
	GetPlayerHistory = function(userid: number)
		return Players:GetBanHistoryAsync(userid)
	end,


}