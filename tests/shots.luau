-- Numeric framing check for the Studio screenshots, run with: lune run tests/shots.luau
-- Rebuilds each shot camera from ShotFraming + Config (the same numbers ShotDirectorServer uses),
-- projects the gremlin labels, the player and the shot's subjects, and fails if anything important is
-- off screen, too small at judge size, overlapping another label or under the HUD.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local cache = {}
local function load(name)
	if cache[name] then
		return cache[name]
	end
	local source = fs.readFile("src/shared/" .. name .. ".luau")
	local parent = setmetatable({}, { __index = function(_, k) return k end })
	local env = setmetatable({
		script = { Parent = parent },
		require = function(n) return load(n) end,
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		Enum = roblox.Enum,
	}, { __index = _G })
	cache[name] = luau.load(source, { debugName = name, environment = env })()
	return cache[name]
end

local Config = load("Config")
local Catalog = load("GremlinCatalog")
local Rarities = load("Rarities")
local F = load("ShotFraming")

local failures = 0
local function check(ok, message)
	if not ok then
		failures += 1
		print("  FAIL " .. message)
	end
end

-- Stall CFrame and pedestal tops exactly as WorldBuilder.buildStall makes them.
local function stallCFrame(index)
	local p = Config.STALL_SPOTS[index]
	return CFrame.lookAt(p, Vector3.new(p.X, p.Y, Config.BELT_Z))
end
local function pedestalTop(cf, pedestal)
	local row = pedestal > 5 and 1 or 0
	local col = (pedestal - 1) % 5
	local base = Config.STALL_FLOOR_HEIGHT + (row == 0 and 0 or 2.2)
	return cf * CFrame.new(-13 + col * 6.5, base + 1, row == 0 and -4 or 6)
end
local TOPS = { Ball = 3.4, Tall = 4.3 }
local function topHeight(gremlin)
	return ((TOPS[gremlin.recipe.shape] or 3.3) + 1.2) * Rarities.get(gremlin.rarity).scale
end
-- the player's own stall builds gremlins bigger (ShotFraming.stallScale)
local function stallTopHeight(gremlin)
	return ((TOPS[gremlin.recipe.shape] or 3.3) + 1.2) * F.stallScale(Rarities.get(gremlin.rarity).scale)
end

-- Projects a world point; returns pixel x, y and depth (or nil behind the camera).
local function project(cam, fov, w, h, p)
	local l = cam:PointToObjectSpace(p)
	if l.Z >= -0.1 then
		return nil
	end
	local t = math.tan(math.rad(fov) / 2)
	local depth = -l.Z
	local nx, ny = l.X / (depth * t * (w / h)), l.Y / (depth * t)
	return (nx + 1) / 2 * w, (1 - ny) / 2 * h, depth
end
local function pxPerStud(fov, h, depth)
	return h / (2 * depth * math.tan(math.rad(fov) / 2))
end

-- HUD rectangles in screen scale (x0, y0, x1, y1), kept in sync with Hud/Buttons by hand.
local HUD = {
	{ "feature strip", 0.17, 0, 0.83, 0.042 },
	{ "event banner", 0.27, 0.048, 0.73, 0.153 },
	{ "logo", 0.8, 0.048, 0.99, 0.12 },
	{ "cash", 0.012, 0.13, 0.232, 0.31 },
	{ "carry card", 0.012, 0.325, 0.232, 0.455 },
	{ "orders", 0.8, 0.135, 0.99, 0.42 },
	{ "buttons", 0.105, 0.835, 0.895, 0.975 },
}
local ROBLOX_MENU = { 0, 0, 0.16, 0.12 } -- Roblox's own top-left buttons at a typical Studio window

local function overlaps(a, b)
	return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
end

