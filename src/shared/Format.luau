-- Format: turns big numbers into short, readable money strings ($1.25M, +$4.2K/s).
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx" }

-- Shortens a number to at most three significant digits with a suffix.
function Format.short(value: number): string
	local negative = value < 0
	local n = math.abs(value)
	local tier = 1
	while n >= 1000 and tier < #SUFFIXES do
		n /= 1000
		tier += 1
	end
	local text
	if tier == 1 then
		text = tostring(math.floor(n))
	elseif n >= 100 then
		text = string.format("%d", math.floor(n))
	elseif n >= 10 then
		text = string.format("%.1f", math.floor(n * 10) / 10)
	else
		text = string.format("%.2f", math.floor(n * 100) / 100)
	end
	text = text:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
	return (negative and "-" or "") .. text .. SUFFIXES[tier]
end

function Format.money(value: number): string
	return "$" .. Format.short(value)
end

function Format.perSecond(value: number): string
	return "+$" .. Format.short(value) .. "/s"
end

function Format.seconds(value: number): string
	return string.format("%ds", math.max(0, math.ceil(value)))
end

return Format
