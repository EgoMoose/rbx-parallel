<!-- Links -->

[project/releases]: https://github.com/EgoMoose/rbx-parallel/releases
[project/wally]: https://wally.run/package/egomoose/parallel

<!-- Badges -->

[badges/github]: https://raw.githubusercontent.com/gist/cxmeel/0dbc95191f239b631c3874f4ccf114e2/raw/github.svg
[badges/wally]: https://raw.githubusercontent.com/gist/cxmeel/0dbc95191f239b631c3874f4ccf114e2/raw/wally.svg

# rbx-parallel

[![Get it on Github][badges/github]][project/releases] [![Get it on Wally][badges/wally]][project/wally]

An abstraction layer for actor-based parallel execution on Roblox.

## How it works?

This project aims to give developers a quick, typed, relatively easy to way to structure and use parallel luau in their Roblox projects.

Every task you write will require creating a worker file. This loaded into the scheduler and defines how each chunk of work is processed by an actor.

For example:

```luau
-- worker
local function workerAction(n: number)
	return n * n
end

return workerAction
```

```luau
-- scheduler
type WorkerAction = typeof(require(Worker))

local scheduler = Parallel.new(32, { -- 32 workers
	script = Worker,
	typecast = (nil :: any) :: WorkerAction,
})

-- wait for the actors to come online
scheduler:waitForReady()

-- now we can schedule some work for the actors to complete.
-- since we're assigning more work than actors each actor will work twice
for i = 1, scheduler:getActorCount() * 2 do
	scheduler:schedule(i)
end

-- then actually tell the actors to do the work
local results = scheduler:work()

-- each actor's returned values are packed in a function to support the type-system
local sum = 0
for _, unpackResult in results do
	local sqNum = unpackResult()
	sum = sum + sqNum
end

print(sum) -- 89440
```