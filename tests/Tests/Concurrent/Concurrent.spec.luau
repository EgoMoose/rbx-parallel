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

local function sumOfSquares(from: number, to: number)
	local sum = 0
	for i = from, to do
		sum = sum + i * i
	end
	return sum
end

local function run(from: number, to: number)
	scheduler:waitForReady()

	for i = from, to do
		scheduler:schedule(i)
	end

	local sum = 0
	local results = scheduler:workAsync()
	for _, unpackResult in results do
		sum = sum + unpackResult()
	end

	return sum
end

it("should let multiple waiters share a busy scheduler", function()
	scheduler:waitForReady()

	local nCallers = 3
	local sums = {}
	local errs = {}
	local nDone = 0

	for c = 1, nCallers do
		task.spawn(function()
			local success, result = pcall(run, c * 100 + 1, c * 100 + 16)
			if success then
				sums[c] = result
			else
				errs[c] = result
			end
			nDone = nDone + 1
		end)
	end

	while nDone < nCallers do
		task.wait()
	end

	for c = 1, nCallers do
		expect(errs[c]).toBeNil()
		expect(sums[c]).toEqual(sumOfSquares(c * 100 + 1, c * 100 + 16))
	end
end)
