local modules = {}

table.insert(modules, function()

local m = {}

m.ModuleType   = "MOVESET"
m.Name         = "Mis Print"
m.Description = "Idle, walk and run animations. Sprinting screams. you can get flashed for about two seconds."
m.InternalName = "MOVESET_MISPRINT"
-- Everything here ships in the Mis_print zip.
m.Assets = {
	"Mis_printIdle.anim",
	"Mis_printWalk.anim",
	"Mis_printRun.anim",
	"Mis_printStunned.anim",
	"Mis_printKill.anim",
	"Mis_printWalk.mp3",
	"Mis_printRun.mp3",
	"Mis_printStunned.mp3",
	"Mis_printKill.mp3",
	"Mis_printVocal.mp3",
}

-- Passive mode: when on, touching players does not kill them. Saved with the module settings.
local passive = false

-- Settings panel: the controls and the passive switch.
m.Config = function(parent)
	Util_CreateText(parent, "Mis Print", 20, Enum.TextXAlignment.Center)
	Util_CreateSeparator(parent)
	Util_CreateText(parent, "Shift: run (hold)\nMobile: tap RUN to toggle\nF or the STUN button: stun yourself\nTouching it kills unless passive is on.\nA sudden bright flash stuns it.", 14, Enum.TextXAlignment.Center)
	Util_CreateSwitch(parent, "Passive (disables killing)", passive).Changed:Connect(function(val)
		passive = val
	end)
end

m.SaveConfig = function() return { passive = passive } end

m.LoadConfig = function(save)
	passive = not not (save and save.passive)
end


local CAS              = game:GetService("ContextActionService")
local Lighting         = game:GetService("Lighting")
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService       = game:GetService("GuiService")

-- Seconds to crossfade between idle, walk and run. The stun cuts in faster.
local FADE_TIME  = 0.2
local STUN_FADE  = 0.05
-- Added on top of LIFT if the feet sit too low or high in a game.
local EXTRA_LIFT = 0

-- WalkSpeed values. The walk animation is authored for about 1.88, so at 6 the feet slide a little.
local WALK_SPEED = 6
local RUN_SPEED  = 35

local TARGET_SPEED = { walk = WALK_SPEED, run = RUN_SPEED }
-- Studs to raise the root per animation so the feet stand on the floor (R6 floor is 3 studs below the root).
local LIFT         = { idle = 3.304, walk = 2.827, run = 2.812, stunned = 1.948 }

-- Slide: seconds it takes to build up or lose speed. Higher is slidier, 0 turns it off.
local SLIDE = 0.65
-- Sliding faster than this keeps the walk or run animation playing after you let go.
local SLIDE_ANIM_MIN = 2

-- Hitbox: size and offset from the root part. It is used for touch kills and for lights that can stun.
-- Set HITBOX_VISIBLE to true to see it while tuning.
local HITBOX_SIZE    = Vector3.new(6, 7, 6)
local HITBOX_OFFSET  = CFrame.new(0, 0, 0)
local HITBOX_VISIBLE = false

-- Kill: how long ReanimateFling is asked to hold the target, and how long before the same target can be hit again.
-- KILL_LENGTH is the length of Mis_printKill.anim.
local KILL_FLING_TIME = 3
local KILL_COOLDOWN   = 3.5
local KILL_LENGTH     = 3.4167
local KILL_VOLUME     = 1

-- Stun length is the length of Mis_printStunned.anim.
-- A flash counts when brightness reaches FLASH_LEVEL and jumps up by FLASH_JUMP in one frame.
local STUN_LENGTH = 2.0167
local FLASH_LEVEL = 1
local FLASH_JUMP  = 0.5

LIFT.kill = 1.613

local SOUND_FILES = {
	walk = "Mis_printWalk.mp3",
	run  = "Mis_printRun.mp3",
}
local SOUND_VOLUME = 1
local STUN_VOLUME  = 1

-- Vocal: starts at VOCAL_MIN_SPEED and speeds up over VOCAL_RAMP seconds, slows down over VOCAL_RAMP_DOWN.
-- The distortion is strongest while slow and fades out at full speed.
local VOCAL_VOLUME    = 1
local VOCAL_RAMP      = 5
local VOCAL_RAMP_DOWN = 3
local VOCAL_MIN_SPEED = 0.3
local CRUNCH_MAX      = 0.9
local CRUNCH_HZ_START = 24
local CRUNCH_HZ_END   = 4

-- Mobile button images (same ones the Ryan moveset uses), the gap between buttons, and how far to shift them from the jump button.
local SPRINT_IMAGE      = "rbxassetid://89190879948216"
local SPRINT_IMAGE_DOWN = "rbxassetid://96892467644525"
local STUN_IMAGE        = "rbxassetid://16803802267"
local BUTTON_GAP        = 16
local BUTTON_Y_OFFSET   = 60

local rootPart  = nil
local rootJoint = nil
local hum       = nil

local anims  = {}
local phase  = {}
local weight = {}
local scale  = {}

local state      = "idle"
local keyRun     = false
local toggleRun  = false
local running    = false
local runButton  = nil
local stunButton = nil
local savedSpeed = 16
local originalJumpPower  = nil
local originalJumpHeight = nil
local liftNow    = LIFT.idle

local sounds     = {}
local soundState = nil
local stunSound  = nil
local killSound  = nil

local vocal       = nil
local crunch      = nil
local vocalOn     = false
local vocalP      = 0
local crunchPhase = 0

local stunned    = false
local stunTime   = 0
local lastLevels = {}

local hitbox     = nil
local hitParams  = nil
local figureRef  = nil
local vel        = Vector3.zero
local killing    = false
local killTime   = 0
local killedAt   = {}
local elapsed    = 0


-- Builds an animator for one .anim file. Weight starts at 0 until it is faded in.
local function loadAnim(fig, file, looped)
	local a  = AnimLib.Animator.new()
	a.rig    = fig
	a.track  = AnimLib.Track.fromfile(AssetGetPathFromFilename(file))
	a.looped = looped
	a.speed  = 1
	a.weight = 0
	return a
end

-- The joint between the root part and the torso, used to apply the floor lift.
local function findRootJoint(fig)
	local found = nil
	for _, d in ipairs(fig:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 == rootPart then
			if d.Name == "RootJoint" then return d end
			found = found or d
		end
	end
	return found
end

-- Creates the looping walk/run sounds, the stun and kill sounds, and the vocal with its distortion effect.
local function createSounds()
	for k, file in pairs(SOUND_FILES) do
		local snd = Instance.new("Sound")
		snd.Name    = "MisPrint_" .. k
		snd.SoundId = AssetGetContentId(file)
		snd.Looped  = true
		snd.Volume  = SOUND_VOLUME
		snd.Parent  = rootPart
		sounds[k]   = snd
	end

	stunSound = Instance.new("Sound")
	stunSound.Name    = "MisPrint_stunned"
	stunSound.SoundId = AssetGetContentId("Mis_printStunned.mp3")
	stunSound.Looped  = false
	stunSound.Volume  = STUN_VOLUME
	stunSound.Parent  = rootPart

	killSound = Instance.new("Sound")
	killSound.Name    = "MisPrint_kill"
	killSound.SoundId = AssetGetContentId("Mis_printKill.mp3")
	killSound.Looped  = false
	killSound.Volume  = KILL_VOLUME
	killSound.Parent  = rootPart

	vocal = Instance.new("Sound")
	vocal.Name         = "MisPrint_vocal"
	vocal.SoundId      = AssetGetContentId("Mis_printVocal.mp3")
	vocal.Looped       = true
	vocal.Volume       = VOCAL_VOLUME
	vocal.PlaybackSpeed = VOCAL_MIN_SPEED
	vocal.Parent       = rootPart

	crunch = Instance.new("DistortionSoundEffect")
	crunch.Level  = 0
	crunch.Parent = vocal
end

-- Plays the loop for the current state and stops the other one.
local function setSound(name)
	if soundState == name then return end
	soundState = name
	for k, snd in pairs(sounds) do
		if k == name then
			if not snd.IsPlaying then snd:Play() end
		else
			snd:Stop()
		end
	end
end

local function destroySounds()
	for _, snd in pairs(sounds) do
		snd:Stop()
		snd:Destroy()
	end
	table.clear(sounds)

	if stunSound then
		stunSound:Stop()
		stunSound:Destroy()
		stunSound = nil
	end
	if killSound then
		killSound:Stop()
		killSound:Destroy()
		killSound = nil
	end
	if vocal then
		vocal:Stop()
		vocal:Destroy()
		vocal = nil
	end
	crunch = nil
	vocalOn = false
end

-- Stops the vocal and resets it so the next sprint starts slow.
local function stopVocal()
	vocalOn = false
	vocalP = 0
	if vocal then vocal:Stop() end
	if crunch then crunch.Level = 0 end
end

-- Moves the vocal ramp up while sprinting and down when not. A stun (cut) stops it at once.
local function updateVocal(dt, active, cut)
	if not vocal then return end

	if cut then
		if vocalOn then stopVocal() end
		return
	end

	if active and not vocalOn then
		vocalOn = true
		vocalP = 0
		crunchPhase = 0
		vocal.TimePosition = 0
		vocal.PlaybackSpeed = VOCAL_MIN_SPEED
		vocal:Play()
	end

	if not vocalOn then return end

	if active then
		vocalP = math.min(1, vocalP + dt / VOCAL_RAMP)
	else
		vocalP = math.max(0, vocalP - dt / VOCAL_RAMP_DOWN)
		if vocalP <= 0 then
			stopVocal()
			return
		end
	end

	local p = vocalP
	local e = p * p * (3 - 2 * p)

	vocal.PlaybackSpeed = VOCAL_MIN_SPEED + (1 - VOCAL_MIN_SPEED) * e

	local hz = CRUNCH_HZ_START + (CRUNCH_HZ_END - CRUNCH_HZ_START) * e
	crunchPhase = crunchPhase + dt * hz * math.pi * 2
	local amp = CRUNCH_MAX * (1 - e * e)
	crunch.Level = amp * (0.6 + 0.4 * math.abs(math.sin(crunchPhase)))
end

-- Lights in the workspace, kept up to date by DescendantAdded and DescendantRemoving.
local lights     = {}
local lightConns = {}

local NORMALS = {
	Front  = Vector3.new(0, 0, -1),
	Back   = Vector3.new(0, 0, 1),
	Top    = Vector3.new(0, 1, 0),
	Bottom = Vector3.new(0, -1, 0),
	Right  = Vector3.new(1, 0, 0),
	Left   = Vector3.new(-1, 0, 0),
}

local function trackLight(d)
	if d:IsA("Light") then
		lights[d] = true
	end
end

-- True when the light is on and its range (and cone, for spot and surface lights) touches the hitbox.
-- Parts that block the light are not taken into account.
local function lightReaches(light)
	if not hitbox or not light.Enabled then return false end
	if not (light:IsA("PointLight") or light:IsA("SpotLight") or light:IsA("SurfaceLight")) then return false end
	local part = light.Parent
	if not part or not part:IsA("BasePart") then return false end
	if figureRef and light:IsDescendantOf(figureRef) then return false end

	local origin = part.Position
	local rel  = hitbox.CFrame:PointToObjectSpace(origin)
	local half = hitbox.Size / 2
	local closest = hitbox.CFrame:PointToWorldSpace(Vector3.new(
		math.clamp(rel.X, -half.X, half.X),
		math.clamp(rel.Y, -half.Y, half.Y),
		math.clamp(rel.Z, -half.Z, half.Z)
	))

	local offset = closest - origin
	local dist = offset.Magnitude
	if dist > light.Range then return false end
	if light:IsA("PointLight") or dist < 0.001 then return true end

	local face = NORMALS[light.Face.Name] or NORMALS.Front
	local dir = part.CFrame:VectorToWorldSpace(face)
	return dir:Dot(offset.Unit) >= math.cos(math.rad(light.Angle / 2))
end

-- Collects every brightness value a flash could come from: Lighting, color correction effects,
-- and (when withLights is true) lights that reach the hitbox.
local function flashSources(withLights)
	local out = {}
	out[Lighting] = Lighting.Brightness
	local cam = workspace.CurrentCamera
	for _, holder in ipairs({ Lighting, cam }) do
		if holder then
			for _, c in ipairs(holder:GetChildren()) do
				if c:IsA("ColorCorrectionEffect") then
					out[c] = c.Brightness
				end
			end
		end
	end
	if withLights then
		for light in pairs(lights) do
			if lightReaches(light) then
				out[light] = light.Brightness
			end
		end
	end
	return out
end

-- Compares this frame to the last one. New color effects count as starting from 0 so an instant 1 still triggers.
-- A light that starts reaching the hitbox uses its current value, so walking into a lit area does not stun.
local function checkFlash()
	local cur = flashSources(true)
	local hit = false
	for inst, v in pairs(cur) do
		local last = lastLevels[inst]
		if last == nil then
			last = (inst == Lighting or inst:IsA("Light")) and v or 0
		end
		if v >= FLASH_LEVEL and v - last >= FLASH_JUMP then
			hit = true
		end
	end
	lastLevels = cur
	return hit
end

-- Creates the invisible box that follows the root part.
local function createHitbox(fig)
	hitbox = Instance.new("Part")
	hitbox.Name         = "MisPrint_hitbox"
	hitbox.Size         = HITBOX_SIZE
	hitbox.Anchored     = true
	hitbox.CanCollide   = false
	hitbox.CanTouch     = false
	hitbox.CanQuery     = false
	hitbox.CastShadow   = false
	hitbox.Massless     = true
	hitbox.Transparency = HITBOX_VISIBLE and 0.7 or 1
	hitbox.Color        = Color3.fromRGB(255, 40, 40)
	hitbox.CFrame       = rootPart.CFrame * HITBOX_OFFSET
	hitbox.Parent       = fig

	figureRef = fig
	hitParams = OverlapParams.new()
	hitParams.FilterType = Enum.RaycastFilterType.Exclude
end

-- Moves the hitbox to the root part and returns every part currently inside it.
local function hitboxParts()
	if not hitbox or not rootPart then return {} end
	hitbox.CFrame = rootPart.CFrame * HITBOX_OFFSET

	local ignore = { hitbox }
	if figureRef then table.insert(ignore, figureRef) end
	local plr = Players.LocalPlayer
	if plr and plr.Character then table.insert(ignore, plr.Character) end
	hitParams.FilterDescendantsInstances = ignore

	return workspace:GetPartsInPart(hitbox, hitParams)
end

-- Kills every living humanoid in the hitbox with ReanimateFling. Each target is skipped for KILL_COOLDOWN seconds after.
local function checkKill(parts)
	local now = elapsed
	local hitAny = false
	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		local h = model and model:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 and (not killedAt[model] or now - killedAt[model] >= KILL_COOLDOWN) then
			killedAt[model] = now
			hitAny = true
			if ReanimateFling then
				pcall(ReanimateFling, model, KILL_FLING_TIME)
			end
		end
	end
	return hitAny
end

-- Starts the kill animation and its sound.
local function startKill()
	killing = true
	killTime = 0
	phase.kill = 0
	if killSound then
		killSound.TimePosition = 0
		killSound:Play()
	end
end

-- Ends the kill early, used when a stun interrupts it.
local function cancelKill()
	killing = false
	if killSound then killSound:Stop() end
end

-- Smooths horizontal speed so the character builds up and loses speed gradually.
-- While stunned or killing it stops dead.
local function updateSlide(dt, targetSpeed)
	if not rootPart then return end
	local cur = rootPart.AssemblyLinearVelocity

	if stunned or killing then
		vel = Vector3.zero
		rootPart.AssemblyLinearVelocity = Vector3.new(0, cur.Y, 0)
		return
	end
	if SLIDE <= 0 then
		vel = Vector3.new(cur.X, 0, cur.Z)
		return
	end

	if hum.FloorMaterial == Enum.Material.Air then
		vel = Vector3.new(cur.X, 0, cur.Z)
		return
	end

	local dir = hum.MoveDirection
	local target = Vector3.new(dir.X, 0, dir.Z) * targetSpeed
	vel = vel:Lerp(target, 1 - math.exp(-dt / SLIDE))
	rootPart.AssemblyLinearVelocity = Vector3.new(vel.X, cur.Y, vel.Z)
end

-- Begins the stun: freezes movement (handled in Update) and plays the stun sound.
local function startStun()
	stunned  = true
	stunTime = 0
	phase.stunned = 0
	if stunSound then
		stunSound.TimePosition = 0
		stunSound:Play()
	end
end

-- Stuns Mis Print on demand, same as a flash. Does nothing while already stunned.
local function manualStun()
	if stunned then return end
	startStun()
	cancelKill()
end

-- Touch sprint button, toggled by tapping.
local function makeRunButton()
	local btn = Instance.new("ImageButton")
	btn.Name = RandomString(12)
	btn.AnchorPoint = Vector2.new(0.5, 1)
	btn.BackgroundTransparency = 1
	btn.Image = SPRINT_IMAGE
	btn.Size = UDim2.fromOffset(70, 70)
	btn.Parent = HiddenGui
	return btn
end

-- Touch stun button with a STUN label, same style as the sprint button.
local function makeStunButton()
	local btn = Instance.new("ImageButton")
	btn.Name = RandomString(12)
	btn.AnchorPoint = Vector2.new(0.5, 1)
	btn.BackgroundTransparency = 1
	btn.Image = STUN_IMAGE
	btn.Size = UDim2.fromOffset(70, 70)
	btn.ZIndex = 10
	btn.Parent = HiddenGui

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "STUN"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.ZIndex = 11
	label.Parent = btn
	return btn
end

-- Places the sprint button above the default jump button (or near the bottom right when it is missing)
-- and the stun button to the left of it.
local function layoutButtons()
	if not runButton and not stunButton then return end
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
	local touchGui = pg and pg:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local jumpBtn = frame and frame:FindFirstChild("JumpButton")

	local posX, posY, sizeX, sizeY
	if jumpBtn then
		posX, posY = jumpBtn.AbsolutePosition.X, jumpBtn.AbsolutePosition.Y
		sizeX, sizeY = jumpBtn.AbsoluteSize.X, jumpBtn.AbsoluteSize.Y
	else
		local cam = workspace.CurrentCamera
		if not cam then return end
		local vp = cam.ViewportSize
		local jump = math.min(vp.X, vp.Y) <= 500 and 70 or 120
		sizeX, sizeY = jump, jump
		posX, posY = vp.X - (jump * 1.5 - 10), vp.Y - jump - 20
	end

	local inset = Vector2.zero
	if HiddenGui and HiddenGui:IsA("ScreenGui") and not HiddenGui.IgnoreGuiInset then
		inset = GuiService:GetGuiInset()
	end
	local baseY = posY - sizeY + BUTTON_Y_OFFSET - inset.Y

	if runButton then
		runButton.Size = UDim2.fromOffset(sizeX, sizeY)
		runButton.Position = UDim2.fromOffset(posX + sizeX / 2 - inset.X, baseY)
	end
	if stunButton then
		stunButton.Size = UDim2.fromOffset(sizeX, sizeY)
		stunButton.Position = UDim2.fromOffset(posX - BUTTON_GAP - sizeX / 2 - inset.X, baseY)
		local label = stunButton:FindFirstChild("Label")
		if label then
			label.TextSize = math.max(10, math.floor(sizeX * 0.2))
		end
	end
end

-- Swaps the sprint image while sprint is toggled on and tints the stun button red while stunned.
local function paintButtons()
	if runButton then
		runButton.Image = toggleRun and SPRINT_IMAGE_DOWN or SPRINT_IMAGE
	end
	if stunButton then
		stunButton.ImageColor3 = stunned and Color3.fromRGB(255, 110, 110) or Color3.new(1, 1, 1)
	end
end


-- Sets up sounds, animations, input and the flash baseline for the character.
m.Init = function(figure)
	rootPart  = figure:FindFirstChild("HumanoidRootPart")
	hum       = figure:FindFirstChildOfClass("Humanoid")
	rootJoint = findRootJoint(figure)

	createSounds()
	createHitbox(figure)

	if hum then
		savedSpeed         = hum.WalkSpeed
		originalJumpPower  = hum.JumpPower
		originalJumpHeight = hum.JumpHeight
	end

	anims = {
		idle    = loadAnim(figure, "Mis_printIdle.anim", true),
		walk    = loadAnim(figure, "Mis_printWalk.anim", true),
		run     = loadAnim(figure, "Mis_printRun.anim", true),
		stunned = loadAnim(figure, "Mis_printStunned.anim", false),
		kill    = loadAnim(figure, "Mis_printKill.anim", false),
	}

	phase  = { idle = 0, walk = 0, run = 0, stunned = 0, kill = 0 }
	weight = { idle = 1, walk = 0, run = 0, stunned = 0, kill = 0 }
	scale  = { idle = 1, walk = 1, run = 1, stunned = 1, kill = 1 }
	for k, a in pairs(anims) do
		a.weight = weight[k]
	end

	state      = "idle"
	keyRun     = false
	toggleRun  = false
	running    = false
	stunned    = false
	stunTime   = 0
	liftNow    = LIFT.idle
	soundState = nil
	vel        = Vector3.zero
	killing    = false
	killTime   = 0
	table.clear(killedAt)
	elapsed    = 0
	table.clear(lights)
	for _, d in ipairs(workspace:GetDescendants()) do
		trackLight(d)
	end
	lightConns = {
		workspace.DescendantAdded:Connect(trackLight),
		workspace.DescendantRemoving:Connect(function(d) lights[d] = nil end),
	}
	lastLevels = flashSources(true)

	CAS:BindAction("MisPrintRun", function(_, input)
		keyRun = input == Enum.UserInputState.Begin
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)

	CAS:BindAction("MisPrintStun", function(_, input)
		if input == Enum.UserInputState.Begin then
			manualStun()
		end
	end, false, Enum.KeyCode.F)

	if UserInputService.TouchEnabled then
		runButton = makeRunButton()
		runButton.Activated:Connect(function()
			toggleRun = not toggleRun
		end)
		stunButton = makeStunButton()
		stunButton.Activated:Connect(manualStun)
		layoutButtons()
	end
end


-- Runs every frame: stun check, state, speed, sounds, animation blend, then the floor lift.
m.Update = function(dt, figure)
	if not hum or not hum.Parent or dt <= 0 then return end

	running = keyRun or toggleRun
	if runButton or stunButton then
		layoutButtons()
		paintButtons()
	end

	elapsed = elapsed + dt

	-- Move the hitbox and find what is inside it. checkFlash runs every frame so a flash that stays on does not stun again.
	local parts = hitboxParts()
	local flashed = checkFlash()
	if killing then
		killTime = killTime + dt
		if killTime >= KILL_LENGTH then
			killing = false
		end
	end
	if stunned then
		stunTime = stunTime + dt
		if stunTime >= STUN_LENGTH then
			stunned = false
		end
	elseif flashed then
		startStun()
		cancelKill()
	end

	if not passive and not stunned and not killing and checkKill(parts) then
		startKill()
	end

	local input = hum.MoveDirection.Magnitude > 0.1
	local moving = input or vel.Magnitude > SLIDE_ANIM_MIN

	if stunned then
		state = "stunned"
	elseif killing then
		state = "kill"
	elseif not moving then
		state = "idle"
	elseif running then
		state = "run"
	else
		state = "walk"
	end

	-- Speed is set by state. Jumping is disabled while stunned.
	hum.WalkSpeed = (stunned or killing) and 0 or (TARGET_SPEED[state] or TARGET_SPEED.walk)
	updateSlide(dt, TARGET_SPEED[state] or 0)
	if stunned then
		hum.JumpPower  = 0
		hum.JumpHeight = 0
	else
		if originalJumpPower then hum.JumpPower = originalJumpPower end
		if originalJumpHeight then hum.JumpHeight = originalJumpHeight end
	end

	setSound((state == "walk" or state == "run") and state or nil)
	updateVocal(dt, running, stunned)

	-- Crossfade: the current state fades in and the others drop to 0 once it is fully in.
	local fade = stunned and STUN_FADE or FADE_TIME
	weight[state] = math.min(1, weight[state] + dt / fade)
	if weight[state] >= 1 then
		for k in pairs(weight) do
			if k ~= state then weight[k] = 0 end
		end
	end

	for k in pairs(anims) do
		if weight[k] > 0 then
			phase[k] = phase[k] + dt * scale[k]
		end
	end
	phase.stunned = math.min(phase.stunned, STUN_LENGTH)
	phase.kill = math.min(phase.kill, KILL_LENGTH)

	-- Fading out animations are applied first so the active one is written last and wins.
	for k, a in pairs(anims) do
		if k ~= state and weight[k] > 0 then
			a.weight = 1
			a:Step(phase[k])
		end
	end

	local active = anims[state]
	active.weight = weight[state]
	active:Step(phase[state])

	-- Blend the lift by animation weight and smooth it, then raise the root joint.
	if rootJoint then
		local sum, total = 0, 0
		for k, w in pairs(weight) do
			sum = sum + w * LIFT[k]
			total = total + w
		end
		local target = (total > 0 and sum / total or 0) + EXTRA_LIFT
		liftNow = liftNow + (target - liftNow) * math.min(1, dt * 15)

		local off = CFrame.new(0, liftNow, 0)
		rootJoint.Transform = (rootJoint.C0:Inverse() * off * rootJoint.C0) * rootJoint.Transform
	end
end


-- Removes everything the module created and puts the humanoid back how it was.
m.Destroy = function(figure)
	CAS:UnbindAction("MisPrintRun")
	CAS:UnbindAction("MisPrintStun")
	destroySounds()

	for _, c in ipairs(lightConns) do c:Disconnect() end
	lightConns = {}
	table.clear(lights)

	if hitbox then
		hitbox:Destroy()
		hitbox = nil
	end
	hitParams = nil
	figureRef = nil

	if runButton then
		runButton:Destroy()
		runButton = nil
	end
	if stunButton then
		stunButton:Destroy()
		stunButton = nil
	end

	if hum and hum.Parent then
		hum.WalkSpeed = savedSpeed
		if originalJumpPower then hum.JumpPower = originalJumpPower end
		if originalJumpHeight then hum.JumpHeight = originalJumpHeight end
	end

	table.clear(anims)
	table.clear(phase)
	table.clear(weight)
	table.clear(scale)
	lastLevels = {}

	rootPart   = nil
	rootJoint  = nil
	hum        = nil
	state      = "idle"
	keyRun     = false
	toggleRun  = false
	running    = false
	stunned    = false
	stunTime   = 0
	killing    = false
	killTime   = 0
	vel        = Vector3.zero
	table.clear(killedAt)
	savedSpeed = 16
	soundState = nil
	originalJumpPower  = nil
	originalJumpHeight = nil
end

return m

end)

return modules
