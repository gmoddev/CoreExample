return function(Runtime)
	local LoadFailure, DependencyReason = Runtime:GetDependency("DependencyGraph", "LoadFailure")

	if not LoadFailure then
		return nil, DependencyReason
	end

	local DependencyGraph = {}

	local Visiting = "Visiting"
	local Visited = "Visited"

	local function FindStackIndex(Stack, Id)
		for Index, StackId in ipairs(Stack) do
			if StackId == Id then
				return Index
			end
		end

		return nil
	end

	local function GetExpectedDependencyLocation(RequirementId, Descriptor)
		local Separator = string.find(RequirementId, ":", 1, true)
		local Kind = Separator and string.sub(RequirementId, 1, Separator - 1) or nil

		if Descriptor and Descriptor.Scope == "ManagerExtension" then
			if Kind == "Helper" then
				return "The owning manager's Extension.Helpers or Helpers folder"
			elseif Kind == "Middleware" then
				return "The owning manager's Extension.Middleware or Middleware folder"
			end
		end

		if Kind == "Helper" then
			return "ReplicatedStorage.Shared or Root.Helpers; helper dependencies must be discovered before middleware and managers"
		elseif Kind == "Middleware" then
			return "Root.Middleware"
		elseif Kind == "Manager" then
			return "Root.Managers"
		end

		return "A loaded Core module id in the form Kind:Name"
	end

	function DependencyGraph.Sort(Descriptors)
		local DescriptorById = {}

		for _, Descriptor in ipairs(Descriptors) do
			if DescriptorById[Descriptor.Id] then
				return nil, LoadFailure.new({
					Stage = "ResolveDependencies",
					ModuleId = Descriptor.Id,
					ModulePath = Descriptor.Module and Descriptor.Module:GetFullName() or nil,
					Reason = ("Duplicate module id '%s'"):format(Descriptor.Id),
				})
			end

			DescriptorById[Descriptor.Id] = Descriptor
		end

		local Ordered = {}
		local StateById = {}
		local Stack = {}

		local function Visit(Descriptor)
			local State = StateById[Descriptor.Id]

			if State == Visited then
				return true
			end

			if State == Visiting then
				local CycleStart = FindStackIndex(Stack, Descriptor.Id) or 1
				local Cycle = {}

				for Index = CycleStart, #Stack do
					table.insert(Cycle, Stack[Index])
				end

				table.insert(Cycle, Descriptor.Id)
				return false, LoadFailure.new({
					Stage = "ResolveDependencies",
					ModuleId = Descriptor.Id,
					ModulePath = Descriptor.Module and Descriptor.Module:GetFullName() or nil,
					Reason = ("Circular dependency detected: %s"):format(table.concat(Cycle, " -> ")),
				})
			end

			StateById[Descriptor.Id] = Visiting
			table.insert(Stack, Descriptor.Id)

			for _, RequirementId in ipairs(Descriptor.Requires) do
				local RequiredDescriptor = DescriptorById[RequirementId]

				if not RequiredDescriptor then
					return false, LoadFailure.new({
						Stage = "ResolveDependencies",
						ModuleId = Descriptor.Id,
						ModulePath = Descriptor.Module and Descriptor.Module:GetFullName() or nil,
						Reason = ("Missing dependency %s"):format(RequirementId),
						Dependency = RequirementId,
						Expected = GetExpectedDependencyLocation(RequirementId, Descriptor),
					})
				end

				local Success, Reason = Visit(RequiredDescriptor)

				if not Success then
					return false, Reason
				end
			end

			table.remove(Stack)
			StateById[Descriptor.Id] = Visited
			table.insert(Ordered, Descriptor)

			return true
		end

		for _, Descriptor in ipairs(Descriptors) do
			local Success, Reason = Visit(Descriptor)

			if not Success then
				return nil, Reason
			end
		end

		return Ordered
	end

	return DependencyGraph
end