-- One shot: labels {name, world centre, studs w/h}, subjects {name, world point}.
local function runShot(name, cam, fov, labels, subjects, w, h, minLabelPx)
	print(string.format("%s @ %dx%d", name, w, h))
	local rects = {}
	for _, label in labels do
		local x, y, depth = project(cam, fov, w, h, label.centre)
		if not x then
			check(false, label.name .. " label behind camera")
			continue
		end
		local s = pxPerStud(fov, h, depth)
		local hw, hh = label.w * s / 2, label.h * s / 2
		local rect = { x - hw, y - hh, x + hw, y + hh, label.name }
		table.insert(rects, rect)
		local lineH = hh * 2 / 3
		print(string.format("  label %-18s at (%4d,%4d) %3dx%3d px, line %4.1f px, depth %4.1f", label.name, x, y, hw * 2, hh * 2, lineH, depth))
		check(rect[1] >= 0 and rect[3] <= w and rect[2] >= 0 and rect[4] <= h * 0.83, label.name .. " label not fully on screen above the buttons")
		check(lineH >= minLabelPx, label.name .. " label lines under " .. minLabelPx .. " px")
		local menu = { ROBLOX_MENU[1] * w, ROBLOX_MENU[2] * h, ROBLOX_MENU[3] * w, ROBLOX_MENU[4] * h }
		check(not overlaps(rect, menu), label.name .. " label under Roblox's top-left menu")
		for _, hud in HUD do
			local hr = { hud[2] * w, hud[3] * h, hud[4] * w, hud[5] * h }
			if hud[1] ~= "event banner" or name ~= "buy" then
				check(not overlaps(rect, hr), label.name .. " label under HUD " .. hud[1])
			end
		end
	end
	for i = 1, #rects do
		for j = i + 1, #rects do
			check(not overlaps(rects[i], rects[j]), "labels overlap: " .. rects[i][5] .. " / " .. rects[j][5])
		end
	end
	for _, subject in subjects do
		local x, y, depth = project(cam, fov, w, h, subject.point)
		local inside = x ~= nil and x >= 0 and x <= w and y >= 0 and y <= h
		print(string.format("  %-28s %s", subject.name, x and string.format("(%4d,%4d) depth %5.1f", x, y, depth) or "behind camera"))
		if subject.mustSee then
			check(inside, subject.name .. " off screen")
		end
		if subject.maxDepth and depth then
			check(depth <= subject.maxDepth, subject.name .. " too far from the camera")
		end
	end
end

local COVER = F.COVER_LINEUP

local function stallLabels(cf, entries)
	local labels = {}
	for index, entry in entries do
		local gremlin = Catalog.get(entry[1])
		assert(gremlin, "unknown gremlin " .. entry[1])
		local top = pedestalTop(cf, index).Position
		local y = stallTopHeight(gremlin) + F.LABEL_GAP + F.LABEL_HEIGHT / 2 + F.labelLift(index)
		table.insert(labels, { name = gremlin.name, centre = top + Vector3.new(0, y, 0), w = F.LABEL_WIDTH, h = F.LABEL_HEIGHT })
	end
	return labels
end

