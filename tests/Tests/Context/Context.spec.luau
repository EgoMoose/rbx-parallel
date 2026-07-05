local JestGlobals = require(game.ReplicatedStorage.DevPackages.JestGlobals)
local Parallel = require(game.ReplicatedStorage.Packages.Parallel)
local Worker = script.Parent.Worker
local WriteWorker = script.Parent.WriteWorker

local it = JestGlobals.it
local expect = JestGlobals.expect

type WorkerAction = typeof(require(Worker))
type WriteWorkerAction = typeof(require(WriteWorker))

local scheduler = Parallel.new(32, {
	script = Worker,
	typecast = (nil :: any) :: WorkerAction,
})

local writeScheduler = Parallel.new(8, {
	script = WriteWorker,
	typecast = (nil :: any) :: WriteWorkerAction,
})

scheduler:waitForReady()
writeScheduler:waitForReady()

local nCount = scheduler:getActorCount() * 2

local expectedSum = 0
for i = 1, nCount do
	expectedSum = expectedSum + i * i
end

local function scheduleAll()
	for i = 1, nCount do
		scheduler:schedule(i)
	end
end

local function sumResults(results)
	local sum = 0
	for _, unpackResult in results do
		sum = sum + unpackResult()
	end
	return sum
end

it("should compute correctly in a parallel context", function()
	scheduleAll()
	local results = scheduler:workAsync("parallel")
	expect(sumResults(results)).toEqual(expectedSum)
end)

it("should compute correctly in a serial context", function()
	scheduleAll()
	local results = scheduler:workAsync("serial")
	expect(sumResults(results)).toEqual(expectedSum)
end)

it("should default to a parallel context", function()
	scheduleAll()
	local results = scheduler:workAsync()
	expect(sumResults(results)).toEqual(expectedSum)
end)

it("should permit DataModel writes in a serial context", function()
	for _ = 1, writeScheduler:getActorCount() do
		writeScheduler:schedule()
	end

	local results = writeScheduler:workAsync("serial")
	for _, unpackResult in results do
		expect(unpackResult()).toEqual(true)
	end
end)

it("should reject DataModel writes in a parallel context", function()
	for _ = 1, writeScheduler:getActorCount() do
		writeScheduler:schedule()
	end

	local results = writeScheduler:workAsync("parallel")

	local erroredCount = 0
	for _, unpackResult in results do
		local success = pcall(unpackResult)
		if not success then
			erroredCount = erroredCount + 1
		end
	end

	expect(erroredCount > 0).toEqual(true)
end)
