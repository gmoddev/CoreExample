return function(Runtime)
	local LoadFailure, DependencyReason = Runtime:GetDependency("SharedPublisher", "LoadFailure")

	if not LoadFailure then
		return nil, DependencyReason
	end

	local SharedPublisher = {}

	local PublishedAttribute = "CorePublishedServerShared"
	local SharedLoadedAttribute = "ServerSharedLoaded"
	local SharedFailureAttribute = "ServerSharedFailureReason"
	local ServerLoadedAttribute = "ServerLoaded"

	local function GetOrCreateSharedFolder(ReplicatedStorage)
		local Shared = ReplicatedStorage:FindFirstChild("Shared")

		if Shared then
			return Shared
		end

		Shared = Instance.new("Folder")
		Shared.Name = "Shared"
		Shared.Parent = ReplicatedStorage

		return Shared
	end

	local function PublishChild(Shared, Child)
		local Existing = Shared:FindFirstChild(Child.Name)

		if Existing then
			if Existing:GetAttribute(PublishedAttribute) then
				Existing:Destroy()
			else
				return false, LoadFailure.new({
					Stage = "PublishServerShared",
					ModuleId = ("Helper:%s"):format(Child.Name),
					ModulePath = Child:GetFullName(),
					Reason = ("Cannot publish Server.Shared.%s because ReplicatedStorage.Shared already has a module with that name"):format(Child.Name),
					Expected = "ReplicatedStorage.Shared must not already contain a non-Core-published module with this name",
				})
			end
		end

		local Clone = Child:Clone()
		Clone:SetAttribute(PublishedAttribute, true)
		Clone.Parent = Shared

		return true
	end

	local function GetSharedFailure(CoreScript)
		local FailureReason = CoreScript:GetAttribute(SharedFailureAttribute)

		if FailureReason == nil then
			return nil
		end

		return LoadFailure.new({
			Stage = "WaitForServerShared",
			ModulePath = CoreScript:GetFullName(),
			Reason = tostring(FailureReason),
		})
	end

	local function MarkSharedFailure(CoreScript, Failure)
		CoreScript:SetAttribute(SharedFailureAttribute, tostring(Failure))
		CoreScript:SetAttribute(SharedLoadedAttribute, true)
	end

	function SharedPublisher.PublishServerShared(CoreScript, Root, Services, Logger)
		local RunService = Services.RunService

		if not RunService:IsServer() then
			return true
		end

		CoreScript:SetAttribute(SharedLoadedAttribute, false)
		CoreScript:SetAttribute(SharedFailureAttribute, nil)
		CoreScript:SetAttribute(ServerLoadedAttribute, false)

		local ServerShared = Root:FindFirstChild("Shared")

		if not ServerShared then
			CoreScript:SetAttribute(SharedLoadedAttribute, true)
			Logger:Stage("No Server.Shared folder found")
			return true
		end

		local Shared = GetOrCreateSharedFolder(Services.ReplicatedStorage)

		for _, Child in ipairs(ServerShared:GetChildren()) do
			if Child:IsA("ModuleScript") then
				local Success, Reason = PublishChild(Shared, Child)

				if not Success then
					MarkSharedFailure(CoreScript, Reason)
					return false, Reason
				end
			end
		end

		CoreScript:SetAttribute(SharedLoadedAttribute, true)
		Logger:Stage("Published Server.Shared helpers to ReplicatedStorage.Shared")

		return true
	end

	function SharedPublisher.WaitForServerShared(CoreScript, Services, Logger)
		local RunService = Services.RunService

		if RunService:IsServer() then
			return true
		end

		local Failure = GetSharedFailure(CoreScript)

		if Failure then
			return false, Failure
		end

		if CoreScript:GetAttribute(SharedLoadedAttribute) == true then
			return true
		end

		Logger:Stage("Waiting for server shared helpers")

		while CoreScript:GetAttribute(SharedLoadedAttribute) ~= true do
			CoreScript:GetAttributeChangedSignal(SharedLoadedAttribute):Wait()
		end

		Failure = GetSharedFailure(CoreScript)

		if Failure then
			return false, Failure
		end

		return true
	end

	function SharedPublisher.MarkServerLoaded(CoreScript, Services)
		local RunService = Services.RunService

		if RunService:IsServer() then
			CoreScript:SetAttribute(ServerLoadedAttribute, true)
		end
	end

	return SharedPublisher
end
