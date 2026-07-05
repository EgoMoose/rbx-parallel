local function workerAction()
	local marker = Instance.new("BoolValue")
	marker.Value = true
	marker.Parent = script
	return marker.Value
end

return workerAction
