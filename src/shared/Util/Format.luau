--!strict
-- Number and time formatting shared by server messages and client UI.

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local Format = {}

-- 1234 -> "1.23K", 15000000 -> "15M"
function Format.Number(value: number): string
	if value ~= value then
		return "0"
	end
	local negative = value < 0
	value = math.abs(value)
	if value < 1000 then
		local text = if value == math.floor(value) then tostring(value) else string.format("%.1f", value)
		return (if negative then "-" else "") .. text
	end
	local tier = math.min(math.floor(math.log10(value) / 3), #SUFFIXES - 1)
	local scaled = value / 10 ^ (tier * 3)
	local text
	if scaled >= 100 then
		text = string.format("%d", math.floor(scaled))
	elseif scaled >= 10 then
		text = string.format("%.1f", math.floor(scaled * 10) / 10)
	else
		text = string.format("%.2f", math.floor(scaled * 100) / 100)
	end
	-- Trim trailing decimal zeros: "1.50" -> "1.5", "2.00" -> "2" (never "100" -> "1")
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "%.?0+$", "")
	end
	return (if negative then "-" else "") .. text .. SUFFIXES[tier + 1]
end

function Format.Cash(value: number): string
	return "$" .. Format.Number(value)
end

-- 75 -> "1:15", 3725 -> "1:02:05"
function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

return Format
