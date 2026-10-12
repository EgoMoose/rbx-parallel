local function workerAction(n: number)
	task.wait(0.1)
	return n * n
end

return workerAction
