local Meta = {
	Name = "MessageHelper",
}

function Meta.Factory()
	return {
		Format = function(Name)
			return ("Hello %s from an isolated manager helper."):format(Name)
		end,
	}
end

return Meta
