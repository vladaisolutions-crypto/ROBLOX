--!strict
-- The bonk bat swing, posed procedurally the way a real swing moves.
--
-- The bat follows a keyframed path (relative to where the player faced when
-- the swing started): cocked up behind the right shoulder, whipped round
-- level in front, wrapped over the left shoulder. The hips and chest turn
-- into it, the front leg strides, and two-bone IK puts both hands on the bat
-- (right hand at the tool grip, left hand just below it). Joint frames are
-- Motor6D.C0 / AnimationConstraint.Attachment0; animations are muted by the
-- caller so these poses are the whole story.

local BatSwing = {}

export type Joint = {
	Key: Instance,
	Part0: BasePart,
	Part1: BasePart,
	GetA0: () -> CFrame,
	SetA0: (CFrame) -> (),
	A1: CFrame,
}

-- Bat in the start frame (x right, y up, z = -forward, like a CFrame):
-- Knob = position of the knob end, Dir = knob-to-barrel direction.
-- Body: Root/Waist yaw (degrees, + turns left), legs (hip/knee pitch).
type Key = {
	Time: number,
	Knob: Vector3,
	Dir: Vector3,
	Root: number,
	Waist: number,
	RHip: number,
	LHip: number,
	RKnee: number,
	LKnee: number,
}

local function key(t: number, knob: Vector3, dir: Vector3, root: number, waist: number, legs: { number }): Key
	return {
		Time = t,
		Knob = knob,
		Dir = dir.Unit,
		Root = root,
		Waist = waist,
		RHip = legs[1],
		LHip = legs[2],
		RKnee = legs[3],
		LKnee = legs[4],
	}
end

-- Positions are in studs from the HumanoidRootPart; -z is forward.
local KEYS: { Key } = {
	-- Ready: bat held up in front of the right shoulder.
	key(0, Vector3.new(0.7, 0.4, -0.9), Vector3.new(0.1, 1, -0.3), 0, 0, { 0, 0, 0, 0 }),
	-- Load: chest turned away, hands up by the right ear, bat pointing up and back.
	key(0.15, Vector3.new(1.0, 1.5, 0.1), Vector3.new(-0.3, 0.75, 0.6), -40, -30, { 5, 28, -12, -38 }),
	-- Launch: front foot down, hips opening, bat dropping flat behind the hands.
	key(0.22, Vector3.new(0.9, 0.7, -0.5), Vector3.new(0.95, -0.12, 0.3), -10, -15, { -10, 5, -20, -5 }),
	-- Contact: hands out front at belly height, bat level and pointing forward.
	key(0.28, Vector3.new(0.1, 0.4, -1.3), Vector3.new(-0.15, -0.08, -1), 25, 20, { -15, 10, -30, -5 }),
	-- Extension: bat swept out to the left.
	key(0.36, Vector3.new(-0.8, 0.6, -0.8), Vector3.new(-1, 0.05, -0.25), 45, 40, { -18, 8, -34, 0 }),
	-- Wrap: bat finishes over the left shoulder.
	key(0.5, Vector3.new(-0.7, 1.4, -0.4), Vector3.new(-0.35, 0.6, 0.72), 45, 50, { -18, 5, -34, 0 }),
	key(0.85, Vector3.new(0.7, 0.4, -0.9), Vector3.new(0.1, 1, -0.3), 0, 0, { 0, 0, 0, 0 }),
}
BatSwing.Length = 0.85
BatSwing.ContactTime = 0.28

local function smooth(k: number): number
	return k * k * (3 - 2 * k)
end

local function sample(t: number): Key
	for i = 1, #KEYS - 1 do
		local a, b = KEYS[i], KEYS[i + 1]
		if t <= b.Time then
			local k = smooth(math.clamp((t - a.Time) / (b.Time - a.Time), 0, 1))
			local function mix(x: number, y: number): number
				return x + (y - x) * k
			end
			return {
				Time = t,
				Knob = a.Knob:Lerp(b.Knob, k),
				Dir = a.Dir:Lerp(b.Dir, k).Unit,
				Root = mix(a.Root, b.Root),
				Waist = mix(a.Waist, b.Waist),
				RHip = mix(a.RHip, b.RHip),
				LHip = mix(a.LHip, b.LHip),
				RKnee = mix(a.RKnee, b.RKnee),
				LKnee = mix(a.LKnee, b.LKnee),
			}
		end
	end
	return KEYS[#KEYS]
end

local function rotated(rest: CFrame, yaw: number, pitch: number): CFrame
	return CFrame.new(rest.Position)
		* CFrame.Angles(0, math.rad(yaw), 0)
		* CFrame.Angles(math.rad(pitch), 0, 0)
		* rest.Rotation
end

-- Rotation taking local axis `u` (with helper `h`) onto world `uw` (with `hw`).
local function align(u: Vector3, h: Vector3, uw: Vector3, hw: Vector3): CFrame
	local function basis(a: Vector3, b: Vector3): CFrame
		local x = a.Unit
		local y = (b - x * b:Dot(x))
		y = if y.Magnitude > 1e-4 then y.Unit else x:Cross(Vector3.zAxis).Unit
		return CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y))
	end
	return basis(uw, hw) * basis(u, h):Inverse()
end

-- A part's world CFrame placed so that its point `localPoint` lands on
-- `world` with rotation `rotation`.
local function place(rotation: CFrame, localPoint: Vector3, world: Vector3): CFrame
	return CFrame.new(world) * rotation * CFrame.new(-localPoint)
