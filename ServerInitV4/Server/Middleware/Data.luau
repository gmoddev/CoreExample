local Metadata = {
	Name = "Data",
	Requires = {
		"Helper:Example",
	},
}

function Metadata.Factory(core)
	local Helper = core:GetHelper("Example")

	return {
		Helper = Helper,
	}
end

return Metadata
