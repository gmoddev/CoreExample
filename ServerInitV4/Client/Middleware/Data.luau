return {
	Name = "Data",
	Requires = {
		"Helper:Example",
	},
	Factory = function(core)
		local Helper = core:GetHelper("Example")

		return {
			Helper = Helper,
		}
	end,
}