end

-- Two-bone IK: shoulder S to target W, elbow bending towards `pole`.
local function solve(S: Vector3, W: Vector3, l1: number, l2: number, pole: Vector3): Vector3
	local offset = W - S
	local d = math.clamp(offset.Magnitude, math.abs(l1 - l2) + 0.01, l1 + l2 - 0.01)
	local dir = if offset.Magnitude > 1e-4 then offset.Unit else Vector3.yAxis * -1
	local a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
	local h = math.sqrt(math.max(l1 * l1 - a * a, 0))
	local side = pole - dir * pole:Dot(dir)
	side = if side.Magnitude > 1e-4 then side.Unit else Vector3.yAxis * -1
	return S + dir * a + side * h
end

-- Pose `joints` (by name) for time `t` of the swing. `frame` is the
-- HumanoidRootPart CFrame the swing is relative to (the live root, so the
-- player can still move); `rest` holds each joint's unposed A0; `grip` is
-- the bat handle's offset from the right hand (Handle = Hand * grip).
function BatSwing.Pose(
	joints: { [string]: Joint },
	rest: { [Instance]: CFrame },
	frame: CFrame,
	t: number,
	grip: CFrame
)
	local k = sample(t)
	local function set(name: string, cf: CFrame)
		local joint = joints[name]
		if joint then
			joint.SetA0(cf)
		end
	end
	local function restOf(name: string): CFrame?
		local joint = joints[name]
		return if joint then rest[joint.Key] else nil
	end

	-- Body: hips and chest turn, head stays on the target, legs stride.
	local root, waist = joints.Root, joints.Waist
	local rootA0 = if root then rotated(rest[root.Key], k.Root, 0) else nil
	local waistA0 = if waist then rotated(rest[waist.Key], k.Waist, 0) else nil
	if rootA0 then
		set("Root", rootA0)
	end
	if waistA0 then
		set("Waist", waistA0)
	end
	local neckRest = restOf("Neck")
	if neckRest then
		set("Neck", rotated(neckRest, -(k.Root + k.Waist) * 0.8, 0))
	end
	local legs: { [string]: number } = { RightHip = k.RHip, LeftHip = k.LHip, RightKnee = k.RKnee, LeftKnee = k.LKnee }
	for name, pitch in legs do
		local r = restOf(name)
		if r then
			set(name, rotated(r, 0, pitch))
		end
	end

	-- Arms need the full R15 chain.
	local rs, re, rw = joints.RightShoulder, joints.RightElbow, joints.RightWrist
	local ls, le, lw = joints.LeftShoulder, joints.LeftElbow, joints.LeftWrist
	if not (root and waist and rootA0 and waistA0 and rs and re and rw and ls and le and lw) then
		return
	end
	-- Where the chest is this frame (from our own root and waist pose).
	local lowerTorso = frame * rootA0 * root.A1:Inverse()
	local upperTorso = lowerTorso * waistA0 * waist.A1:Inverse()

	-- The bat and the right hand that holds it.
	local knob = frame:PointToWorldSpace(k.Knob)
	local dir = frame:VectorToWorldSpace(k.Dir)
	local up = frame.UpVector
	local side = dir:Cross(up)
	if side.Magnitude < 1e-3 then
		side = frame.RightVector
	end
	-- Handle: +Z runs knob to barrel, its centre 2.1 studs from the knob.
	local x = side.Unit
	local handle = CFrame.fromMatrix(knob + dir * 2.1, x, dir:Cross(x), dir)
	local rightHand = handle * grip:Inverse()

	local down = -upperTorso.UpVector
	local function arm(shoulder: Joint, elbow: Joint, wrist: Joint, target: Vector3, outward: Vector3, hand: CFrame?)
		local S = (upperTorso * rest[shoulder.Key]).Position
		local upperLen = (rest[elbow.Key].Position - shoulder.A1.Position).Magnitude
		local lowerLen = (rest[wrist.Key].Position - elbow.A1.Position).Magnitude
		local E = solve(S, target, upperLen, lowerLen, down * 0.6 + outward * 0.4)
		-- Upper arm: shoulder point on S, elbow point on E, front towards the hand.
		local uLocal = rest[elbow.Key].Position - shoulder.A1.Position
		local upperRot = align(uLocal, Vector3.new(0, 0, -1), E - S, target - E)
		local upperArm = place(upperRot, shoulder.A1.Position, S)
		local lLocal = rest[wrist.Key].Position - elbow.A1.Position
		local lowerRot = align(lLocal, Vector3.new(0, 0, -1), target - E, S - E)
		local lowerArm = place(lowerRot, elbow.A1.Position, E)
		shoulder.SetA0(upperTorso:Inverse() * upperArm * shoulder.A1)
		elbow.SetA0(upperArm:Inverse() * lowerArm * elbow.A1)
		if hand then
			wrist.SetA0(lowerArm:Inverse() * hand * wrist.A1)
		else
			wrist.SetA0(rest[wrist.Key])
		end
	end
	local rightWristAt = (rightHand * rw.A1).Position
	arm(rs, re, rw, rightWristAt, upperTorso.RightVector, rightHand)
	-- Left hand just below the right, nearer the knob.
	local leftAt = (handle * CFrame.new(0, 0, -1.95)).Position
	arm(ls, le, lw, leftAt, -upperTorso.RightVector, nil)
end

return BatSwing
