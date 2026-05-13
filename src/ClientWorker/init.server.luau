--!strict

local rootRef = assert(script:FindFirstChild("RootRef") :: ObjectValue?)
local rootModule = assert(rootRef.Value :: ModuleScript?)
local workerCallback = require(rootModule:FindFirstChild("Worker")) :: any

return workerCallback(script)
