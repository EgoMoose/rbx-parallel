local function workerAction(n: number)
	task.wait(0.2)
	return n * n
end

return workerAction
