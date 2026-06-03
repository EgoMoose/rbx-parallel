local JestGlobals = require(game.ReplicatedStorage.DevPackages.JestGlobals)
local Parallel = require(game.ReplicatedStorage.Packages.Parallel)
local Worker = script.Parent.Worker

local it = JestGlobals.it
local expect = JestGlobals.expect

type WorkerAction = typeof(require(Worker))

local scheduler = Parallel.new(8, {
	script = Worker,
	typecast = (nil :: any) :: WorkerAction,
})

scheduler:waitForReady()

local results
it("should cancel in-flight work", function()
	for i = 1, scheduler:getActorCount() * 2 do
		scheduler:schedule(i)
	end

	task.defer(function()
		scheduler:cancelWork()
	end)

	local cancelled
	results, cancelled = scheduler:workAsync()

	expect(cancelled).toEqual(true)
	expect(scheduler:isWorking()).toEqual(false)
end)

it("should error when unpacking cancelled results", function()
	local cancelledCount = 0
	for _, unpackResult in results do
		local success, err: string? = pcall(function()
			unpackResult()
		end)

		if not success then
			expect(not not (err and err:match("Work was cancelled"))).toEqual(true)
			cancelledCount = cancelledCount + 1
		end
	end

	expect(cancelledCount > 0).toEqual(true)
end)

it("cancelling should do nothing not working", function()
	scheduler:cancelWork()
end)

it("should be reusable after cancelling", function()
	scheduler:waitForReady()
	expect(scheduler:getActorCount()).toEqual(8)

	local nCount = scheduler:getActorCount()

	local serialSum = 0
	for i = 1, nCount do
		serialSum = serialSum + i * i
		scheduler:schedule(i)
	end

	local newResults, cancelled = scheduler:workAsync()
	expect(cancelled).toEqual(false)

	local sum = 0
	for _, unpackResult in newResults do
		sum = sum + unpackResult()
	end

	expect(sum).toEqual(serialSum)
end)
