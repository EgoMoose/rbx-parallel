--!strict
--!nolint DeprecatedApi

local RunService = game:GetService("RunService") :: RunService

local Future = require(script.Parent.Future)
local Trove = require(script.Parent.Trove)

local Bootstrap = require(script.Bootstrap)

local MODULE_REFS_FOLDER = Bootstrap.createRefs()
local IS_EDIT_MODE = Bootstrap.isEditMode()

-- Class

local ParallelStatic = {}

local ParallelClass = {}
ParallelClass.__index = ParallelClass
ParallelClass.ClassName = "Parallel"

export type Required<T..., U...> = {
	script: ModuleScript,
	typecast: (T...) -> U...,
}

export type Parallel<T..., U...> = typeof(setmetatable(
	{} :: {
		trove: Trove.Trove,

		ticket: number,
		isWorking: boolean,
		required: Required<T..., U...>,

		binding: BindableEvent,
		isReadyFuture: Future.Future<()>,

		actorEntries: {
			{
				actor: Actor,
				scheduled: { () -> T... },
			}
		},
	},
	ParallelClass
))

function ParallelStatic.new<T..., U...>(n: number, required: Required<T..., U...>)
	local self = setmetatable({}, ParallelClass) :: Parallel<T..., U...>

	self.trove = Trove.new()

	self.ticket = 0
	self.actorEntries = {}
	self.required = required

	self.isWorking = false
	self.isReadyFuture = Future.new()

	local template = script.ClientWorker
	local parent: Instance = MODULE_REFS_FOLDER
	if script:FindFirstAncestorWhichIsA("Plugin") then
		template = script.PluginWorker
	elseif IS_EDIT_MODE then
		local tmpPlugin = PluginManager():CreatePlugin()
		self.trove:Add(tmpPlugin)
		template = script.PluginWorker
		parent = tmpPlugin
	elseif RunService:IsServer() then
		template = script.ServerWorker
	end

	local moduleRef = Instance.new("ObjectValue")
	moduleRef.Name = `Parallel_{required.script.Name}`
	moduleRef.Value = required.script
	moduleRef.Archivable = false
	moduleRef.Parent = parent
	self.trove:Add(moduleRef)

	self.binding = Instance.new("BindableEvent")
	self.binding.Name = "Binding"
	self.binding.Parent = moduleRef
	self.trove:Add(self.binding)

	for i = 1, n do
		local actor = Instance.new("Actor")
		actor.Name = tostring(i)
		actor.Parent = moduleRef

		local worker = template:Clone()
		worker.Enabled = true
		worker.Parent = actor

		self.actorEntries[i] = {
			actor = actor,
			scheduled = {},
		}
	end

	task.spawn(function()
		for _, actorEntry in self.actorEntries do
			while not actorEntry.actor:GetAttribute("IsReady") do
				actorEntry.actor:GetAttributeChangedSignal("IsReady"):Wait()
			end
		end

		self.isReadyFuture:complete()
	end)

	return self
end

-- Public

function ParallelClass.waitForReady<T..., U...>(self: Parallel<T..., U...>)
	self.isReadyFuture:expect()
end

function ParallelClass.getActorCount<T..., U...>(self: Parallel<T..., U...>)
	return #self.actorEntries
end

function ParallelClass.schedule<T..., U...>(self: Parallel<T..., U...>, ...: T...)
	assert(self.isReadyFuture:isCompleted(), "Not ready!")

	self.ticket = self.ticket + 1
	local myTicket = self.ticket

	local actorIndex = ((myTicket - 1) % #self.actorEntries) + 1
	local actorEntry = self.actorEntries[actorIndex]

	table.insert(actorEntry.scheduled, Future.packAsCallback(...))
end

function ParallelClass.clear<T..., U...>(self: Parallel<T..., U...>)
	assert(self.isReadyFuture:isCompleted(), "Not ready!")

	self.ticket = 0
	for _, actorEntry in self.actorEntries do
		table.clear(actorEntry.scheduled)
	end
end

function ParallelClass.workAsync<T..., U...>(self: Parallel<T..., U...>)
	assert(self.isReadyFuture:isCompleted(), "Not ready!")
	assert(not self.isWorking, "Already working!")
	self.isWorking = true

	local futures = {}
	local connection = self.binding.Event:Connect(function(k: number, success: boolean, ...)
		if success then
			futures[k]:complete(Future.packAsCallback(...))
		else
			local err: string = ...
			futures[k]:complete(function()
				error("\n" .. err, 2)
			end)
		end
	end)

	for i, actorEntry in self.actorEntries do
		for j, unpackArgs in actorEntry.scheduled do
			local k = ((j - 1) * #self.actorEntries) + i
			futures[k] = Future.new()
			actorEntry.actor:SendMessage("Work", k, unpackArgs())
		end
	end

	self:clear()

	local results = {}
	for i, future in futures do
		local castedFuture = (future :: any) :: Future.Future<() -> U...>
		results[i] = castedFuture:expect()
	end

	connection:Disconnect()

	self.isWorking = false
	return results
end

function ParallelClass.Destroy<T..., U...>(self: Parallel<T..., U...>)
	self.trove:Destroy()
	self.actorEntries = {}
end

--

return ParallelStatic
