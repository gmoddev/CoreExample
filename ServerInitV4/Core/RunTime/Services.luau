local Services = {}

function Services.new(Promise, Logger)
	local Cache = {}

	return setmetatable({
		Promise = Promise,
	}, {
		__index = function(_, Key)
			if Cache[Key] then
				return Cache[Key]
			end

			local Success, Service = pcall(game.GetService, game, Key)

			if Success and Service then
				Cache[Key] = Service
				return Service
			end

			Logger:Warn(("Invalid service requested: %s"):format(tostring(Key)))
			return nil
		end,

		__newindex = function()
			Logger:Warn("Services table is read only")
		end,
	})
end

return Services
