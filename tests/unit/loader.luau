-- Loads game modules outside Roblox (under Lune) by emulating `script`,
-- `require(instance)` and the bits of `game` that shared modules touch.
-- Only pure modules (configs, utils, data helpers) can be loaded this way.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any

local Loader = {}

local cache: { [string]: any } = {}

local Node = {}
local function node(path: string)
	return setmetatable({ __path = path }, Node)
end
Node.__index = function(self, key: string)
	local path = rawget(self, "__path")
	if key == "Parent" then
		return node(string.match(path, "^(.*)/[^/]+$") or path)
	elseif key == "Name" then
		return string.match(path, "([^/]+)$")
	end
	return node(path .. "/" .. key)
end

local fakeGame = {
	GetService = function(_, name: string)
		if name == "ReplicatedStorage" then
			return { Shared = node("src/shared") }
		end
		error("service not available in unit tests: " .. name)
	end,
}

local function resolve(path: string): string
	if fs.isFile(path .. ".luau") then
		return path .. ".luau"
	elseif fs.isFile(path .. "/init.luau") then
		return path .. "/init.luau"
	end
	error("module not found: " .. path)
end

function Loader.require(target: any): any
	local path = rawget(target, "__path")
	local file = resolve(path)
	if cache[file] ~= nil then
		return cache[file]
	end
	local chunk = luau.load(fs.readFile(file), {
		debugName = file,
		environment = {
			script = node(path),
			require = Loader.require,
			game = fakeGame,
			Color3 = roblox.Color3,
			Vector3 = roblox.Vector3,
			Vector2 = roblox.Vector2,
			CFrame = roblox.CFrame,
			UDim2 = roblox.UDim2,
			Enum = roblox.Enum,
		},
	})
	local result = chunk()
	cache[file] = result
	return result
end

-- Shortcut: Loader.get("src/shared/Config/Slimes")
function Loader.get(path: string): any
	return Loader.require(node(path))
end

return Loader
