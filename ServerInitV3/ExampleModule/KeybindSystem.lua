--[[ 
 Not_Lowest
 Delinquent Studios
 4/27/2025
]]

return function(helpers, services)
	local CAS      = services.ContextActionService
	local Core     = helpers.CoreService
	local LogStage = Core.LogStage

	local Remotes = helpers.Directory.Remotes

	local RebindRemote: BindableFunction = Remotes:WaitForChild("Rebind")

	LogStage("Loading Keybind System")

	local meta = {}
	meta.__index = meta

	function meta:Rebind(Action, NewKey)
		if not self.Actions[Action] then
			return false
		end
		
		CAS:UnbindAction(Action)

		local keys = {}
		if typeof(NewKey) == "EnumItem" then
			assert(NewKey.EnumType == Enum.KeyCode, 
				("[%s] Rebind expects Enum.KeyCode"):format(Action))
			keys = { NewKey }
		elseif type(NewKey) == "table" then
			for _, k in ipairs(NewKey) do
				assert(typeof(k) == "EnumItem" and k.EnumType == Enum.KeyCode,
					("[%s] Rebind table must contain only Enum.KeyCode"):format(Action))
			end
			keys = NewKey
		else
			error(("[%s] Rebind newKey must be Enum.KeyCode or table of them"):format(Action))
		end

		CAS:BindAction(Action, function(_, state)
			if state == Enum.UserInputState.Begin then
				self.Actions[Action](state)
			end
		end, false, table.unpack(keys))

		self.Keybinds[Action] = keys
	end

	local KeybindSystem = setmetatable({
		Keybinds = {},  -- [actionName] = { Enum.KeyCode, … }
		Actions  = {},  -- [actionName] = callback()
	}, meta)

	--// Where its loaded here
	local Managers = Core.LoadManagers(script, KeybindSystem, services)
	for Action, module in pairs(Managers) do
		assert(type(module.Action) == "function",
			("[%s] must return .Action"):format(Action))

		local def = module.DefaultKey
		local keys = {}

		if typeof(def) == "EnumItem" then
			assert(def.EnumType == Enum.KeyCode,
				("[%s] DefaultKey must be Enum.KeyCode"):format(Action))
			keys = { def }

		elseif type(def) == "table" then
			for _, k in ipairs(def) do
				assert(typeof(k) == "EnumItem" and k.EnumType == Enum.KeyCode,
					("[%s] DefaultKey table must contain only Enum.KeyCode"):format(Action))
			end
			keys = def

		else
			error(("[%s] DefaultKey must be Enum.KeyCode or table of them"):format(Action))
		end

		KeybindSystem.Actions[Action] = module.Action

		CAS:BindAction(Action, function(_, state)
			if state == Enum.UserInputState.Begin then
				module.Action()
			end
		end, false, table.unpack(keys))

		KeybindSystem.Keybinds[Action] = keys
	end

	RebindRemote.OnInvoke = function(action,key)
		return KeybindSystem:Rebind(action,key)
	end

	helpers.KeybindSystem = KeybindSystem
	return KeybindSystem
end
