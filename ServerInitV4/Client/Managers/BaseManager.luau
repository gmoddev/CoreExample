local Meta = {
	Name = "BaseManager",
}

function Meta.Factory(core)
	local Services = core.Services
	local RunService = Services.RunService

	return {
		IsClient = RunService:IsClient(),
	}
end

return Meta
