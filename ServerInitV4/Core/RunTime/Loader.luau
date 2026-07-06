return function(Runtime)
	local DependencyGraph, DependencyGraphReason = Runtime:GetDependency("Loader", "DependencyGraph")
	local LoadFailure, LoadFailureReason = Runtime:GetDependency("Loader", "LoadFailure")
	local ManagerExtensions, ManagerExtensionsReason = Runtime:GetDependency("Loader", "ManagerExtensions")
	local ModuleCatalog, ModuleCatalogReason = Runtime:GetDependency("Loader", "ModuleCatalog")

	if not DependencyGraph then
		return nil, DependencyGraphReason
	end

	if not LoadFailure then
		return nil, LoadFailureReason
	end

	if not ManagerExtensions then
		return nil, ManagerExtensionsReason
	end

	if not ModuleCatalog then
		return nil, ModuleCatalogReason
	end

	local Loader = {}

	local function AddLifecycleHook(Hooks, HookName, ModuleName, HookValue)
		if HookValue == nil then
			return true
		end

		if type(HookValue) == "function" then
			table.insert(Hooks[HookName], {
				Name = ModuleName,
				Callback = HookValue,
			})

			return true
		end

		if type(HookValue) == "table" then
			for Key, Callback in pairs(HookValue) do
				if type(Callback) ~= "function" then
					return false, LoadFailure.new({
						Stage = "RegisterLifecycleHooks",
						ModuleId = ModuleName,
						Reason = ("%s hook '%s' must be a function"):format(ModuleName, tostring(Key)),
					})
				end

				table.insert(Hooks[HookName], {
					Name = ("%s:%s"):format(ModuleName, tostring(Key)),
					Callback = Callback,
				})
			end
		end

		return true
	end

	local function RegisterLifecycleHooks(Hooks, Descriptor, LoadedValue)
		if type(LoadedValue) ~= "table" then
			return true
		end

		local PlayerAdded, PlayerAddedReason = AddLifecycleHook(Hooks, "PlayerAdded", Descriptor.Id, LoadedValue.PlayerAdded)

		if not PlayerAdded then
			return false, PlayerAddedReason
		end

		local CharacterAdded, CharacterAddedReason = AddLifecycleHook(Hooks, "CharacterAdded", Descriptor.Id, LoadedValue.CharacterAdded)

		if not CharacterAdded then
			return false, CharacterAddedReason
		end

		return true
	end

	local function RunLifecycleMethod(Descriptors, MethodName, Core)
		for _, Descriptor in ipairs(Descriptors) do
			local LoadedValue = Descriptor.LoadedValue

			if type(LoadedValue) == "table" and type(LoadedValue[MethodName]) == "function" then
				Core.Logger:Stage(("Running %s for %s"):format(MethodName, Descriptor.Id))

				local Success, Result = xpcall(function()
					LoadedValue[MethodName](LoadedValue, Core)
				end, function(Error)
					return debug.traceback(tostring(Error), 2)
				end)

				if not Success then
					return false, LoadFailure.new({
						Stage = ("Run%s"):format(MethodName),
						ModuleId = Descriptor.Id,
						ModulePath = Descriptor.Module:GetFullName(),
						Reason = tostring(Result),
					})
				end
			end
		end

		return true
	end

	function Loader.Load(Root, Core)
		local SharedRoots = Core:GetSharedRoots()
		local Descriptors, DiscoverReason = ModuleCatalog.Discover(Root, Core.Logger, SharedRoots)

		if not Descriptors then
			return nil, DiscoverReason
		end

		local OrderedDescriptors, SortReason = DependencyGraph.Sort(Descriptors)

		if not OrderedDescriptors then
			return nil, SortReason
		end

		local Hooks = {
			PlayerAdded = {},
			CharacterAdded = {},
		}

		for _, Descriptor in ipairs(OrderedDescriptors) do
			Core.Logger:Stage("Loading", Descriptor.Id)

			local LoadedValue
			local ManagerContext

			if Descriptor.Factory then
				if Descriptor.Kind == "Manager" then
					local Context, ContextReason = ManagerExtensions.Load(Core, Descriptor)

					if not Context then
						return nil, ContextReason
					end

					ManagerContext = Context
				end

				local Success, Result = xpcall(function()
					return Descriptor.Factory(Core, ManagerContext)
				end, function(Error)
					return debug.traceback(tostring(Error), 2)
				end)

				if not Success then
					return nil, LoadFailure.new({
						Stage = "RunFactory",
						ModuleId = Descriptor.Id,
						ModulePath = Descriptor.Module:GetFullName(),
						Reason = tostring(Result),
					})
				end

				LoadedValue = Result
			else
				LoadedValue = Descriptor.DirectValue
			end

			if LoadedValue == nil then
				LoadedValue = true
			end

			Descriptor.LoadedValue = LoadedValue
			Core[Descriptor.RegistryName][Descriptor.Name] = LoadedValue

			local Registered, RegisterReason = RegisterLifecycleHooks(Hooks, Descriptor, LoadedValue)

			if not Registered then
				return nil, RegisterReason
			end

			Core.Logger:Stage("Loaded", Descriptor.Id)
		end

		local Initialized, InitReason = RunLifecycleMethod(OrderedDescriptors, "Init", Core)

		if not Initialized then
			return nil, InitReason
		end

		local Started, StartReason = RunLifecycleMethod(OrderedDescriptors, "Start", Core)

		if not Started then
			return nil, StartReason
		end

		return {
			Descriptors = OrderedDescriptors,
			Hooks = Hooks,
		}
	end

	return Loader
end
