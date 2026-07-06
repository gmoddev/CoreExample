local Meta = {
	Name = "BaseManager",
}

function Meta.Factory(core)
	local Services = core.Services
	local RunService = Services.RunService

	return {
		IsServer = RunService:IsServer(),
	}
end

return Meta
