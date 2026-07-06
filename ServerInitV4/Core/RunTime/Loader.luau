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

	local function GetDependencyKind(RequirementId)
		local Separator = string.find(RequirementId, ":", 1, true)

		if not Separator then
			return nil
		end

		return string.sub(RequirementId, 1, Separator - 1)
	end

	local function SplitDescriptorsByPhase(Descriptors)
		local HelperDescriptors = {}
		local MiddlewareDescriptors = {}
		local ManagerDescriptors = {}

		for _, Descriptor in ipairs(Descriptors) do
			if Descriptor.Kind == "Helper" then
				table.insert(HelperDescriptors, Descriptor)
			elseif Descriptor.Kind == "Middleware" then
				table.insert(MiddlewareDescriptors, Descriptor)
			else
				table.insert(ManagerDescriptors, Descriptor)
			end
		end

		return HelperDescriptors, MiddlewareDescriptors, ManagerDescriptors
	end

	local function ContainsKind(Kinds, Kind)
		for _, AllowedKind in ipairs(Kinds) do
			if Kind == AllowedKind then
				return true
			end
		end

		return false
	end

	local function ValidatePhaseDependencies(Descriptors, AllowedKinds)
		for _, Descriptor in ipairs(Descriptors) do
			for _, RequirementId in ipairs(Descriptor.Requires) do
				local RequirementKind = GetDependencyKind(RequirementId)

				if not ContainsKind(AllowedKinds, RequirementKind) then
					return false, LoadFailure.new({
						Stage = "ResolveDependencies",
						ModuleId = Descriptor.Id,
						ModulePath = Descriptor.Module and Descriptor.Module:GetFullName() or nil,
						Reason = ("%s modules cannot depend on %s because Core loads phases in this order: Helpers, Middleware, Managers"):format(Descriptor.Kind, RequirementId),
						Dependency = RequirementId,
						Expected = ("One of these dependency kinds: %s"):format(table.concat(AllowedKinds, ", ")),
					})
				end
			end
		end

		return true
	end

	local function AddSatisfiedIds(SatisfiedIds, Descriptors)
		for _, Descriptor in ipairs(Descriptors) do
			SatisfiedIds[Descriptor.Id] = true
		end
	end

	local function AppendDescriptors(Target, Source)
		for _, Descriptor in ipairs(Source) do
			table.insert(Target, Descriptor)
		end
	end

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

		local HelperDescriptors, MiddlewareDescriptors, ManagerDescriptors = SplitDescriptorsByPhase(Descriptors)
		local HelpersValid, HelpersValidReason = ValidatePhaseDependencies(HelperDescriptors, { "Helper" })

		if not HelpersValid then
			return nil, HelpersValidReason
		end

		local MiddlewareValid, MiddlewareValidReason =
			ValidatePhaseDependencies(MiddlewareDescriptors, { "Helper", "Middleware" })

		if not MiddlewareValid then
			return nil, MiddlewareValidReason
		end

		local ManagersValid, ManagersValidReason =
			ValidatePhaseDependencies(ManagerDescriptors, { "Helper", "Middleware", "Manager" })

		if not ManagersValid then
			return nil, ManagersValidReason
		end

		local OrderedHelpers, HelperSortReason = DependencyGraph.Sort(HelperDescriptors)

		if not OrderedHelpers then
			return nil, HelperSortReason
		end

		local SatisfiedIds = {}
		AddSatisfiedIds(SatisfiedIds, OrderedHelpers)

		local OrderedMiddleware, MiddlewareSortReason = DependencyGraph.Sort(MiddlewareDescriptors, SatisfiedIds)

		if not OrderedMiddleware then
			return nil, MiddlewareSortReason
		end

		AddSatisfiedIds(SatisfiedIds, OrderedMiddleware)

		local OrderedManagers, ManagerSortReason = DependencyGraph.Sort(ManagerDescriptors, SatisfiedIds)

		if not OrderedManagers then
			return nil, ManagerSortReason
		end

		local OrderedDescriptors = {}
		AppendDescriptors(OrderedDescriptors, OrderedHelpers)
		AppendDescriptors(OrderedDescriptors, OrderedMiddleware)
		AppendDescriptors(OrderedDescriptors, OrderedManagers)

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
