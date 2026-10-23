-- Arthur.lua
-- Created with Moveset Creator V6
-- Place in: UhhhhhhReanim/Modules/Arthur.lua
--
-- Additions in this version:
--   * A revolver model welded to the hand, with muzzle-flash / smoke / spark /
--     shockwave VFX and a slight recoil kick that fires whenever
--     "revolver shoot 1" or "revolver shoot 2" plays.
--   * Revolver + holster mounting now uses attachment-point matching
--     (GripPoint / HolsterPoint on the gun, matched against an attachment on
--     the hand / hip) instead of a single guessed CFrame offset, so the fit
--     stays correct regardless of the rig's own part orientation, and can be
--     nudged visually in Studio by dragging the Attachment gizmos.
--   * A "deadeye" skill: no dedicated .anim, it reuses revolver aim.anim
--     (held for the full duration rather than its own short clip length),
--     plays the Dead Eye sound from the Delta content library, applies a
--     sepia/desaturated screen effect plus an ember aura around Arthur, and
--     slows every other Humanoid in the world to 15% speed for 25 seconds
--     while it's active. While active, it also raycasts from the camera and
--     shows a red "X" mark over any player the revolver is aimed at.
--   * A hip holster prop. A button toggles Draw/Holster: while holstered the
--     revolver-related abilities (reload, aim, shoot 1/2, deadeye) are locked,
--     and drawing puts the revolver back in the hand and re-enables them.

cloneref = cloneref or function(o) return o end

local Debris       = cloneref(game:GetService("Debris"))
local RunService    = cloneref(game:GetService("RunService"))
local Players       = cloneref(game:GetService("Players"))
local Workspace     = cloneref(game:GetService("Workspace"))
local Lighting      = cloneref(game:GetService("Lighting"))
local TweenService  = cloneref(game:GetService("TweenService"))
local UserInputService = cloneref(game:GetService("UserInputService"))

local Player = Players.LocalPlayer

local modules = {}
local function AddModule(m)
    table.insert(modules, m)
end

-- san_lua: convert any string to a valid Lua identifier (no spaces)
-- used only for table keys that are Lua identifiers (mode actions)
local function san_lua(s)
    return (s or ""):gsub("[^%w_]", "_")
end

