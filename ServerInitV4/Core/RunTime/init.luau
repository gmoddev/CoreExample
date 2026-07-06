local RunService = game:GetService("RunService")

local IsServer = RunService:IsServer()
local COSText = IsServer and "SERVER" or "CLIENT"

local RuntimeLoadOrder = {
	[1] = "Promise";
	[2] = "LoadFailure";
	[3] = "Logger";
	[4] = "Services";
	[5] = "SharedPublisher";
	[6] = "DependencyGraph";
	[7] = "ModuleCatalog";
	[8] = "ManagerExtensions";
	[9] = "Loader";
	[10] = "Lifecycle";
}

local Runtime = {
	Loaded = false,
	FailureReason = nil,
	COSText = COSText,
}

function Runtime:GetDependency(Owner, DependencyName)
	local Dependency = self[DependencyName]

	if Dependency == nil then
		return nil, ("Runtime module %s requires %s before it has loaded"):format(Owner, DependencyName)
	end

	return Dependency
end

local function LoadRuntimeModule(Step)
	local Module = script:FindFirstChild(Step)

	if not Module then
		return false, ("Runtime module %s is missing"):format(Step)
	end

	local Success, Result, FactoryReason = xpcall(function()
		local ModuleResult = require(Module)

		if type(ModuleResult) == "function" then
			local FactoryResult, Reason = ModuleResult(Runtime)

			if FactoryResult == nil then
				return nil, Reason or ("Runtime module %s factory returned nil"):format(Step)
			end

			return FactoryResult
		end

		return ModuleResult
	end, function(Error)
		return debug.traceback(tostring(Error), 2)
	end)

	if not Success then
		return false, ("Runtime module %s failed to load\n%s"):format(Step, tostring(Result))
	end

	if Result == nil then
		return false, tostring(FactoryReason or ("Runtime module %s returned nil"):format(Step))
	end

	return true, Result
end

for _, Step in ipairs(RuntimeLoadOrder) do
	local Success, Result = LoadRuntimeModule(Step)

	if not Success then
		Runtime.FailureReason = Result
		return Runtime
	end

	Runtime[Step] = Result
end

Runtime.Loaded = true

return Runtime
