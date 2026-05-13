local RunService = game:GetService("RunService") :: RunService

local Bootstrap = {}

function Bootstrap.createRefs()
	local rootRefTemplate = Instance.new("ObjectValue")
	rootRefTemplate.Name = "RootRef"
	rootRefTemplate.Value = script.Parent

	rootRefTemplate:Clone().Parent = script.Parent.ClientWorker
	rootRefTemplate:Clone().Parent = script.Parent.PluginWorker
	rootRefTemplate:Clone().Parent = script.Parent.ServerWorker

	rootRefTemplate:Destroy()

	local moduleRefFolder = Instance.new("Folder")
	moduleRefFolder.Name = "ModuleRefs"
	moduleRefFolder.Parent = script.Parent

	return moduleRefFolder
end

function Bootstrap.isEditMode()
	local isEdit = false
	local success = pcall(function(...)
		isEdit = RunService:IsEdit()
	end)
	return success and isEdit
end

return Bootstrap
