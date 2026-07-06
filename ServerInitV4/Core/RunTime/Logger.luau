return function(Runtime)
	local LoadFailure, DependencyReason = Runtime:GetDependency("Logger", "LoadFailure")

	if not LoadFailure then
		return nil, DependencyReason
	end

	local Logger = {}
	Logger.__index = Logger

	local function ReadLogFlag(CoreScript, Config)
		if Config and Config.DoLogStage ~= nil then
			return Config.DoLogStage == true
		end

		local Flag = CoreScript:FindFirstChild("DoPrintSuccess")

		if Flag and Flag:IsA("BoolValue") then
			return Flag.Value == true
		end

		return false
	end

	function Logger.new(CoreScript, Config, COSText)
		local self = setmetatable({
			DoLogStage = ReadLogFlag(CoreScript, Config),
			COSText = COSText or "UNKNOWN",
		}, Logger)

		return self
	end

	function Logger:Info(...)
		warn(("[%s]"):format(self.COSText), ...)
	end

	function Logger:Warn(...)
		warn(("[%s]"):format(self.COSText), ...)
	end

	function Logger:Error(...)
		warn(("[%s]"):format(self.COSText), ...)
	end

	function Logger:Failure(Failure)
		if LoadFailure.Is(Failure) then
			self:Warn(LoadFailure.ToString(Failure))
		else
			self:Warn(tostring(Failure))
		end
	end

	function Logger:Stage(...)
		if not self.DoLogStage then
			return
		end

		warn(("[%s]"):format(self.COSText), ...)
	end

	return Logger
end
