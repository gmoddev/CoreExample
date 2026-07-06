local Meta = {
	Name = "ExampleManager",
	Requires = {
		"Helper:Example",
		"Helper:ExampleTwo",
		"Helper:SharedExample",
		"Middleware:Data",
		"Manager:BaseManager",
	},
}

function Meta.Factory(core)
	local Services = core.Services

	local ReplicatedStorage = Services.ReplicatedStorage

	local Middleware = core:GetMiddleware("Data")
	local BaseManager = core:GetManager("BaseManager")
	local HelperOne, HelperTwo, SharedExample = core:GetHelper("Example", "ExampleTwo", "SharedExample")

	return {
		BaseManager = BaseManager,
		HelperOne = HelperOne,
		HelperTwo = HelperTwo,
		SharedExample = SharedExample,
		Middleware = Middleware,
		ReplicatedStorage = ReplicatedStorage,
	}
end

return Meta
