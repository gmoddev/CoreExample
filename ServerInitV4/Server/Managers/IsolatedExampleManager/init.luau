local Meta = {
	Name = "IsolatedExampleManager",
	Requires = {
		"Manager:BaseManager",
	},
}

return {
	Meta,
	function(core, Manager)
		local BaseManager = core:GetManager("BaseManager")
		local MessageHelper = Manager:GetHelper("MessageHelper")
		local DataMiddleware = Manager:GetMiddleware("DataMiddleware")

		return {
			BaseManager = BaseManager,
			MessageHelper = MessageHelper,
			DataMiddleware = DataMiddleware,

			BuildMessage = function(Name)
				local Message = MessageHelper.Format(Name)

				return DataMiddleware.Wrap(Message)
			end,
		}
	end,
}
