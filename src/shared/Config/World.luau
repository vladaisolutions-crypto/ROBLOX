--!strict
-- Map layout. Everything is generated from these numbers at server start.

local PLOT_X = { -135, -45, 45, 135 }
-- Plot centres sit this far from the belt; bases are deep so they hold up to
-- 7 rows of pedestals (the entrance stays the same distance from the belt).
local PLOT_Z = 80

local plotCFrames: { CFrame } = {}
-- North row faces +Z (towards the belt), south row is rotated to face -Z.
for _, x in PLOT_X do
	table.insert(plotCFrames, CFrame.new(x, 0, -PLOT_Z))
end
for _, x in PLOT_X do
	table.insert(plotCFrames, CFrame.new(x, 0, PLOT_Z) * CFrame.Angles(0, math.pi, 0))
end

return {
	PlotCFrames = plotCFrames,
	PlotWidth = 64, -- local X
	PlotDepth = 108, -- local Z, entrance at +Z/2
	FloorY = 1,
	WallHeight = 5, -- fence collision: low enough to jump (default jump ~7.2 studs); the gate lock barrier stays BarrierHeight
	BarrierHeight = 18,

	PedestalColumns = 6,
	PedestalRows = 7,
	PedestalSpacingX = 10,
	PedestalSpacingZ = 13,

	BeltStartX = -175,
	BeltEndX = 175,
	BeltWidth = 14,
	BeltY = 1.4,
	BeltSpeed = 7, -- studs per second
	SpawnEverySeconds = 2.5,
	MaxBeltSlimes = 30,

	MapSizeX = 520,
	MapSizeZ = 360,
}