local cf1 = stallCFrame(1)
local fh = Config.STALL_FLOOR_HEIGHT
for _, size in { { 768, 480 }, { 1920, 1080 } } do
	local w, h = size[1], size[2]
	local minPx = 9 * h / 480
	-- 1 cover
	local cam = CFrame.lookAt(cf1:PointToWorldSpace(F.COVER_EYE), cf1:PointToWorldSpace(F.COVER_TARGET))
	local stand = cf1:PointToWorldSpace(F.COVER_STAND)
	local subjects = {
		{ name = "player head", point = stand + Vector3.new(0, 2.5, 0), mustSee = true },
		{ name = "player feet", point = stand - Vector3.new(0, 3, 0), mustSee = true },
		{ name = "stall sign", point = cf1:PointToWorldSpace(Vector3.new(0, fh + 15, 12.2)), mustSee = false },
		{ name = "skyline top (x0,z130,y50)", point = Vector3.new(0, 50, 130), mustSee = false },
	}
	for index = 1, #COVER do
		local p = pedestalTop(cf1, index).Position
		table.insert(subjects, { name = "gremlin feet " .. index, point = p, mustSee = true })
	end
	local labels = stallLabels(cf1, COVER)
	runShot("cover", cam, F.COVER_FOV, labels, subjects, w, h, minPx)
	local hx, hy = project(cam, F.COVER_FOV, w, h, stand + Vector3.new(0, 2.5, 0))
	local _, fy = project(cam, F.COVER_FOV, w, h, stand - Vector3.new(0, 3, 0))
	check(fy < h * 0.83, "cover: player's feet behind the button row")
	for _, label in labels do
		local lx, ly, depth = project(cam, F.COVER_FOV, w, h, label.centre)
		local s = pxPerStud(F.COVER_FOV, h, depth)
		check(math.abs(hx - lx) > label.w * s / 2 + 8 or hy - 10 > ly + label.h * s / 2, "cover: player's head under the " .. label.name .. " label")
	end
	-- 2 buy
	local x = cf1.Position.X
	cam = CFrame.lookAt(F.BUY_EYE + Vector3.new(x, 0, 0), F.BUY_TARGET + Vector3.new(x, 0, 0))
	local player = F.BUY_PLAYER + Vector3.new(x, 0, 0)
	local carried = Catalog.get("DanfoDragon")
	local carryLabel = player + Vector3.new(0, 3.2 + topHeight(carried) + F.LABEL_GAP + F.LABEL_HEIGHT / 2, 0)
	local beltLabels = { { name = carried.name .. " (held)", centre = carryLabel, w = F.LABEL_WIDTH, h = F.LABEL_HEIGHT } }
	local beltSubjects = { { name = "player feet", point = player - Vector3.new(0, 3, 0), mustSee = true } }
	for i, entry in F.BUY_LINEUP do
		local g = Catalog.get(entry[1])
		local bx = entry[3] + x
		local lift = 0
		local c = Vector3.new(bx, Config.BELT_TOP_Y + topHeight(g) + F.LABEL_GAP + F.LABEL_HEIGHT_PRICED / 2 + lift, Config.BELT_Z)
		table.insert(beltLabels, { name = g.name, centre = c, w = F.LABEL_WIDTH, h = F.LABEL_HEIGHT_PRICED })
		table.insert(beltSubjects, { name = "belt gremlin " .. g.name, point = Vector3.new(bx, Config.BELT_TOP_Y + 1, Config.BELT_Z), mustSee = false })
	end
	runShot("buy", cam, F.BUY_FOV, beltLabels, beltSubjects, w, h, minPx * 0.8)
	-- 3 threat
	cam = CFrame.lookAt(F.THREAT_EYE + Vector3.new(x, 0, 0), F.THREAT_TARGET + Vector3.new(x, 0, 0))
	local cf4 = stallCFrame(4)
	local pirateSpot = (CFrame.new(pedestalTop(cf4, 3).Position) * cf4.Rotation * CFrame.new(0, 0, -6)).Position
	runShot("threat", cam, F.THREAT_FOV, {}, {
		{ name = "rival-stall pirate head", point = Vector3.new(pirateSpot.X, fh + 6.5, pirateSpot.Z), mustSee = true },
		{ name = "rival-stall pirate label", point = Vector3.new(pirateSpot.X, fh + 9.5, pirateSpot.Z), mustSee = true },
		{ name = "shutter pirate head", point = F.THREAT_PIRATE + Vector3.new(x, 6.5, 0), mustSee = true, maxDepth = 45 },
		{ name = "shutter pirate feet", point = F.THREAT_PIRATE + Vector3.new(x, 0, 0), mustSee = true },
		{ name = "shutter pirate label", point = F.THREAT_PIRATE + Vector3.new(x, 9.5, 0), mustSee = true },
		{ name = "player head", point = F.THREAT_PLAYER + Vector3.new(x, 2.5, 0), mustSee = true },
		{ name = "player feet", point = F.THREAT_PLAYER + Vector3.new(x, -3, 0), mustSee = true },
		{ name = "own shutter centre", point = cf1:PointToWorldSpace(Vector3.new(0, fh + 5, -13.6)), mustSee = true },
		{ name = "own shutter left", point = cf1:PointToWorldSpace(Vector3.new(-18, fh + 5, -13.6)), mustSee = false },
		{ name = "own shutter right", point = cf1:PointToWorldSpace(Vector3.new(18, fh + 5, -13.6)), mustSee = false },
		{ name = "wave crest above pirate", point = Vector3.new(x, 27, F.THREAT_WAVE_Z), mustSee = true },
		{ name = "wave crest x+60", point = Vector3.new(x + 60, 27, F.THREAT_WAVE_Z), mustSee = true },
		{ name = "boss hat top", point = F.THREAT_BOSS + Vector3.new(x, 22, 0), mustSee = true },
		{ name = "boss feet", point = F.THREAT_BOSS + Vector3.new(x, 0, 0), mustSee = true },
		{ name = "boss apron sign", point = F.THREAT_BOSS + Vector3.new(x, 5.6, 0), mustSee = true },
	}, w, h, minPx)
	-- the boss (about 13 studs wide, 22 tall) must not stand in front of the shot's other subjects
	do
		local bx, by, bdepth = project(cam, F.THREAT_FOV, w, h, F.THREAT_BOSS + Vector3.new(x, 11, 0))
		local s = pxPerStud(F.THREAT_FOV, h, bdepth)
		local box = { bx - 7 * s, by - 11 * s, bx + 7 * s, by + 11 * s }
		for _, subject in {
			{ "shutter pirate head", F.THREAT_PIRATE + Vector3.new(x, 6.5, 0) },
			{ "shutter pirate label", F.THREAT_PIRATE + Vector3.new(x, 9.5, 0) },
			{ "player head", F.THREAT_PLAYER + Vector3.new(x, 2.5, 0) },
			{ "own shutter centre", cf1:PointToWorldSpace(Vector3.new(0, fh + 5, -13.6)) },
			{ "rival-stall pirate head", Vector3.new(pirateSpot.X, fh + 6.5, pirateSpot.Z) },
		} do
			local px, py, pdepth = project(cam, F.THREAT_FOV, w, h, subject[2])
			local inside = px and px > box[1] and px < box[3] and py > box[2] and py < box[4]
			check(not (inside and bdepth < pdepth + 6), "threat: the boss hides the " .. subject[1])
		end
		check(bdepth < 90, "threat: the boss is too far away to read")
		-- his name tag and hat stay clear of the boss / surge banners (top centre)
		local banners = { { 0.27 * w, 0.048 * h, 0.73 * w, 0.153 * h }, { 0.27 * w, 0.165 * h, 0.73 * w, 0.265 * h } }
		for _, part in { { "apron sign", 5.6 }, { "face", 11 }, { "hat top", 22 } } do
			local px, py = project(cam, F.THREAT_FOV, w, h, F.THREAT_BOSS + Vector3.new(x, part[2], 0))
			for _, r in banners do
				check(not (px and px > r[1] and px < r[3] and py > r[2] and py < r[4]), "threat: boss " .. part[1] .. " under a banner")
			end
			check(px ~= nil and py > 0.05 * h, "threat: boss " .. part[1] .. " off the top")
			-- the threat shot hides the cash panel (payload.hide); every other panel still counts
			for _, hud in HUD do
				if hud[1] ~= "cash" and hud[1] ~= "event banner" and hud[1] ~= "carry card" then -- no carry in this shot
					check(not (px > hud[2] * w and px < hud[4] * w and py > hud[3] * h and py < hud[5] * h), "threat: boss " .. part[1] .. " under HUD " .. hud[1])
				end
			end
			check(not (px < ROBLOX_MENU[3] * w and py < ROBLOX_MENU[4] * h), "threat: boss " .. part[1] .. " under Roblox's menu")
		end
	end
	-- 4 progress (panels cover the sides, so only the middle must be clear)
	cam = CFrame.lookAt(cf1:PointToWorldSpace(F.PROGRESS_EYE), cf1:PointToWorldSpace(F.PROGRESS_TARGET))
	runShot("progress", cam, F.PROGRESS_FOV, {}, {
		{ name = "player", point = cf1:PointToWorldSpace(F.PROGRESS_STAND), mustSee = true },
		{ name = "pedestal 3", point = pedestalTop(cf1, 3).Position, mustSee = true },
	}, w, h, minPx)
end

if failures > 0 then
	print(failures .. " framing problem(s)")
	process.exit(1)
end
print("shots: all framing checks passed")
