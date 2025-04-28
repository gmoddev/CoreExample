--[[
Not_Lowest
Delinquent Studios
Not the most efficent way to do it
]]

return function(helpers,services)
	local Players       = services.Players
	
	local HeadLookRE    = helpers.Directory.Remotes.HeadLook

	local debounce = {}

	local MAX_DIST_SQ = 10 * 10

	HeadLookRE.OnServerEvent:Connect(function(player, neckCFrame)
		if typeof(neckCFrame) ~= "CFrame" then return end
		if debounce[player] then return end
		debounce[player] = true

		local char = player.Character
		local head = char and char:FindFirstChild("Head")
		if head then
			local origin = head.Position

			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= player then
					local oChar = other.Character
					local oHead = oChar and oChar:FindFirstChild("Head")
					if oHead then
						local diff = oHead.Position - origin
						if diff.X*diff.X + diff.Y*diff.Y + diff.Z*diff.Z <= MAX_DIST_SQ then
							HeadLookRE:FireClient(other, player, neckCFrame)
						end
					end
				end
			end
		end

		task.delay(0.2, function()
			debounce[player] = nil
		end)
	end)

	Players.PlayerRemoving:Connect(function(leaver)
		debounce[leaver] = nil
	end)

end