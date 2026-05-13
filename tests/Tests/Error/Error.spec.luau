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

scheduler:waitForReady()

local results
it("should successfully run", function()
	for i = 1, scheduler:getActorCount() do
		scheduler:schedule()
	end
	results = scheduler:workAsync()
end)

it("should error when unpacking the results", function()
	for _, unpackResult in results do
		local success, err: string? = pcall(function()
			unpackResult()
		end)

		expect(success).toEqual(false)
		expect(not not (err and err:match("Some error occurred!$"))).toEqual(true)
	end
end)
