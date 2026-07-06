return function(_Runtime)
	local Lifecycle = {}

	local function RunHook(Core, Hook, ...)
		local CapturedCount = select("#", ...)
		local CapturedArgs = { ... }

		task.spawn(function()
			local Success, Result = xpcall(function()
				Hook.Callback(table.unpack(CapturedArgs, 1, CapturedCount))
			end, function(Error)
				return debug.traceback(tostring(Error), 2)
			end)

			if not Success then
				Core.Logger:Error(("%s failed\n%s"):format(Hook.Name, tostring(Result)))
			end
		end)
	end

	local function RunCharacterHooks(Core, Hooks, Character, Player)
		for _, Hook in ipairs(Hooks.CharacterAdded) do
			RunHook(Core, Hook, Character, Player)
		end
	end

	local function RunPlayerHooks(Core, Hooks, Player)
		Core.Logger:Stage("Running player hooks for", Player.Name)

		for _, Hook in ipairs(Hooks.PlayerAdded) do
			RunHook(Core, Hook, Player)
		end

		if Player.Character then
			RunCharacterHooks(Core, Hooks, Player.Character, Player)
		end

		local Connection = Player.CharacterAdded:Connect(function(Character)
			RunCharacterHooks(Core, Hooks, Character, Player)
		end)

		table.insert(Core._LifecycleConnections, Connection)
	end

	function Lifecycle.Bind(Core, Hooks)
		local Connections = Core._LifecycleConnections
		local RunService = Core.Services.RunService
		local Players = Core.Services.Players

		if RunService:IsServer() then
			for _, Player in ipairs(Players:GetPlayers()) do
				RunPlayerHooks(Core, Hooks, Player)
			end

			table.insert(Connections, Players.PlayerAdded:Connect(function(Player)
				RunPlayerHooks(Core, Hooks, Player)
			end))
		else
			local Player = Players.LocalPlayer

			if Player.Character then
				RunCharacterHooks(Core, Hooks, Player.Character, Player)
			end

			table.insert(Connections, Player.CharacterAdded:Connect(function(Character)
				RunCharacterHooks(Core, Hooks, Character, Player)
			end))
		end

		return Connections
	end

	return Lifecycle
end
