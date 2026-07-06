return function(Runtime)
	local DependencyGraph, DependencyGraphReason = Runtime:GetDependency("ManagerExtensions", "DependencyGraph")
	local LoadFailure, LoadFailureReason = Runtime:GetDependency("ManagerExtensions", "LoadFailure")

	if not DependencyGraph then
		return nil, DependencyGraphReason
	end

	if not LoadFailure then
		return nil, LoadFailureReason
	end

	local ManagerExtensions = {}

	local LocalKinds = {
		{
			Kind = "Helper",
			FolderName = "Helpers",
			RegistryName = "Helpers",
		},
		{
			Kind = "Middleware",
			FolderName = "Middleware",
			RegistryName = "Middleware",
		},
	}

	local function NormalizeRequires(Requires, CurrentKind, ModuleScript)
		if Requires == nil then
			return {}
		end

		if type(Requires) == "string" then
			Requires = { Requires }
		end

		if type(Requires) ~= "table" then
			return nil, LoadFailure.new({
				Stage = "ReadManagerExtensionMetadata",
				ModulePath = ModuleScript:GetFullName(),
				Reason = "Manager extension Requires must be a string or array of strings",
			})
		end

		local Normalized = {}

		for _, Requirement in ipairs(Requires) do
			if type(Requirement) ~= "string" then
				return nil, LoadFailure.new({
					Stage = "ReadManagerExtensionMetadata",
					ModulePath = ModuleScript:GetFullName(),
					Reason = "Manager extension Requires entries must be strings",
				})
			end

			if string.find(Requirement, ":", 1, true) then
				table.insert(Normalized, Requirement)
			else
				table.insert(Normalized, ("%s:%s"):format(CurrentKind, Requirement))
			end
		end

		return Normalized
	end

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

		for _, Descriptor in ipairs(Descriptors) do
			if Descriptor.Kind == "Helper" then
				table.insert(HelperDescriptors, Descriptor)
			else
				table.insert(MiddlewareDescriptors, Descriptor)
			end
		end

		return HelperDescriptors, MiddlewareDescriptors
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
						ModuleId = ("Manager:%s:%s"):format(Descriptor.ManagerName, Descriptor.Id),
						ModulePath = Descriptor.Module and Descriptor.Module:GetFullName() or nil,
						Reason = ("Manager extension %s modules cannot depend on %s because Core loads local extension phases in this order: Helpers, Middleware"):format(Descriptor.Kind, RequirementId),
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

	local function GetRegistryValues(Registry, RegistryName, ManagerName, Logger, ...)
		local Count = select("#", ...)

		if Count == 0 then
			return Registry
		end

		local Results = {}

		for Index = 1, Count do
			local Name = select(Index, ...)
			local Value = Registry[Name]

			if Value == nil then
				Logger:Warn(("%s extension %s '%s' has not been loaded"):format(ManagerName, RegistryName, tostring(Name)))
				return nil
			end

			Results[Index] = Value
		end

		return table.unpack(Results, 1, Count)
	end

	local function CreateContext(ManagerName, Logger)
		local Context = {
			Name = ManagerName,
			Helpers = {},
			Middleware = {},
			Logger = Logger,
		}

		function Context:GetHelper(...)
			return GetRegistryValues(self.Helpers, "Helper", self.Name, self.Logger, ...)
		end

		function Context:GetMiddleware(...)
			return GetRegistryValues(self.Middleware, "Middleware", self.Name, self.Logger, ...)
		end

		return Context
	end

	local function ReadModule(ModuleScript, KindInfo, ManagerName)
		local Success, FirstReturn = xpcall(function()
			return require(ModuleScript)
		end, function(Error)
			return {
				Reason = tostring(Error),
				Trace = debug.traceback(tostring(Error), 2),
			}
		end)

		if not Success then
			return false, LoadFailure.new({
				Stage = "RequireManagerExtension",
				ModuleId = ("Manager:%s:%s:%s"):format(ManagerName, KindInfo.Kind, ModuleScript.Name),
				ModulePath = ModuleScript:GetFullName(),
				Reason = FirstReturn.Reason,
				Trace = FirstReturn.Trace,
			})
		end

		return true, FirstReturn
	end

	local function BuildDescriptor(ModuleScript, KindInfo, ManagerName)
		local Success, FirstReturn = ReadModule(ModuleScript, KindInfo, ManagerName)

		if not Success then
			return nil, FirstReturn
		end

		local Metadata = {}
		local Factory = nil
		local DirectValue = nil

		if type(FirstReturn) == "function" then
			Factory = FirstReturn
		elseif type(FirstReturn) == "table" and (type(FirstReturn[1]) == "table" or FirstReturn[2] ~= nil) then
			if type(FirstReturn[1]) ~= "table" or type(FirstReturn[2]) ~= "function" then
				return nil, LoadFailure.new({
					Stage = "ReadManagerExtensionMetadata",
					ModulePath = ModuleScript:GetFullName(),
					Reason = "Tuple module format must be { MetadataTable, FactoryFunction }",
				})
			end

			Metadata = FirstReturn[1]
			Factory = FirstReturn[2]
		elseif type(FirstReturn) == "table" and type(FirstReturn.Factory) == "function" then
			Metadata = FirstReturn
			Factory = FirstReturn.Factory
		else
			Metadata = type(FirstReturn) == "table" and FirstReturn or {}
			DirectValue = FirstReturn
		end

		if Factory ~= nil and type(Factory) ~= "function" then
			return nil, LoadFailure.new({
				Stage = "ReadManagerExtensionMetadata",
				ModulePath = ModuleScript:GetFullName(),
				Reason = "Factory must be a function",
			})
		end

		local Name = Metadata.Name or ModuleScript.Name

		if type(Name) ~= "string" or Name == "" then
			return nil, LoadFailure.new({
				Stage = "ReadManagerExtensionMetadata",
				ModulePath = ModuleScript:GetFullName(),
				Reason = "Module has an invalid Name",
			})
		end

		local Requires, RequiresReason = NormalizeRequires(Metadata.Requires, KindInfo.Kind, ModuleScript)

		if not Requires then
			return nil, RequiresReason
		end

		return {
			Id = ("%s:%s"):format(KindInfo.Kind, Name),
			Kind = KindInfo.Kind,
			RegistryName = KindInfo.RegistryName,
			Name = Name,
			Requires = Requires,
			Module = ModuleScript,
			Metadata = Metadata,
			Factory = Factory,
			DirectValue = DirectValue,
			LoadedValue = nil,
			ManagerName = ManagerName,
			Scope = "ManagerExtension",
		}
	end

	local function AddDescriptor(Descriptors, SeenIds, Descriptor)
		if SeenIds[Descriptor.Id] then
			return false, LoadFailure.new({
				Stage = "DiscoverManagerExtensions",
				ModuleId = ("Manager:%s:%s"):format(Descriptor.ManagerName, Descriptor.Id),
				ModulePath = Descriptor.Module:GetFullName(),
				Reason = ("Duplicate manager extension id '%s' in Manager:%s"):format(Descriptor.Id, Descriptor.ManagerName),
			})
		end

		SeenIds[Descriptor.Id] = true
		table.insert(Descriptors, Descriptor)

		return true
	end

	local function DiscoverFolder(Folder, KindInfo, Descriptors, SeenIds, ManagerName)
		local Children = Folder:GetChildren()

		table.sort(Children, function(Left, Right)
			return Left.Name < Right.Name
		end)

		for _, Child in ipairs(Children) do
			if Child:IsA("ModuleScript") then
				local Descriptor, DescriptorReason = BuildDescriptor(Child, KindInfo, ManagerName)

				if not Descriptor then
					return false, DescriptorReason
				end

				local Added, AddReason = AddDescriptor(Descriptors, SeenIds, Descriptor)

				if not Added then
					return false, AddReason
				end
			end
		end

		return true
	end

	local function FindExtensionFolder(ManagerModule, FolderName)
		local Extension = ManagerModule:FindFirstChild("Extension")
		local NestedFolder = Extension and Extension:FindFirstChild(FolderName)
		local FlatFolder = ManagerModule:FindFirstChild(FolderName)

		if NestedFolder and FlatFolder then
			return nil, LoadFailure.new({
				Stage = "DiscoverManagerExtensions",
				ModuleId = ("Manager:%s"):format(ManagerModule.Name),
				ModulePath = ManagerModule:GetFullName(),
				Reason = ("%s has both Extension/%s and %s. Choose one manager extension layout."):format(
					ManagerModule:GetFullName(),
					FolderName,
					FolderName
				),
			})
		end

		return NestedFolder or FlatFolder
	end

	local function Discover(ManagerModule, ManagerName)
		local Descriptors = {}
		local SeenIds = {}

		for _, KindInfo in ipairs(LocalKinds) do
			local Folder, FolderReason = FindExtensionFolder(ManagerModule, KindInfo.FolderName)

			if FolderReason then
				return nil, FolderReason
			end

			if Folder then
				local Success, Reason = DiscoverFolder(Folder, KindInfo, Descriptors, SeenIds, ManagerName)

				if not Success then
					return nil, Reason
				end
			end
		end

		return Descriptors
	end

	function ManagerExtensions.Load(Core, Descriptor)
		local Context = CreateContext(Descriptor.Name, Core.Logger)

		if Descriptor.Metadata.NoCheckChildren == true then
			return Context
		end

		local Descriptors, DiscoverReason = Discover(Descriptor.Module, Descriptor.Name)

		if not Descriptors then
			return nil, DiscoverReason
		end

		if #Descriptors == 0 then
			return Context
		end

		local HelperDescriptors, MiddlewareDescriptors = SplitDescriptorsByPhase(Descriptors)
		local HelpersValid, HelpersValidReason = ValidatePhaseDependencies(HelperDescriptors, { "Helper" })

		if not HelpersValid then
			return nil, HelpersValidReason
		end

		local MiddlewareValid, MiddlewareValidReason =
			ValidatePhaseDependencies(MiddlewareDescriptors, { "Helper", "Middleware" })

		if not MiddlewareValid then
			return nil, MiddlewareValidReason
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

		local OrderedDescriptors = {}
		AppendDescriptors(OrderedDescriptors, OrderedHelpers)
		AppendDescriptors(OrderedDescriptors, OrderedMiddleware)

		for _, LocalDescriptor in ipairs(OrderedDescriptors) do
			Core.Logger:Stage("Loading", ("Manager:%s:%s"):format(Descriptor.Name, LocalDescriptor.Id))

			local LoadedValue

			if LocalDescriptor.Factory then
				local Success, Result = xpcall(function()
					return LocalDescriptor.Factory(Core, Context)
				end, function(Error)
					return debug.traceback(tostring(Error), 2)
				end)

				if not Success then
					return nil, LoadFailure.new({
						Stage = "RunManagerExtensionFactory",
						ModuleId = ("Manager:%s:%s"):format(Descriptor.Name, LocalDescriptor.Id),
						ModulePath = LocalDescriptor.Module:GetFullName(),
						Reason = tostring(Result),
					})
				end

				LoadedValue = Result
			else
				LoadedValue = LocalDescriptor.DirectValue
			end

			if LoadedValue == nil then
				LoadedValue = true
			end

			LocalDescriptor.LoadedValue = LoadedValue
			Context[LocalDescriptor.RegistryName][LocalDescriptor.Name] = LoadedValue

			Core.Logger:Stage("Loaded", ("Manager:%s:%s"):format(Descriptor.Name, LocalDescriptor.Id))
		end

		return Context
	end

	return ManagerExtensions
end
