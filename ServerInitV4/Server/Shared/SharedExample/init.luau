
local Meta = {
	Name = "SharedExample",
}

function Meta.Factory(core)
	local Services = core.Services
	local RunService = Services.RunService

	local FormatMessage = require(script.FormatMessage)

	return {
		IsServer = RunService:IsServer(),

		GetMessage = function(Name)
			return FormatMessage(Name)
		end,
	}
end

return Meta