AddModule(function()
    local m = {}
    m.ModuleType   = "MOVESET"
    m.Name         = "Arthur Morgan"
    m.Description  = "Arthur morgan [WIP}"
    m.InternalName = "Arthur"

    m.Assets = {
        "Arthur idle.anim",
        "arthur walk.anim",
        "Arthur run.anim",
        "RevolverReload.anim",
        "RevolverShot.anim",
        "revolver aim.anim",
        "revolver shoot 2.anim",
    }

    m.FlingEnabled = {
        ["revolver reload "] = false,
        ["revolver reload"] = false,
        ["revolver shoot 1"] = false,
        ["revolver aim"] = false,
        ["revolver shoot 2"] = false,
        ["deadeye"] = false,
    }

    m.Config = function(parent)
        Util_CreateText(parent, "Arthur Morgan", 18, Enum.TextXAlignment.Center)
        Util_CreateSeparator(parent)
    end

    m.SaveConfig = function()
        local t = {}
        return t
    end

    m.LoadConfig = function(save)
    end

    -- ============================================================
    -- CONFIG  (tune these to fit your rig / revolver mesh)
    -- ============================================================
    local REVOLVER_MESH_ID    = "" -- rbxassetid://... leave blank to use the built-in placeholder revolver
    local REVOLVER_TEXTURE_ID = "" -- optional, only used if REVOLVER_MESH_ID is set

    -- Attachment-point based mounting: instead of guessing a single blind
    -- CFrame offset, we align an Attachment on the revolver (built in
    -- buildRevolver, named "GripPoint" / "HolsterPoint") with a matching
    -- Attachment on the hand / hip. This keeps the revolver correctly
    -- positioned & oriented no matter how the hand/hip part's own local axes
    -- are rotated, and lets you nudge the fit visually in Studio by dragging
    -- the Attachment gizmos instead of hand-editing CFrame math.
    local HAND_ATTACHMENT_NAME    = "RevolverGripAttachment"
    local HOLSTER_ATTACHMENT_NAME = "RevolverHolsterAttachment"

    -- Fallback CFrames (local to the hand/hip part) used only if that part
    -- doesn't already have a fitting attachment (R15's built-in
    -- "RightGripAttachment" is preferred automatically when present).
    -- NOTE: the holster offset's Y is POSITIVE (toward the top of
    -- RightUpperLeg, i.e. the belt/hip line) - a negative Y here mounts the
    -- revolver near the knee, which reads as "hoisted at the bottom".
    local HAND_ATTACHMENT_FALLBACK    = CFrame.new(0, -0.9, 0) * CFrame.Angles(math.rad(-90), 0, 0)
    local HOLSTER_ATTACHMENT_FALLBACK = CFrame.new(0.05, 0.5, 0.12) * CFrame.Angles(0, 0, math.rad(180))

    -- Exact filename as it sits in your Delta workspace's Content/Sounds folder
    local DEADEYE_SOUND_FILE = "RDR2 Arthur Dead Eye Sound Effect (High Honor).mp3"

    -- Dead Eye: how long the slow-motion lasts once activated, and how much
    -- slower everything but Arthur moves while it's active (0.15 = 15% speed).
    local DEADEYE_DURATION   = 25
    local DEADEYE_TIME_SCALE = 0.15

    local HOLSTER_KEY = Enum.KeyCode.T
    local DEADEYE_KEY = Enum.KeyCode.Z

    -- STATE
    local baseAnims    = {}
    local actionAnims  = {}
    local animJump     = nil
    local actionStart  = {}
    local currentBase   = "none"
    local currentAction = nil
    local wasInAir      = false
    local flingActive   = false
    local touchConns    = {}
    local allJoints     = {}
    local figureRef     = nil
    local SPEED_WALK    = 16
    local SPEED_SPRINT  = 26
    local isSprinting   = false

    local revolverModel    = nil
    local muzzleAttachment = nil
    local holsterModel     = nil
    local holstered        = false

    local deadeyeActive         = false
    local deadeyeAffected       = {}   -- [Humanoid] = { walkSpeed, jumpPower, tracks = {[track] = origSpeed} }
    local deadeyeDescendantConn = nil
    local deadeyeColorCorr      = nil
    local deadeyeBlur           = nil
    local deadeyeAura           = nil
    local deadeyeMarkGui        = nil  -- BillboardGui with the "X" shown on whoever is being aimed at
    local deadeyeMarkTarget     = nil
    local deadeyeSelectedTarget = nil
    local deadeyeTargetConn     = nil
    local deadeyeInputConn      = nil
    local deadeyeShotsPending   = false
    local shotSequence          = 0

    -- Actions that require the revolver to be drawn
    local REVOLVER_ACTIONS = {
        ["revolver reload "] = true,
        ["revolver shoot 1"] = true,
        ["revolver aim"]     = true,
        ["revolver shoot 2"] = true,
        ["deadeye"]          = true,
    }

    -- Priority used by playAction to decide whether a newly requested action
    -- is allowed to interrupt/restart the one currently playing. Shoot
    -- actions outrank aim/reload/deadeye so firing while aimed (or pressing
    -- shoot again) always plays, instead of being silently swallowed because
    -- currentAction was still set to something else.
    local ACTION_PRIORITY = {
        ["revolver reload "] = 1,
        ["revolver aim"]     = 1,
        ["deadeye"]          = 1,
        ["revolver shoot 1"] = 2,
        ["revolver shoot 2"] = 2,
    }

    -- Source file for each one-shot action anim, keyed the same way as
    -- actionAnims. Used by playAction to rebuild a fresh Animator/Track
    -- every time an action (re)plays - see the comment in playAction for why.
    local ACTION_ANIM_FILES = {
        ["revolver reload "] = "RevolverReload.anim",
        ["revolver shoot 1"] = "RevolverShot.anim",
        ["revolver aim"]     = "revolver aim.anim",
        ["revolver shoot 2"] = "revolver shoot 2.anim",
    }

    -- HELPERS
    local function makeSound(filename, parent, volume, looped)
        local s = Instance.new("Sound")
        s.SoundId = AssetGetContentId(filename)
        s.Volume  = volume or 0.8
        s.Looped  = looped or false
        s.Parent  = parent
        return s
    end

    local function loadAnim(fig, file, looped)
        local a = AnimLib.Animator.new()
        a.rig    = fig
        a.track  = AnimLib.Track.fromfile(AssetGetPathFromFilename(file))
        a.looped = looped or false
        a.speed  = 1
        a.weight = 0
        return a
    end

    local function setSpeed(speed)
        if not figureRef then return end
        local hum = figureRef:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = speed end
    end

    local function clearBase()
        for _, a in pairs(baseAnims) do a.weight = 0 end
    end

    local function setBase(state)
        if currentBase == state then return end
        currentBase = state
        clearBase()
        local a = baseAnims[state]
        if a then
            a.weight = 1
            actionStart[a] = os.clock()
        end
    end

    local function stopAllAnimSounds()
        -- no per-action sounds (deadeye plays its own one-shot sound separately, see playDeadeyeSound)
    end

    local function stopAction()
        for _, anim in pairs(actionAnims) do
            if anim then
                anim.weight = 0
                pcall(function() anim:Step(0) end)
            end
        end

        -- IMPORTANT:
        -- Never leave stale actionStart entries behind. The old implementation
        -- could continue stepping a finished animation object and leave
        -- currentAction/base state out of sync, which is what caused the
        -- occasional freeze / wrong follow-up shot behavior.
        actionStart = {}
        stopAllAnimSounds()
        currentAction = nil
        flingActive   = false
    end

    -- ============================================================
    -- REVOLVER MODEL
    -- Placeholder low-poly geometry. If you have your own revolver mesh,
    -- just set REVOLVER_MESH_ID above and it'll be used instead.
    -- ============================================================
    local function weldRigid(part0, part1)
        local w = Instance.new("WeldConstraint")
        w.Part0  = part0
        w.Part1  = part1
        w.Parent = part1
        return w
    end

    local function newPart(name, size, color, material)
        local p = Instance.new("Part")
        p.Name          = name
        p.Size          = size
        p.Color         = color
        p.Material      = material or Enum.Material.Metal
        p.CanCollide    = false
        p.CanQuery      = false
        p.CastShadow    = false
        p.Massless      = true
        p.Anchored      = false
        p.TopSurface    = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        return p
    end

    local function buildRevolverPlaceholder(model)
        local grip = newPart("Grip", Vector3.new(0.32, 0.85, 0.34), Color3.fromRGB(64, 42, 26), Enum.Material.Wood)
        grip.CFrame = CFrame.new(0, 0, 0)
        grip.Parent = model

        local frame = newPart("Frame", Vector3.new(0.3, 0.34, 1.05), Color3.fromRGB(35, 35, 35))
        frame.CFrame = grip.CFrame * CFrame.new(0, 0.58, -0.05)
        frame.Parent = model

        local cylinder = newPart("Cylinder", Vector3.new(0.46, 0.46, 0.5), Color3.fromRGB(30, 30, 30))
        cylinder.Shape  = Enum.PartType.Cylinder
        cylinder.CFrame = frame.CFrame * CFrame.new(0, 0.02, 0.32) * CFrame.Angles(0, 0, math.rad(90))
        cylinder.Parent = model

        local barrel = newPart("Barrel", Vector3.new(0.18, 0.18, 1.55), Color3.fromRGB(20, 20, 20))
        barrel.CFrame = frame.CFrame * CFrame.new(0, 0.02, -0.55)
        barrel.Parent = model

        local hammer = newPart("Hammer", Vector3.new(0.12, 0.22, 0.12), Color3.fromRGB(45, 45, 45))
        hammer.CFrame = frame.CFrame * CFrame.new(0, 0.22, 0.5)
        hammer.Parent = model

        weldRigid(grip, frame)
        weldRigid(frame, cylinder)
        weldRigid(frame, barrel)
        weldRigid(frame, hammer)

        local muzzle = Instance.new("Attachment")
        muzzle.Name   = "MuzzlePoint"
        muzzle.CFrame = CFrame.new(0, 0, -0.8)
        muzzle.Parent = barrel

        local gripPoint = Instance.new("Attachment")
        gripPoint.Name   = "GripPoint"
        -- sits at the base of the grip; matched against the hand's attachment
        gripPoint.CFrame = CFrame.new(0, -0.35, 0)
        gripPoint.Parent = grip

        local holsterPoint = Instance.new("Attachment")
        holsterPoint.Name   = "HolsterPoint"
        -- rotated so the muzzle points down into the pouch when holstered
        holsterPoint.CFrame = CFrame.new(0, -0.1, 0) * CFrame.Angles(math.rad(-90), 0, 0)
        holsterPoint.Parent = grip

        return grip, muzzle
    end

    local function buildRevolverMesh(model)
        local grip = Instance.new("MeshPart")
        grip.Name       = "Grip"
        grip.MeshId     = REVOLVER_MESH_ID
        if REVOLVER_TEXTURE_ID ~= "" then grip.TextureID = REVOLVER_TEXTURE_ID end
        grip.CanCollide = false
        grip.CanQuery   = false
        grip.CastShadow = false
        grip.Massless   = true
        grip.Anchored   = false
        grip.Parent     = model

        local muzzle = Instance.new("Attachment")
        muzzle.Name   = "MuzzlePoint"
        muzzle.CFrame = CFrame.new(0, 0, -1) -- nudge to match your mesh's barrel tip
        muzzle.Parent = grip

        local gripPoint = Instance.new("Attachment")
        gripPoint.Name   = "GripPoint"
        gripPoint.CFrame = CFrame.new(0, -0.35, 0) -- nudge to match your mesh's handle
        gripPoint.Parent = grip

        local holsterPoint = Instance.new("Attachment")
        holsterPoint.Name   = "HolsterPoint"
        holsterPoint.CFrame = CFrame.new(0, -0.1, 0) * CFrame.Angles(math.rad(-90), 0, 0)
        holsterPoint.Parent = grip

        return grip, muzzle
    end

    local function buildRevolver()
        local model = Instance.new("Model")
        model.Name = "ArthurRevolver"

        local primary, muzzle
        if REVOLVER_MESH_ID ~= "" then
            primary, muzzle = buildRevolverMesh(model)
        else
            primary, muzzle = buildRevolverPlaceholder(model)
        end

        model.PrimaryPart = primary
        return model, muzzle
    end

    local function buildHolster()
        local model = Instance.new("Model")
        model.Name = "ArthurHolster"

        local pouch = newPart("Pouch", Vector3.new(0.4, 0.9, 0.28), Color3.fromRGB(70, 46, 28), Enum.Material.Fabric)
        pouch.Parent = model

        local strap = newPart("Strap", Vector3.new(0.42, 0.15, 0.3), Color3.fromRGB(50, 32, 18), Enum.Material.Fabric)
        strap.CFrame = pouch.CFrame * CFrame.new(0, 0.4, 0)
        strap.Parent = model

        weldRigid(pouch, strap)

        model.PrimaryPart = pouch
        return model
    end

    -- ============================================================
    -- VFX  (muzzle flash for the two shoot actions)
    -- ============================================================
    local function newEmitter(parent, props)
        local e = Instance.new("ParticleEmitter")
        e.Enabled = false
        e.Rate    = 0
        for k, v in pairs(props) do e[k] = v end
        e.Parent = parent
        return e
    end

    local muzzleFlashEmitter, muzzleSmokeEmitter, muzzleSparkEmitter
    local muzzleShockEmitter, muzzleLight, muzzleCoreEmitter
    local muzzleRingEmitter, muzzleTrailEmitter

    local function setupMuzzleVFX(attachment)
        -- Layered muzzle package:
        -- 1) core flame
        -- 2) wide flash burst
        -- 3) hot sparks
        -- 4) expanding shock ring
        -- 5) volumetric smoke
        -- 6) animated point light
        muzzleFlashEmitter = newEmitter(attachment, {
            Texture       = "rbxasset://textures/particles/fire_main.dds",
            Color         = ColorSequence.new(
                Color3.fromRGB(255, 245, 220),
                Color3.fromRGB(255, 150, 45)
            ),
            Size          = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.35),
                NumberSequenceKeypoint.new(0.18, 2.2),
                NumberSequenceKeypoint.new(0.48, 1.25),
                NumberSequenceKeypoint.new(1, 0)
            }),
            Transparency  = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.02),
                NumberSequenceKeypoint.new(0.65, 0.08),
                NumberSequenceKeypoint.new(1, 1)
            }),
            Lifetime      = NumberRange.new(0.055, 0.105),
            Speed         = NumberRange.new(0, 1),
            Rotation      = NumberRange.new(0, 360),
            RotSpeed      = NumberRange.new(-120, 120),
            LightEmission = 1,
            LockedToPart  = true,
        })

        muzzleCoreEmitter = newEmitter(attachment, {
            Texture       = "rbxasset://textures/particles/fire_main.dds",
            Color         = ColorSequence.new(Color3.fromRGB(255, 255, 235)),
            Size          = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.15),
                NumberSequenceKeypoint.new(0.16, 1.0),
                NumberSequenceKeypoint.new(0.45, 0.55),
                NumberSequenceKeypoint.new(1, 0),
            }),
            Transparency  = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Lifetime      = NumberRange.new(0.035, 0.075),
            Speed         = NumberRange.new(5, 12),
            SpreadAngle   = Vector2.new(10, 10),
            LightEmission = 1,
            LockedToPart  = true,
        })

        muzzleSmokeEmitter = newEmitter(attachment, {
            Texture      = "rbxasset://textures/particles/smoke_main.dds",
            Color        = ColorSequence.new(
                Color3.fromRGB(115, 115, 115),
                Color3.fromRGB(65, 65, 65)
            ),
            Size         = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.35),
                NumberSequenceKeypoint.new(0.2, 0.9),
                NumberSequenceKeypoint.new(0.62, 2.4),
                NumberSequenceKeypoint.new(1, 3.6),
            }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.38),
                NumberSequenceKeypoint.new(0.3, 0.58),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Lifetime = NumberRange.new(0.65, 1.2),
            Speed    = NumberRange.new(2, 5),
            Drag     = 2.5,
            SpreadAngle = Vector2.new(20, 20),
            Rotation = NumberRange.new(0, 360),
            RotSpeed = NumberRange.new(-70, 70),
        })

        muzzleSparkEmitter = newEmitter(attachment, {
            Texture       = "rbxasset://textures/particles/sparkles_main.dds",
            Color         = ColorSequence.new(
                Color3.fromRGB(255, 255, 245),
                Color3.fromRGB(255, 170, 55)
            ),
            Size          = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.22),
                NumberSequenceKeypoint.new(0.45, 0.1),
                NumberSequenceKeypoint.new(1, 0)
            }),
            Transparency  = NumberSequence.new(0.08, 1),
            Lifetime      = NumberRange.new(0.12, 0.3),
            Speed         = NumberRange.new(11, 24),
            SpreadAngle   = Vector2.new(20, 20),
            Acceleration  = Vector3.new(0, -55, 0),
            Drag          = 2,
            LightEmission = 1,
        })

        muzzleShockEmitter = newEmitter(attachment, {
            Texture       = "rbxasset://textures/particles/smoke_main.dds",
            Color         = ColorSequence.new(Color3.fromRGB(255, 225, 170)),
            Size          = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.15),
                NumberSequenceKeypoint.new(0.2, 1.5),
                NumberSequenceKeypoint.new(0.65, 3.2),
                NumberSequenceKeypoint.new(1, 4.4),
            }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.18),
                NumberSequenceKeypoint.new(0.25, 0.35),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Lifetime      = NumberRange.new(0.11, 0.18),
            Speed         = NumberRange.new(0, 0.2),
            LightEmission = 0.85,
            LockedToPart  = true,
        })

        muzzleRingEmitter = newEmitter(attachment, {
            Texture       = "rbxasset://textures/particles/ring_main.dds",
            Color         = ColorSequence.new(Color3.fromRGB(255, 210, 125)),
            Size          = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.25),
                NumberSequenceKeypoint.new(0.22, 2.8),
                NumberSequenceKeypoint.new(1, 5.4),
            }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.1),
                NumberSequenceKeypoint.new(0.45, 0.45),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Lifetime      = NumberRange.new(0.08, 0.14),
            Speed         = NumberRange.new(8, 14),
            SpreadAngle   = Vector2.new(0, 0),
            LightEmission = 1,
            LockedToPart  = true,
        })

        muzzleTrailEmitter = newEmitter(attachment, {
            Texture       = "rbxasset://textures/particles/sparkles_main.dds",
            Color         = ColorSequence.new(Color3.fromRGB(255, 220, 150)),
            Size          = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.11),
                NumberSequenceKeypoint.new(0.5, 0.05),
                NumberSequenceKeypoint.new(1, 0)
            }),
            Transparency = NumberSequence.new(0.15, 1),
            Lifetime     = NumberRange.new(0.16, 0.34),
            Speed        = NumberRange.new(22, 38),
            SpreadAngle  = Vector2.new(8, 8),
            LightEmission = 1,
        })

        muzzleLight = Instance.new("PointLight")
        muzzleLight.Color      = Color3.fromRGB(255, 194, 110)
        muzzleLight.Range      = 18
        muzzleLight.Brightness = 0
        muzzleLight.Shadows    = false
        muzzleLight.Parent     = attachment
    end

    local function recoilKick()
        if not revolverModel or not revolverModel.PrimaryPart then return end
        local w = revolverModel.PrimaryPart:FindFirstChild("RevolverMount")
        if not w or not w:IsA("Weld") then return end

        local restC0 = w.C0
        w.C0 = restC0 * CFrame.new(0, 0, 0.11) * CFrame.Angles(math.rad(-10), 0, 0)

        local tween = TweenService:Create(
            w,
            TweenInfo.new(0.13, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            { C0 = restC0 }
        )
        tween:Play()
    end

    local function fireMuzzleFlash()
        if not muzzleAttachment or holstered then return end

        if muzzleFlashEmitter then muzzleFlashEmitter:Emit(10) end
        if muzzleCoreEmitter then muzzleCoreEmitter:Emit(5) end
        if muzzleSmokeEmitter then muzzleSmokeEmitter:Emit(7) end
        if muzzleSparkEmitter then muzzleSparkEmitter:Emit(18) end
        if muzzleShockEmitter then muzzleShockEmitter:Emit(2) end
        if muzzleRingEmitter then muzzleRingEmitter:Emit(2) end
        if muzzleTrailEmitter then muzzleTrailEmitter:Emit(9) end

        if muzzleLight then
            muzzleLight.Brightness = 14
            muzzleLight.Range = 20

            local flashTween = TweenService:Create(
                muzzleLight,
                TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Brightness = 0, Range = 9 }
            )
            flashTween:Play()
        end

        recoilKick()
    end

    -- ============================================================
    -- DEAD EYE
    -- Sound + screen VFX + world slow-motion. No dedicated .anim - it
    -- reuses revolver aim.anim (see actionAnims["deadeye"] below) and holds
    -- that pose for DEADEYE_DURATION seconds instead of the clip's own,
    -- much shorter, length. While active it also raycasts from the camera
    -- each frame and shows a red "X" mark over whichever player is being
    -- aimed at.
    -- ============================================================
    local function playDeadeyeSound()
        if not figureRef then return end
        local parent = figureRef:FindFirstChild("HumanoidRootPart") or figureRef
        local snd = makeSound(DEADEYE_SOUND_FILE, parent, 1, false)
        snd.Ended:Connect(function() snd:Destroy() end)
        snd:Play()
    end

    local function slowTarget(hum)
        if not hum or deadeyeAffected[hum] then return end
        local entry = { walkSpeed = hum.WalkSpeed, jumpPower = hum.JumpPower, tracks = {} }
        hum.WalkSpeed = hum.WalkSpeed * DEADEYE_TIME_SCALE
        hum.JumpPower = hum.JumpPower * DEADEYE_TIME_SCALE
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                entry.tracks[track] = track.Speed
                pcall(function() track:AdjustSpeed(track.Speed * DEADEYE_TIME_SCALE) end)
            end
        end
        deadeyeAffected[hum] = entry
    end

    local function restoreTarget(hum, entry)
        if not hum or not hum.Parent then return end
        hum.WalkSpeed = entry.walkSpeed
        hum.JumpPower = entry.jumpPower
        for track, spd in pairs(entry.tracks) do
            if track then pcall(function() track:AdjustSpeed(spd) end) end
        end
    end

    local function slowEveryoneElse()
        local myHum = figureRef and figureRef:FindFirstChildOfClass("Humanoid")
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("Humanoid") and v ~= myHum then
                slowTarget(v)
            end
        end
    end

    local function restoreEveryone()
        for hum, entry in pairs(deadeyeAffected) do
            restoreTarget(hum, entry)
        end
        table.clear(deadeyeAffected)
    end

    local function onDeadeyeDescendantAdded(inst)
        if not deadeyeActive then return end
        if inst:IsA("Humanoid") then
            local myHum = figureRef and figureRef:FindFirstChildOfClass("Humanoid")
            if inst ~= myHum then
                task.defer(slowTarget, inst)
            end
        end
    end

    local function setupDeadeyeVFX()
        deadeyeColorCorr = Instance.new("ColorCorrectionEffect")
        deadeyeColorCorr.Name       = "DeadeyeColorCorrection"
        deadeyeColorCorr.Enabled    = false
        deadeyeColorCorr.Saturation = 0
        deadeyeColorCorr.Contrast   = 0
        deadeyeColorCorr.Brightness = 0
        deadeyeColorCorr.TintColor  = Color3.fromRGB(255, 200, 140)
        deadeyeColorCorr.Parent     = Lighting

        deadeyeBlur = Instance.new("BlurEffect")
        deadeyeBlur.Name    = "DeadeyeBlur"
        deadeyeBlur.Enabled = false
        deadeyeBlur.Size    = 0
        deadeyeBlur.Parent  = Lighting

        local hrp = figureRef and (figureRef:FindFirstChild("HumanoidRootPart")
            or figureRef:FindFirstChild("UpperTorso") or figureRef:FindFirstChild("Torso"))
        if hrp then
            deadeyeAura = newEmitter(hrp, {
                Texture       = "rbxasset://textures/particles/sparkles_main.dds",
                Color         = ColorSequence.new(Color3.fromRGB(255, 170, 90)),
                Size          = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.25),
                    NumberSequenceKeypoint.new(1, 0),
                }),
                Transparency  = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.2),
                    NumberSequenceKeypoint.new(1, 1),
                }),
                Lifetime      = NumberRange.new(0.6, 1),
                Speed         = NumberRange.new(1, 2),
                SpreadAngle   = Vector2.new(180, 180),
                Rate          = 10,
                LightEmission = 1,
            })
        end
    end

    local function playDeadeyeVFX(on)
        if deadeyeColorCorr then
            deadeyeColorCorr.Enabled = true
            local tween = TweenService:Create(deadeyeColorCorr, TweenInfo.new(0.35), {
                Saturation = on and -0.75 or 0,
                Contrast   = on and 0.15 or 0,
                Brightness = on and 0.05 or 0,
            })
            tween:Play()
            if not on then
                tween.Completed:Connect(function()
                    if deadeyeColorCorr and not deadeyeActive then deadeyeColorCorr.Enabled = false end
                end)
            end
        end
        if deadeyeBlur then
            deadeyeBlur.Enabled = true
            local tween = TweenService:Create(deadeyeBlur, TweenInfo.new(0.35), { Size = on and 6 or 0 })
            tween:Play()
            if not on then
                tween.Completed:Connect(function()
                    if deadeyeBlur and not deadeyeActive then deadeyeBlur.Enabled = false end
                end)
            end
        end
        if deadeyeAura then deadeyeAura.Enabled = on end
    end

    local function createDeadeyeMarkGui()
        local gui = Instance.new("BillboardGui")
        gui.Name           = "DeadeyeMark"
        gui.Size           = UDim2.new(0, 42, 0, 42)
        gui.StudsOffset    = Vector3.new(0, 1, 0)
        gui.AlwaysOnTop    = true
        gui.LightInfluence = 0
        gui.Adornee        = nil

        local x = Instance.new("TextLabel")
        x.Name                   = "X"
        x.BackgroundTransparency = 1
        x.Size                   = UDim2.new(1, 0, 1, 0)
        x.Font                   = Enum.Font.GothamBlack
        x.TextScaled             = true
        x.TextColor3             = Color3.fromRGB(255, 45, 30)
        x.TextStrokeTransparency = 0
        x.TextStrokeColor3       = Color3.fromRGB(20, 0, 0)
        x.Text                   = "X"
        x.Parent                 = gui

        return gui
    end

    local function clearDeadeyeMark()
        if deadeyeMarkGui then
            deadeyeMarkGui.Adornee = nil
            deadeyeMarkGui.Parent  = nil
        end
        deadeyeMarkTarget = nil
    end

    local function updateDeadeyeTarget()
        if not deadeyeActive or not figureRef then
            clearDeadeyeMark()
            return
        end

        -- Mobile-selected target stays locked until it dies/gets replaced.
        if deadeyeSelectedTarget and deadeyeSelectedTarget.Parent
            and deadeyeSelectedTarget.Health > 0 then

            local char = deadeyeSelectedTarget.Parent
            local head = char:FindFirstChild("Head") or char.PrimaryPart
            if head then
                markDeadeyeTarget(deadeyeSelectedTarget, head)
                return
            end
        end

        -- Desktop/controller fallback: camera ray.
        local camera = Workspace.CurrentCamera
        if not camera then return end

        local myHum = figureRef:FindFirstChildOfClass("Humanoid")
        local origin = camera.CFrame.Position
        local dir = camera.CFrame.LookVector * 400

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { figureRef }

        local result = Workspace:Raycast(origin, dir, params)
        if result and result.Instance then
            local targetHum, targetHead = resolveHumanoidFromInstance(result.Instance)
            if targetHum and targetHead and targetHum ~= myHum then
                markDeadeyeTarget(targetHum, targetHead)
                return
            end
        end

        clearDeadeyeMark()
    end

    local function endDeadeye()
        if not deadeyeActive then return end
        deadeyeActive = false
        if deadeyeDescendantConn then
            deadeyeDescendantConn:Disconnect()
            deadeyeDescendantConn = nil
        end
        restoreEveryone()
        playDeadeyeVFX(false)
        clearSelectedTarget()
        if deadeyeInputConn then
            deadeyeInputConn:Disconnect()
            deadeyeInputConn = nil
        end
        if currentAction == "deadeye" then
            stopAction()
            currentBase = "none"
        end
    end

    -- ============================================================
    -- HOLSTER / DRAW
    -- ============================================================
    local function findHandPart(figure)
        return figure:FindFirstChild("RightHand") or figure:FindFirstChild("Right Arm")
    end

    local function findHipPart(figure)
        return figure:FindFirstChild("RightUpperLeg") or figure:FindFirstChild("Right Leg")
            or figure:FindFirstChild("LowerTorso") or figure:FindFirstChild("Torso")
    end

    local function getOrCreateAttachment(part, name, fallbackCFrame)
        if not part then return nil end
        local att = part:FindFirstChild(name)
        if not att and name == HAND_ATTACHMENT_NAME then
            -- R15 rigs already ship a correctly-placed grip attachment on the hand
            att = part:FindFirstChild("RightGripAttachment")
        end
        if not att then
            att = Instance.new("Attachment")
            att.Name   = name
            att.CFrame = fallbackCFrame
            att.Parent = part
        end
        return att
    end

    local function attachRevolverTo(part, mountAttachmentName, fallbackCFrame, revolverAttachmentName)
        if not revolverModel or not revolverModel.PrimaryPart then return end
        -- Fall back to a part that's always present on the rig so mounting
        -- still succeeds (and holstered/drawn state stays in sync) even if
        -- the expected hand/hip part can't be found - i.e. holstering still
        -- works even when the revolver isn't currently being held anywhere.
        part = part or (figureRef and (figureRef:FindFirstChild("HumanoidRootPart")
            or figureRef:FindFirstChild("Torso"))) or figureRef
        if not part then return end
        local old = revolverModel.PrimaryPart:FindFirstChild("RevolverMount")
        if old then old:Destroy() end

        local mountAttachment = getOrCreateAttachment(part, mountAttachmentName, fallbackCFrame)
        local gunAttachment    = revolverModel.PrimaryPart:FindFirstChild(revolverAttachmentName)

        local w = Instance.new("Weld")
        w.Name  = "RevolverMount"
        w.Part0 = part
        w.Part1 = revolverModel.PrimaryPart
        if mountAttachment and gunAttachment then
            -- align the two attachments exactly, regardless of either part's
            -- own local axis orientation
            w.C0 = mountAttachment.CFrame
            w.C1 = gunAttachment.CFrame
        else
            w.C0 = fallbackCFrame
            w.C1 = CFrame.new()
        end
        w.Parent = revolverModel.PrimaryPart
    end

    local function drawRevolver()
        if not figureRef then return end
        local hand = findHandPart(figureRef)
        attachRevolverTo(hand, HAND_ATTACHMENT_NAME, HAND_ATTACHMENT_FALLBACK, "GripPoint")
        holstered = false
        ContextActions:SetTitle("GM_Holster", "Holster")
    end

    local function holsterRevolver()
        if not figureRef then return end
        local hip = findHipPart(figureRef)
        attachRevolverTo(hip, HOLSTER_ATTACHMENT_NAME, HOLSTER_ATTACHMENT_FALLBACK, "HolsterPoint")
        holstered = true
        if deadeyeActive then endDeadeye() end
        if currentAction then
            stopAction()
        end
        ContextActions:SetTitle("GM_Holster", "Draw")
    end

    local function toggleHolster()
        if holstered then
            drawRevolver()
        else
            holsterRevolver()
        end
    end

    -- ACTIONS
    local function playAction(name)
        if REVOLVER_ACTIONS[name] and holstered then return end
        if name == "deadeye" and deadeyeActive then return end

        if currentAction then
            local curPriority = ACTION_PRIORITY[currentAction] or 0
            local newPriority = ACTION_PRIORITY[name] or 0
            if newPriority < curPriority then return end
        end

        -- Every one-shot receives a genuinely new AnimLib Animator/Track.
        -- This avoids re-entering a track whose internal end state has already
        -- been reached.
        local file = ACTION_ANIM_FILES[name]
        if file and figureRef then
            local old = actionAnims[name]
            if old then
                old.weight = 0
                actionStart[old] = nil
            end

            actionAnims[name] = loadAnim(figureRef, file, false)

            if name == "revolver aim" then
                -- Dead Eye uses a separate reference to the fresh aim object.
                actionAnims["deadeye"] = actionAnims["revolver aim"]
            end
        end

        local a = actionAnims[name]
        if not a then return end

        -- Hard reset all previous action state before arming the new action.
        for _, anim in pairs(actionAnims) do
            if anim and anim ~= a then anim.weight = 0 end
        end
        actionStart = {}

        a.weight = 1
        actionStart[a] = os.clock()
        currentAction = name
        flingActive = m.FlingEnabled[name] == true

        if name == "revolver shoot 1" or name == "revolver shoot 2" then
            shotSequence += 1
            fireMuzzleFlash()
        end
    end

    local function playDeadeye()
        if holstered or deadeyeActive then return end
        playAction("deadeye")
        if currentAction ~= "deadeye" then return end

        deadeyeActive = true
        -- The aim pose is held for the full DEADEYE_DURATION (instead of the
        -- clip's own short length) because currentAction == "deadeye" is
        -- exempt from the clip-length auto-stop check in m.Update, and it is
        -- cleanly stopped by stopAction() inside endDeadeye() below - so we
        -- never mark it looped, which would otherwise replay the short clip
        -- endlessly for the whole duration instead of just holding the pose.

        playDeadeyeSound()
        playDeadeyeVFX(true)
        slowEveryoneElse()
        setupDeadeyeMobileInput()
        deadeyeDescendantConn = Workspace.DescendantAdded:Connect(onDeadeyeDescendantAdded)

        task.delay(DEADEYE_DURATION, endDeadeye)
    end

    local function toggleSprint()
        isSprinting = not isSprinting
        if isSprinting then
            setSpeed(SPEED_SPRINT)
            ContextActions:SetTitle("GM_Sprint", "Walk")
        else
            setSpeed(SPEED_WALK)
            ContextActions:SetTitle("GM_Sprint", "Sprint")
        end
    end

    local function setupFlingTouched(figure)
        local function hookPart(part)
            local conn = part.Touched:Connect(function(hit)
                if not flingActive then return end
                if not hit or not hit.Parent then return end
                local target = hit.Parent
                if target:IsA("Accessory") then target = target.Parent end
                if target == figure then return end
                if not target:FindFirstChildOfClass("Humanoid") then return end
                ReanimateFling(target)
            end)
            table.insert(touchConns, conn)
        end
        for _, part in ipairs(figure:GetDescendants()) do
            if part:IsA("BasePart") then hookPart(part) end
        end
        table.insert(touchConns, figure.DescendantAdded:Connect(function(part)
            if part:IsA("BasePart") then hookPart(part) end
        end))
    end

    -- INIT
    m.Init = function(figure)
        figureRef = figure
        local hrp = figure:FindFirstChild("HumanoidRootPart") or figure
        local hum = figure:FindFirstChildOfClass("Humanoid")

        allJoints = {}
        for _, v in ipairs(figure:GetDescendants()) do
            if v:IsA("Motor6D") then table.insert(allJoints, v) end
        end

        baseAnims = {
            idle = loadAnim(figure, "Arthur idle.anim", true),
            walk = loadAnim(figure, "arthur walk.anim", true),
            sprint = loadAnim(figure, "Arthur run.anim", true),
        }
        animJump = baseAnims.jump

        actionAnims = {
            ["revolver reload "] = loadAnim(figure, "RevolverReload.anim", false),
            ["revolver shoot 1"] = loadAnim(figure, "RevolverShot.anim", false),
            ["revolver aim"] = loadAnim(figure, "revolver aim.anim", false),
            ["revolver shoot 2"] = loadAnim(figure, "revolver shoot 2.anim", false),
        }
        -- Dead Eye has no .anim of its own - it just reuses "revolver aim"
        actionAnims["deadeye"] = actionAnims["revolver aim"]

        setSpeed(SPEED_WALK)
        setBase("idle")
        setupFlingTouched(figure)

        -- build & equip the revolver + holster prop
        revolverModel, muzzleAttachment = buildRevolver()
        revolverModel.Parent = figure
        setupMuzzleVFX(muzzleAttachment)
        drawRevolver()

        holsterModel = buildHolster()
        holsterModel.Parent = figure
        local hip = findHipPart(figure)
        if hip and holsterModel.PrimaryPart then
            local hipAttachment = getOrCreateAttachment(hip, HOLSTER_ATTACHMENT_NAME, HOLSTER_ATTACHMENT_FALLBACK)
            local w = Instance.new("Weld")
            w.Name   = "HolsterMount"
            w.Part0  = hip
            w.Part1  = holsterModel.PrimaryPart
            w.C0     = hipAttachment.CFrame
            w.Parent = holsterModel.PrimaryPart
        end

        setupDeadeyeVFX()

        ContextActions:BindAction("GM_Sprint", function(_, inputState, _)
            if inputState == Enum.UserInputState.Begin then toggleSprint() end
        end, true, Enum.KeyCode.LeftAlt)
        ContextActions:SetTitle("GM_Sprint", "Sprint")
        ContextActions:SetPosition("GM_Sprint", UDim2.new(1, -70, 1, -130))

        ContextActions:BindAction("GM_revolver_reload_", function(_, inputState, _)
            if inputState == Enum.UserInputState.Begin then playAction("revolver reload ") end
        end, true, Enum.KeyCode.R)
        ContextActions:SetTitle("GM_revolver_reload_", "revolver reload ")
        ContextActions:SetPosition("GM_revolver_reload_", UDim2.new(1, -140, 1, -130))

        ContextActions:BindAction("GM_revolver_shoot_1", function(_, inputState, _)
            if inputState == Enum.UserInputState.Begin then playAction("revolver shoot 1") end
        end, true, Enum.KeyCode.E)
        ContextActions:SetTitle("GM_revolver_shoot_1", "revolver shoot 1")
        ContextActions:SetPosition("GM_revolver_shoot_1", UDim2.new(1, -210, 1, -130))

        ContextActions:BindAction("GM_revolver_aim", function(_, inputState, _)
            if inputState == Enum.UserInputState.Begin then playAction("revolver aim") end
        end, true, Enum.KeyCode.Q)
        ContextActions:SetTitle("GM_revolver_aim", "revolver aim")
        ContextActions:SetPosition("GM_revolver_aim", UDim2.new(1, -280, 1, -130))

        ContextActions:BindAction("GM_revolver_shoot_2", function(_, inputState, _)
            if inputState == Enum.UserInputState.Begin then playAction("revolver shoot 2") end
        end, true, Enum.KeyCode.F)
        ContextActions:SetTitle("GM_revolver_shoot_2", "revolver shoot 2")
        ContextActions:SetPosition("GM_revolver_shoot_2", UDim2.new(1, -350, 1, -130))

        ContextActions:BindAction("GM_Deadeye", function(_, inputState, _)
            if inputState == Enum.UserInputState.Begin then playDeadeye() end
        end, true, DEADEYE_KEY)
        ContextActions:SetTitle("GM_Deadeye", "Dead Eye")
        ContextActions:SetPosition("GM_Deadeye", UDim2.new(1, -420, 1, -130))

        ContextActions:BindAction("GM_Holster", function(_, inputState, _)
            if inputState == Enum.UserInputState.Begin then toggleHolster() end
        end, true, HOLSTER_KEY)
        ContextActions:SetTitle("GM_Holster", "Holster")
        ContextActions:SetPosition("GM_Holster", UDim2.new(1, -490, 1, -130))
    end

    -- UPDATE
    m.Update = function(dt, figure)
        local hum = figure:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local inAir = hum.FloorMaterial == Enum.Material.Air

        -- Auto-stop finished actions. Use the animation elapsed-time
        -- watchdog as the authoritative fallback instead of depending on
        -- wrapper-specific Length/Time behavior.
        if currentAction and currentAction ~= "deadeye" then
            local a = actionAnims[currentAction]
            local started = a and actionStart[a]

            if a and started then
                local elapsed = os.clock() - started
                local duration = 1.15

                if a.track then
                    local ok, length = pcall(function()
                        return tonumber(a.track.Length) or 0
                    end)
                    if ok and length and length > 0.05 then
                        duration = math.max(0.08, math.min(length, 3.0))
                    end
                end

                if elapsed >= (duration / math.max(0.05, a.speed or 1)) then
                    a.weight = 0
                    actionStart[a] = nil
                    stopAllAnimSounds()
                    currentAction = nil
                    flingActive = false
                    currentBase = "none"
                end
            end
        end

        -- locomotion state machine
        if not currentAction then
            if inAir then
                if not wasInAir then
                    clearBase()
                    currentBase = "jump"
                    if animJump then
                        animJump.weight = 1
                        actionStart[animJump] = os.clock()
                    end
                end
            else
                if wasInAir and animJump then animJump.weight = 0 end
                local moving = hum.MoveDirection.Magnitude > 0.1
                if moving then
                    if isSprinting then setBase("sprint") else setBase("walk") end
                else
                    setBase("idle")
                end
            end
        end

        wasInAir = inAir
        updateDeadeyeTarget()

        local now = os.clock()
        for a, start in pairs(actionStart) do
            if a and a.weight > 0 then a:Step(now - start) end
        end
    end

    -- DESTROY
    m.Destroy = function(figure)
        ContextActions:UnbindAction("GM_Sprint")
        ContextActions:UnbindAction("GM_revolver_reload_")
        ContextActions:UnbindAction("GM_revolver_shoot_1")
        ContextActions:UnbindAction("GM_revolver_aim")
        ContextActions:UnbindAction("GM_revolver_shoot_2")
        ContextActions:UnbindAction("GM_Deadeye")
        ContextActions:UnbindAction("GM_Holster")

        for _, conn in ipairs(touchConns) do conn:Disconnect() end
        table.clear(touchConns)

        endDeadeye()
        if deadeyeColorCorr then deadeyeColorCorr:Destroy() end
        if deadeyeBlur then deadeyeBlur:Destroy() end
        if deadeyeAura then deadeyeAura:Destroy() end
        if deadeyeMarkGui then deadeyeMarkGui:Destroy() end
        if deadeyeInputConn then deadeyeInputConn:Disconnect() end
        if deadeyeTargetConn then deadeyeTargetConn:Disconnect() end
        deadeyeColorCorr  = nil
        deadeyeBlur       = nil
        deadeyeAura       = nil
        deadeyeMarkGui    = nil
        deadeyeMarkTarget = nil
        deadeyeSelectedTarget = nil
        deadeyeInputConn = nil
        deadeyeTargetConn = nil
        deadeyeAffected   = {}

        stopAllAnimSounds()

        for _, joint in ipairs(allJoints) do
            if joint and joint.Parent then joint.Transform = CFrame.identity end
        end
        allJoints = {}

        for _, a in pairs(baseAnims)   do a.weight = 0 end
        for _, a in pairs(actionAnims) do a.weight = 0 end

        if revolverModel then revolverModel:Destroy() end
        if holsterModel then holsterModel:Destroy() end
        revolverModel      = nil
        holsterModel       = nil
        muzzleAttachment    = nil
        muzzleFlashEmitter = nil
        muzzleSmokeEmitter = nil
        muzzleSparkEmitter = nil
        muzzleShockEmitter = nil
        muzzleLight        = nil
        muzzleCoreEmitter  = nil
        muzzleRingEmitter  = nil
        muzzleTrailEmitter = nil
        holstered          = false

        setSpeed(16)
        actionStart   = {}
        currentAction = nil
        currentBase   = "idle"
        wasInAir      = false
        flingActive   = false
        figureRef     = nil
        animJump      = nil
        baseAnims     = {}
        actionAnims   = {}
        isSprinting   = false
    end

    return m
end)

return modules