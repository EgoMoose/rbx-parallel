--!strict

return function(script: LuaSourceContainer)
	local actor = assert(script:GetActor(), "No actor found.")

	local moduleRef = assert(actor:FindFirstAncestorWhichIsA("ObjectValue"), "No module found.")
	local module = assert(moduleRef.Value, "No value in the ObjectValue.")
	assert(module:IsA("ModuleScript"), "ModuleRef Value is not a ModuleScript.")

	local binding = assert(moduleRef:FindFirstChild("Binding"), "Not binding instance found.")
	assert(binding:IsA("BindableEvent"), "Not a BindableEvent.")

	local workerAction = require(module) :: any
	actor:BindToMessageParallel("Work", function(k, ...)
		local packedResults
		local packedArgs = table.pack(...)
		local success, err: string? = pcall(function()
			packedResults = table.pack(workerAction(table.unpack(packedArgs, 1, packedArgs.n)))
		end)

		if success then
			binding:Fire(k, true, table.unpack(packedResults, 1, packedResults.n))
		else
			binding:Fire(k, false, err or "UNKNOWN ERROR")
		end
	end)

	actor:SetAttribute("IsReady", true)
end
