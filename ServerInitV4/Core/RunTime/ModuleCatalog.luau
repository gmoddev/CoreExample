return function(Runtime)
	local LoadFailure, DependencyReason = Runtime:GetDependency("ModuleCatalog", "LoadFailure")

	if not LoadFailure then
		return nil, DependencyReason
	end

	local ModuleCatalog = {}

	local ModuleKinds = {
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
		{
			Kind = "Manager",
			FolderName = "Managers",
			RegistryName = "Managers",
		},
	}

	local SharedKindInfo = {
		Kind = "Helper",
		FolderName = "Shared",
		RegistryName = "Helpers",
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
				Stage = "ReadMetadata",
				ModulePath = ModuleScript:GetFullName(),
				Reason = "Requires must be a string or array of strings",
			})
		end

		local Normalized = {}

		for _, Requirement in ipairs(Requires) do
			if type(Requirement) ~= "string" then
				return nil, LoadFailure.new({
					Stage = "ReadMetadata",
					ModulePath = ModuleScript:GetFullName(),
					Reason = "Requires entries must be strings",
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

	local function ReadModule(ModuleScript, KindInfo)
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
				Stage = "RequireModule",
				ModuleId = ("%s:%s"):format(KindInfo.Kind, ModuleScript.Name),
				ModulePath = ModuleScript:GetFullName(),
				Reason = FirstReturn.Reason,
				Trace = FirstReturn.Trace,
			})
		end

		return true, FirstReturn
	end

	local function BuildDescriptor(ModuleScript, KindInfo)
		local Success, FirstReturn = ReadModule(ModuleScript, KindInfo)

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
					Stage = "ReadMetadata",
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
				Stage = "ReadMetadata",
				ModulePath = ModuleScript:GetFullName(),
				Reason = "Factory must be a function",
			})
		end

		local Name = Metadata.Name or ModuleScript.Name

		if type(Name) ~= "string" or Name == "" then
			return nil, LoadFailure.new({
				Stage = "ReadMetadata",
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
			FolderName = KindInfo.FolderName,
			RegistryName = KindInfo.RegistryName,
			Name = Name,
			Requires = Requires,
			Module = ModuleScript,
			Metadata = Metadata,
			Factory = Factory,
			DirectValue = DirectValue,
			LoadedValue = nil,
		}
	end

	local function GetDevelopmentOverride(Folder, ModuleScript)
		local Development = Folder:FindFirstChild("Development")

		if not Development then
			return ModuleScript
		end

		local Override = Development:FindFirstChild(ModuleScript.Name)

		if Override and Override:IsA("ModuleScript") then
			return Override
		end

		return ModuleScript
	end

	local function AddDescriptor(Descriptors, SeenIds, Descriptor, Root)
		if SeenIds[Descriptor.Id] then
			return false, LoadFailure.new({
				Stage = "DiscoverModules",
				ModuleId = Descriptor.Id,
				ModulePath = Descriptor.Module:GetFullName(),
				Reason = ("Duplicate module id '%s' while loading %s"):format(Descriptor.Id, Root:GetFullName()),
			})
		end

		SeenIds[Descriptor.Id] = true
		table.insert(Descriptors, Descriptor)

		return true
	end

	local function DiscoverFolder(Folder, KindInfo, Descriptors, SeenIds)
		local Children = Folder:GetChildren()

		table.sort(Children, function(Left, Right)
			return Left.Name < Right.Name
		end)

		for _, Child in ipairs(Children) do
			if Child:IsA("ModuleScript") and Child.Name ~= "Development" then
				local ModuleScript = GetDevelopmentOverride(Folder, Child)
				local Descriptor, DescriptorReason = BuildDescriptor(ModuleScript, KindInfo)

				if not Descriptor then
					return false, DescriptorReason
				end

				local Added, AddReason = AddDescriptor(Descriptors, SeenIds, Descriptor, Folder)

				if not Added then
					return false, AddReason
				end
			end
		end

		return true
	end

	function ModuleCatalog.Discover(Root, Logger, SharedRoots)
		local Descriptors = {}
		local SeenIds = {}

		for _, SharedRoot in ipairs(SharedRoots or {}) do
			if SharedRoot then
				local Success, Reason = DiscoverFolder(SharedRoot, SharedKindInfo, Descriptors, SeenIds)

				if not Success then
					return nil, Reason
				end
			end
		end

		for _, KindInfo in ipairs(ModuleKinds) do
			local Folder = Root:FindFirstChild(KindInfo.FolderName)

			if Folder then
				local Success, Reason = DiscoverFolder(Folder, KindInfo, Descriptors, SeenIds)

				if not Success then
					return nil, Reason
				end
			else
				Logger:Stage(("No %s folder found under %s"):format(KindInfo.FolderName, Root:GetFullName()))
			end
		end

		return Descriptors
	end

	return ModuleCatalog
end
