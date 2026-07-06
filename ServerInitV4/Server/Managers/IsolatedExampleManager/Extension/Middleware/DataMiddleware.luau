local Meta = {
	Name = "DataMiddleware",
	Requires = {
		"Helper:MessageHelper",
	},
}

function Meta.Factory(_core, Manager)
	local MessageHelper = Manager:GetHelper("MessageHelper")

	return {
		MessageHelper = MessageHelper,

		Wrap = function(Message)
			return {
				Message = Message,
				Source = "IsolatedExampleManager",
			}
		end,
	}
end

return Meta
