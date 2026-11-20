-- ShotFraming: pure numbers for the screenshot cameras and the gremlin label layout, shared by the
-- Studio shot director and tests/shots.luau (which projects them to check the framing numerically).
-- Stall-local coordinates: x across the stall, y up from the ground, -z towards the Snack Belt.
local ShotFraming = {}

-- Floating label size in studs (BillboardGui scale size), with and without the belt price line.
ShotFraming.LABEL_WIDTH = 6.2 -- just under the 6.5-stud pedestal pitch, so side neighbours never touch
ShotFraming.LABEL_HEIGHT = 4.4
ShotFraming.LABEL_HEIGHT_PRICED = 5.6
ShotFraming.LABEL_GAP = 1.2 -- studs between a gremlin's head and its label's lower edge

-- Player-stall gremlins are built 1.3x bigger, capped so the largest still fit the 6.5-stud pedestal pitch.
ShotFraming.STALL_BOOST = 1.3
ShotFraming.STALL_MAX_SCALE = 2.0
function ShotFraming.stallScale(rarityScale: number): number
	return math.min(rarityScale * ShotFraming.STALL_BOOST, ShotFraming.STALL_MAX_SCALE)
end

-- Extra lift for a pedestal's label: the back row (6-10) floats 3 studs higher so, seen from the cover
-- camera, its labels clear the front row's (checked by tests/shots.luau).
function ShotFraming.labelLift(pedestal: number): number
	return pedestal > 5 and 3 or 0
end

-- Cover (key 1): the player's full stall from above the lane, looking down into it so both rows of
-- labels separate on screen (found by a grid search over eye height/distance in tests/shots.luau terms).
ShotFraming.COVER_EYE = Vector3.new(-1, 34, -21)
ShotFraming.COVER_TARGET = Vector3.new(0, 9, 5)
ShotFraming.COVER_STAND = Vector3.new(-17.5, 4.6, -5) -- right of pedestal 1, under its label, above the buttons
ShotFraming.COVER_FOV = 65
-- The cover stall: pedestals 1-5 front, 6-10 back; mixed rarities, glowing mutations, a Divine and a Secret.
ShotFraming.COVER_LINEUP = {
	{ "SuyaSamurai", nil }, { "JollofJetpack", "Gold" }, { "DanfoDragon", nil }, { "ZoboZeppelin", "Owambe Lace" }, { "PuffPuffPaladin", nil },
	{ "AmalaArchmage", nil }, { "GeneratorSeraph", "Rainbow" }, { "PlantainPharaoh", "Neon" }, { "InfinitePuffPuffParadox", "Harmattan" }, { "KunuLeviathan", nil },
}

-- Buy (key 2), world-relative to the stall's x: the player on the lane, back to camera, a Legendary overhead.
ShotFraming.BUY_PLAYER = Vector3.new(3, 3, 7.5)
ShotFraming.BUY_EYE = Vector3.new(6, 9, 26)
ShotFraming.BUY_TARGET = Vector3.new(4, 7.5, 0)
-- Belt lineup for the buy shot: x offsets from the stall, right of the player (the cash panel is on the left).
ShotFraming.BUY_LINEUP = { { "KilishiKnight", nil, -9 }, { "OkraOctopus", "Pepper", 10 }, { "ChinChinCheetah", "Lagoon", 17 } }
ShotFraming.BUY_FOV = 70
ShotFraming.BUY_CARRIED = "DanfoDragon"

-- Threat (key 3), world-relative to the stall's x: from beside the player's stall looking north-east,
-- a Pocket Pirate locked out at the glowing shutter, the player ready to whack it, a second pirate
-- stealing from the rival stall across the belt, and the surge wall rising out of the lagoon behind.
ShotFraming.THREAT_EYE = Vector3.new(-36,14,22)
ShotFraming.THREAT_TARGET = Vector3.new(4,5,2)
ShotFraming.THREAT_PIRATE = Vector3.new(4, 0, 22) -- feet, in front of the shutter
ShotFraming.THREAT_PLAYER = Vector3.new(-7, 3, 18)
ShotFraming.THREAT_WAVE_Z = -84
ShotFraming.THREAT_FOV = 70
ShotFraming.THREAT_BOSS = Vector3.new(-14, 0, 40) -- Oga Pepperpot's feet, behind the player on the lane

-- Progress (key 4): straight on to the stall, panels over the sides.
ShotFraming.PROGRESS_EYE = Vector3.new(0, 14, -30)
ShotFraming.PROGRESS_TARGET = Vector3.new(0, 6, 2)
ShotFraming.PROGRESS_STAND = Vector3.new(0, 4.6, -10)
ShotFraming.PROGRESS_FOV = 70

return ShotFraming
