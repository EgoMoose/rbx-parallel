--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local run = require("@utils/run")

local STAGING_DIR = "build/staging"
local STAGING_PACKAGES = `{STAGING_DIR}/Packages`
local WRAPPER_FILE = `{STAGING_PACKAGES}/TARGET_PACKAGE.luau`

local wallyToml = serde.decode("toml", fs.readFile("wally.toml"))
local owner, packageShortName = wallyToml.package.name:match("^(.-)/(.+)$")
assert(owner and packageShortName, "wally name must be `owner/name`")
local indexName = `{owner}_{packageShortName}@{wallyToml.package.version}`

if fs.isDir("build") then
	fs.removeDir("build")
end

fs.writeDir("build")
fs.writeDir(STAGING_DIR)
fs.writeDir(STAGING_PACKAGES)

-- Wally-shaped wrapper for wally-package-types to discover and patch
fs.writeFile(WRAPPER_FILE, `return require(script.Parent._Index["{indexName}"]["{packageShortName}"])\n`)

-- Paths in the staging project resolve relative to its own location (build/staging/)
local stagingProject = {
	name = "build-standalone-staging",
	tree = {
		["$className"] = "Folder",
		Packages = {
			["$className"] = "Folder",
			["TARGET_PACKAGE"] = { ["$path"] = "Packages/TARGET_PACKAGE.luau" },
			_Index = {
				["$className"] = "Folder",
				[indexName] = {
					["$className"] = "Folder",
					[packageShortName] = { ["$path"] = "../../src" },
				},
			},
		},
	},
}

fs.writeFile(`{STAGING_DIR}/staging.project.json`, serde.encode("json", stagingProject, true))

-- wally-package-types resolves sourcemap filePaths relative to its cwd, so run both from STAGING_DIR
run("rojo", { "sourcemap", "staging.project.json", "-o", "sourcemap.json" }, { cwd = STAGING_DIR })
run("wally-package-types", { "--sourcemap", "sourcemap.json", "Packages" }, { cwd = STAGING_DIR })

-- Patched wrapper points at the staging _Index; rewrite the require for the standalone tree
local patched = fs.readFile(WRAPPER_FILE)
local adjusted, replacements =
	patched:gsub('require%(script%.Parent%._Index%[".-"%]%[".-"%]%)', "require(script.Packages.TARGET_PACKAGE)")
assert(replacements == 1, "expected wally-package-types to leave exactly one require to rewrite")
fs.writeFile("build/standalone.luau", adjusted)

local defaultProj = serde.decode("json", fs.readFile("default.project.json"))

fs.writeFile(
	"standalone.project.json",
	serde.encode("json", {
		["name"] = defaultProj.name,
		["tree"] = {
			["$path"] = "build/standalone.luau",
			["Packages"] = {
				["$path"] = "Packages",
				["TARGET_PACKAGE"] = {
					["$path"] = "default.project.json",
				},
			},
		},
	})
)

run("rojo", { "build", "standalone.project.json", "--output", process.args[1] })

fs.removeFile("standalone.project.json")
fs.removeDir("build")
