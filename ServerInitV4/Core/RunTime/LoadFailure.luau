local LoadFailure = {}

local function AddLine(Lines, Label, Value)
	if Value == nil or Value == "" then
		return
	end

	table.insert(Lines, ("%s: %s"):format(Label, tostring(Value)))
end

local function GetRequireHint(Reason)
	if type(Reason) ~= "string" then
		return nil
	end

	if string.find(Reason, "did not return exactly one value", 1, true) then
		return "Roblox ModuleScripts must return exactly one value. Use a single table with Factory = function(core) ... end."
	end

	return nil
end

function LoadFailure.new(Data)
	Data = Data or {}

	return {
		IsLoadFailure = true,
		Stage = Data.Stage,
		ModuleId = Data.ModuleId,
		ModulePath = Data.ModulePath,
		Reason = Data.Reason,
		Dependency = Data.Dependency,
		Expected = Data.Expected,
		Hint = Data.Hint or GetRequireHint(Data.Reason),
		Trace = Data.Trace,
	}
end

function LoadFailure.Is(Value)
	return type(Value) == "table" and Value.IsLoadFailure == true
end

function LoadFailure.ToString(Failure, IncludeTrace)
	if not LoadFailure.Is(Failure) then
		return tostring(Failure)
	end

	local Lines = {
		("Failed to load %s"):format(Failure.ModuleId or "Core module"),
	}

	AddLine(Lines, "Path", Failure.ModulePath)
	AddLine(Lines, "Stage", Failure.Stage)
	AddLine(Lines, "Dependency", Failure.Dependency)
	AddLine(Lines, "Reason", Failure.Reason)
	AddLine(Lines, "Expected", Failure.Expected)
	AddLine(Lines, "Hint", Failure.Hint)

	if IncludeTrace then
		AddLine(Lines, "Trace", Failure.Trace)
	end

	return table.concat(Lines, "\n")
end

function LoadFailure.FromReason(Reason, Data)
	if LoadFailure.Is(Reason) then
		return Reason
	end

	Data = Data or {}
	Data.Reason = Data.Reason or tostring(Reason)

	return LoadFailure.new(Data)
end

return LoadFailure
