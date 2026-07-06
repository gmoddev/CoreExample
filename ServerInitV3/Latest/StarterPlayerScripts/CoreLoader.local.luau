--[[
Not_Lowest
1/29/2025
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = ReplicatedStorage:FindFirstChild("Core")

if Core then
	local RequiredCore = require(Core)
	if type(RequiredCore) == "function" then
		RequiredCore(ReplicatedStorage.Client)
	end
end