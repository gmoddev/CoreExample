return {
	Name = "ExampleTwo",
	Factory = function(core)
		local Services = core.Services
		local ReplicatedStorage = Services.ReplicatedStorage

		return {
			ReplicatedStorage = ReplicatedStorage,
		}
	end,
}
