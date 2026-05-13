local JestGlobals = require(game.ReplicatedStorage.DevPackages.JestGlobals)
local Parallel = require(game.ReplicatedStorage.Packages.Parallel)
local Worker = script.Parent.Worker

local it = JestGlobals.it
local expect = JestGlobals.expect

type WorkerAction = typeof(require(Worker))

local scheduler = Parallel.new(32, {
	script = Worker,
	typecast = (nil :: any) :: WorkerAction,
})

local nCount = scheduler:getActorCount() * 2

local serialSum = 0
for i = 1, nCount do
	serialSum = serialSum + i * i
end

scheduler:waitForReady()

local results
it("should successfully run", function()
	for i = 1, nCount do
		scheduler:schedule(i)
	end
	results = scheduler:workAsync()
end)

local sum = 0
it("should unpack the results", function()
	for _, unpackResult in results do
		sum = sum + unpackResult()
	end

	expect(sum).toEqual(serialSum)
end)
