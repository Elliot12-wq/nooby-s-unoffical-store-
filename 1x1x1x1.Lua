local modules = {}

table.insert(modules, function()

	local m = {}
	m.ModuleType = "MOVESET"
	m.Name = "1x1x1x1"
	m.Description = "The physical manifestation of pure malice, hatred, and negativity himself; the one who despises no one else more than the former admin, Shedletsky\n\nprobably something to updated that one outdated 1x1x1x1 moveset\n\nmade by Berry"
	m.InternalName = "1x1x1x1"

	m.Assets = {
		"1xIdle.anim",
		"1xWalk.anim",
		"1xRun.anim",
		"1xM1.anim",
		"1xMass.anim",
		"1xKill.anim",
		"1xIntro.anim",
		"1xShedKill.anim",
		"1xStunStart.anim",
		"1xStunLoop.anim",
		"1xStunEnd.anim",
		"1xVictim.anim",
		"1xKillMinion.anim",
		"1xShedVictim.anim",
		"1xEntangle.anim",
		"1xRotten.anim",
		"1xEye.anim",
		"1xMinionIdle.anim",
		"1xMinionRun.anim",
		"1xMinionAttack.anim",
		"1xMinionSpawn.anim",
		"1xMinionWalk.anim",
		"1XM1.mp3",
		"1XCHASE.mp3",
		"1XKILL.mp3",
		"1xIntro.mp3",
		"1xOutro.mp3",
		"1XSHEDKILL.mp3",
		"1XSTUNSTART.mp3",
		"1XSTUNEND.mp3",
		"1XMASS.mp3",
		"1XENTANGLE.mp3",
		"1XROTTEN.mp3",
		"1XIDLEVOICE.mp3",
		"1XEYE.mp3",
	}

	m.Config = function(parent) end

	local Players    = game:GetService("Players")
	local Debris     = game:GetService("Debris")
	local UIS        = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")
	local Player     = Players.LocalPlayer

	local animator      = nil
	local tracks        = {}
	local currentTrack  = nil
	local animationTime = 0
	local lastState     = "none"
	local usingSkill    = false
	local isSprinting   = false

	local flingActive   = false
	local touchConns    = {}
	local figureRef     = nil
	local activeVictims = {}

	local isM1Active    = false
	local m1AnimTime    = 0
	local lowerAnimator = nil
	local lowerMuted    = false

	local observeConn   = nil
	local inObserveLoop = false
	local observeTarget = nil

	local voidActive = false
	local voidHit    = false

	local activeMinions = {}

	local minionBench   = {}
	local BENCH_SIZE    = 3
	local BENCH_PARK_Y  = -9999
	local usedFriendIds = {}

	local MASS_SLOW_SPEED     = 2.5
	local ENTANGLE_SLOW_SPEED = 1.5
	local EYE_SLOW_SPEED      = 3.0

	local legSnapSkills       = false
	local eyeActive           = false
	local skillSnapAnimTime   = 0

	local LEG_JOINTS = { ["Left Hip"] = true, ["Right Hip"] = true }

	local function stepSkillMotor6D(figure, dt, locoState)
		if not lowerAnimator then return end

		local locoTrack
		if locoState == "run" then
			locoTrack = eyeActive and tracks.idle or tracks.run
		elseif locoState == "walk" then
			locoTrack = tracks.walk
		else
			locoTrack = tracks.idle
		end

		if lowerAnimator.track ~= locoTrack then
			lowerAnimator.track  = locoTrack
			lowerAnimator.looped = true
		end

		skillSnapAnimTime      = skillSnapAnimTime + dt
		lowerAnimator.looped   = true
		lowerAnimator:Step(skillSnapAnimTime)

		local legSnapshot = {}
		for _, motor in ipairs(figure:GetDescendants()) do
			if motor:IsA("Motor6D") and LEG_JOINTS[motor.Name] then
				legSnapshot[motor] = motor.Transform
			end
		end

		animator.looped = true
		animator:Step(animationTime)

		for motor, cf in pairs(legSnapshot) do
			motor.Transform = cf
		end
	end

	local function playSound(id, parent)
		local s = Instance.new("Sound")
		s.SoundId = AssetGetContentId(id)
		s.Volume  = 1.5
		s.Parent  = parent
		s:Play()
		Debris:AddItem(s, 8)
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

	local function setupFlingTouched(figure)
		local function hookPart(part)
			local conn = part.Touched:Connect(function(hit)
				if not hit or not hit.Parent then return end
				local target = hit.Parent
				if target:IsA("Accessory") then target = target.Parent end
				if target == figure then return end
				if not target:FindFirstChildOfClass("Humanoid") then return end
				if voidActive then voidHit = true end
				if flingActive then ReanimateFling(target) end
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

	local function getRandomPlayer()
		local valid = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
				table.insert(valid, p)
			end
		end
		if #valid > 0 then return valid[math.random(1, #valid)] end
		return nil
	end

	local function spawnVictimNPC(offsetCFrame, animName, duration)
		if not figureRef then return end
		task.spawn(function()
			local targetPlayer = getRandomPlayer()
			local dummy
			if targetPlayer and targetPlayer.Character then
				pcall(function()
					targetPlayer.Character.Archivable = true
					dummy = targetPlayer.Character:Clone()
					targetPlayer.Character.Archivable = false
				end)
			end
			if not dummy then
				pcall(function()
					figureRef.Archivable = true
					dummy = figureRef:Clone()
					figureRef.Archivable = false
				end)
			end
			if not dummy then
				dummy = Players:CreateHumanoidModelFromDescription(
					Instance.new("HumanoidDescription"),
					Enum.HumanoidRigType.R6
				)
			end
			if not dummy then return end
			dummy.Name   = "Meowified"
			dummy.Parent = workspace
			for _, v in ipairs(dummy:GetDescendants()) do
				if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("Sound")
				or v:IsA("ScreenGui") or v:IsA("BillboardGui") or v:IsA("SurfaceGui") then
					v:Destroy()
				elseif v:IsA("BasePart") then
					v.Massless   = true
					v.CanCollide = false
					v.CanTouch   = false
					v.CanQuery   = false
					v.Anchored   = (v.Name == "HumanoidRootPart")
				end
			end
			local root   = dummy:FindFirstChild("HumanoidRootPart") or dummy:FindFirstChild("Torso")
			local myRoot = figureRef:FindFirstChild("HumanoidRootPart") or figureRef:FindFirstChild("Torso")
			if root and myRoot then
				if dummy:IsA("Model") then
					dummy.PrimaryPart = root
					dummy:PivotTo(myRoot.CFrame * offsetCFrame)
				else
					root.CFrame = myRoot.CFrame * offsetCFrame
				end
			end
			local ok, dAnim = pcall(function() return loadAnim(dummy, animName, false) end)
			if ok and dAnim then
				dAnim.weight = 1
				table.insert(activeVictims, { anim = dAnim, dummy = dummy, start = os.clock() })
			end
			Debris:AddItem(dummy, duration + 0.3)
		end)
	end

	local function clearObserve()
		inObserveLoop = false
		observeTarget = nil
		if observeConn then
			observeConn:Disconnect()
			observeConn = nil
		end
	end

	local MINION_CHASE_RADIUS    = 30
	local MINION_CHASE_SPEED     = 8
	local MINION_WANDER_SPEED    = 4
	local MINION_ATTACK_RANGE    = 4
	local MINION_ATTACK_ANIM_DUR = 0.5
	local MINION_ATTACK_COOLDOWN = 1.75
	local MINION_WANDER_RANGE    = 20
	local MINION_WANDER_COOLDOWN = 2.0

	local MINION_SPAWN_OFFSETS = {
		CFrame.new(-4, 0, 0),
		CFrame.new( 4, 0, 0),
		CFrame.new( 0, 0, 4),
	}

	local function getClosestPlayerInRadius(minionRoot, radius)
		local bestDist   = math.huge
		local bestTarget = nil
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= Player and p.Character then
				local pRoot = p.Character:FindFirstChild("HumanoidRootPart")
				if pRoot then
					local dist = (pRoot.Position - minionRoot.Position).Magnitude
					if dist < radius and dist < bestDist then
						bestDist   = dist
						bestTarget = p
					end
				end
			end
		end
		return bestTarget, bestDist
	end

	local function minionSetAnim(minionData, animKey, looped)
		if minionData.currentAnimKey == animKey then return end
		minionData.currentAnimKey  = animKey
		minionData.animator.track  = minionData.tracks[animKey]
		minionData.animator.looped = looped
		minionData.animTime        = 0
	end

	local function pickWanderTarget(minionRoot)
		local base  = minionRoot.Position
		local angle = math.random() * math.pi * 2
		local dist  = math.random(5, MINION_WANDER_RANGE)
		return Vector3.new(base.X + math.cos(angle) * dist, base.Y, base.Z + math.sin(angle) * dist)
	end

	local function moveMinionToward(minionRoot, targetPos, speed, dt)
		local dir = Vector3.new((targetPos - minionRoot.Position).X, 0, (targetPos - minionRoot.Position).Z)
		local mag = dir.Magnitude
		if mag < 0.5 then return true end
		local step = dir.Unit * speed * dt
		if step.Magnitude > mag then step = dir end
		minionRoot.CFrame = CFrame.new(minionRoot.Position + step, minionRoot.Position + dir.Unit)
		return false
	end

	local function runMinionAI(minionData, dt)
		local root = minionData.model:FindFirstChild("HumanoidRootPart")
		if not root or not minionData.model.Parent then return false end
		local now = os.clock()
		minionData.animTime = minionData.animTime + dt
		minionData.animator:Step(minionData.animTime)

		if minionData.currentAnimKey == "attack" and not minionData.attackAnimDone then
			local elapsed = now - minionData.attackAnimStart
			if elapsed >= MINION_ATTACK_ANIM_DUR then
				minionData.attackAnimDone = true
				minionData.onCooldown     = true
				minionData.lastAttackTime = now
			else
				return true
			end
		end
		if minionData.onCooldown then
			minionSetAnim(minionData, "idle", true)
			if now - minionData.lastAttackTime >= MINION_ATTACK_COOLDOWN then
				minionData.onCooldown        = false
				minionData.attackAnimDone    = false
				minionData.wanderTarget      = nil
				minionData.wanderArrivalTime = nil
			end
			return true
		end
		local target, dist = getClosestPlayerInRadius(root, MINION_CHASE_RADIUS)
		if target then
			local pRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
			if not pRoot then return true end
			if dist <= MINION_ATTACK_RANGE then
				if minionData.currentAnimKey ~= "attack" then
					minionSetAnim(minionData, "attack", false)
					minionData.attackAnimStart = now
					minionData.attackAnimDone  = false
					ReanimateFling(target.Character)
				end
			else
				minionSetAnim(minionData, "run", true)
				moveMinionToward(root, pRoot.Position, MINION_CHASE_SPEED, dt)
			end
		else
			if minionData.wanderArrivalTime then
				minionSetAnim(minionData, "idle", true)
				if now - minionData.wanderArrivalTime >= MINION_WANDER_COOLDOWN then
					minionData.wanderArrivalTime = nil
					minionData.wanderTarget      = nil
				end
				return true
			end
			minionSetAnim(minionData, "walk", true)
			if not minionData.wanderTarget then
				minionData.wanderTarget = pickWanderTarget(root)
			end
			local reached = moveMinionToward(root, minionData.wanderTarget, MINION_WANDER_SPEED, dt)
			if reached then
				minionData.wanderTarget      = nil
				minionData.wanderArrivalTime = now
			end
		end
		return true
	end

	local function fetchFreshAppearances(count)
		local function tryFetch(allowUsed)
			local friendIds = {}
			pcall(function()
				local pages = Players:GetFriendsAsync(Player.UserId)
				while true do
					for _, info in ipairs(pages:GetCurrentPage()) do
						if allowUsed or not usedFriendIds[tostring(info.Id)] then
							table.insert(friendIds, info.Id)
						end
						if #friendIds >= count * 4 then break end
					end
					if pages.IsFinished or #friendIds >= count * 4 then break end
					pages:AdvanceToNextPageAsync()
				end
			end)
			for i = #friendIds, 2, -1 do
				local j = math.random(1, i)
				friendIds[i], friendIds[j] = friendIds[j], friendIds[i]
			end
			local appearances = {}
			for _, uid in ipairs(friendIds) do
				if #appearances >= count then break end
				local desc
				pcall(function() desc = Players:GetHumanoidDescriptionFromUserId(uid) end)
				if desc then
					table.insert(appearances, { desc = desc, uid = tostring(uid) })
				end
			end
			if #appearances < count then
				for _, p in ipairs(Players:GetPlayers()) do
					if #appearances >= count then break end
					if p ~= Player and (allowUsed or not usedFriendIds[tostring(p.UserId)]) then
						local desc
						pcall(function() desc = Players:GetHumanoidDescriptionFromUserId(p.UserId) end)
						if desc then
							table.insert(appearances, { desc = desc, uid = tostring(p.UserId) })
						end
					end
				end
			end
			return appearances
		end

		local appearances = tryFetch(false)
		if #appearances < count then
			usedFriendIds = {}
			appearances   = tryFetch(true)
		end
		while #appearances < count do
			table.insert(appearances, { desc = Instance.new("HumanoidDescription"), uid = nil })
		end
		return appearances
	end

	local function buildBenchedModel(humanoidDesc)
		local dummy
		if humanoidDesc then
			pcall(function()
				dummy = Players:CreateHumanoidModelFromDescription(humanoidDesc, Enum.HumanoidRigType.R6)
			end)
		end
		if not dummy and figureRef then
			pcall(function()
				figureRef.Archivable = true
				dummy = figureRef:Clone()
				figureRef.Archivable = false
			end)
		end
		if not dummy then return nil end

		dummy.Name   = "HATE"
		dummy.Parent = workspace

		for _, v in ipairs(dummy:GetDescendants()) do
			if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("Sound")
			or v:IsA("ScreenGui") or v:IsA("BillboardGui") or v:IsA("SurfaceGui") then
				v:Destroy()
			elseif v:IsA("BasePart") then
				v.Massless   = true
				v.CanCollide = false
				v.CanTouch   = true
				v.CanQuery   = true
				v.Anchored   = false
			end
		end

		local dRoot = dummy:FindFirstChild("HumanoidRootPart") or dummy:FindFirstChild("Torso")
		if dRoot then
			if dummy:IsA("Model") then dummy.PrimaryPart = dRoot end
			dRoot.CFrame   = CFrame.new(0, BENCH_PARK_Y, 0)
			dRoot.Anchored = true
		end

		local minionTracks = {
			idle   = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xMinionIdle.anim")),
			walk   = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xMinionWalk.anim")),
			run    = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xMinionRun.anim")),
			attack = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xMinionAttack.anim")),
		}

		local minionAnim = AnimLib.Animator.new()
		minionAnim.rig    = dummy
		minionAnim.track  = minionTracks.idle
		minionAnim.looped = true
		minionAnim.speed  = 1
		minionAnim.weight = 1

		return {
			model    = dummy,
			tracks   = minionTracks,
			animator = minionAnim,
		}
	end

	local benchBuilding = false
	local function refillBench()
		if benchBuilding then return end
		benchBuilding = true
		task.spawn(function()
			local needed = BENCH_SIZE - #minionBench
			if needed <= 0 then benchBuilding = false return end
			local appearances = fetchFreshAppearances(needed)
			for _, entry in ipairs(appearances) do
				local benched = buildBenchedModel(entry.desc)
				if benched then
					benched.friendUid = entry.uid
					table.insert(minionBench, benched)
				end
				task.wait()
			end
			benchBuilding = false
		end)
	end

	local function spawnOneMinion(offsetIndex)
		if not figureRef then return end
		local offset = MINION_SPAWN_OFFSETS[offsetIndex]
		if not offset then return end

		local benched = table.remove(minionBench, 1)
		if not benched then
			local fresh = fetchFreshAppearances(1)
			benched = buildBenchedModel(fresh[1].desc)
			if not benched then return end
			benched.friendUid = fresh[1].uid
		end

		if benched.friendUid then
			usedFriendIds[benched.friendUid] = true
		end

		local model  = benched.model
		local myRoot = figureRef:FindFirstChild("HumanoidRootPart") or figureRef:FindFirstChild("Torso")
		local dRoot  = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
		if myRoot and dRoot then
			if model:IsA("Model") then
				model:PivotTo(myRoot.CFrame * offset)
			else
				dRoot.CFrame = myRoot.CFrame * offset
			end
		end

		local spawnAnim = loadAnim(model, "1xMinionSpawn.anim", false)
		spawnAnim.weight = 1

		local minionData = {
			model             = model,
			animator          = benched.animator,
			tracks            = benched.tracks,
			currentAnimKey    = "idle",
			animTime          = 0,
			wanderTarget      = nil,
			wanderArrivalTime = nil,
			onCooldown        = false,
			lastAttackTime    = 0,
			attackAnimStart   = 0,
			attackAnimDone    = false,
			spawnAnim         = spawnAnim,
			spawnStart        = os.clock(),
			spawnDone         = false,
		}

		table.insert(activeMinions, minionData)
		Debris:AddItem(model, 300)
	end

	local function destroyAllMinions()
		for _, md in ipairs(activeMinions) do
			if md.model and md.model.Parent then md.model:Destroy() end
		end
		activeMinions = {}
		for _, b in ipairs(minionBench) do
			if b.model and b.model.Parent then b.model:Destroy() end
		end
		minionBench = {}
	end

	m.Init = function(figure)
		figureRef = figure
		local hum  = figure:FindFirstChildOfClass("Humanoid")
		local root = figure:FindFirstChild("HumanoidRootPart")
		if not hum or not root then return end

		animator        = AnimLib.Animator.new()
		animator.rig    = figure
		animator.looped = true

		tracks.idle         = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xIdle.anim"))
		tracks.walk         = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xWalk.anim"))
		tracks.run          = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xRun.anim"))
		tracks.m1           = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xM1.anim"))
		tracks.hateMass     = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xMass.anim"))
		tracks.kill         = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xKill.anim"))
		tracks.intro        = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xIntro.anim"))
		tracks.outro        = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xOutro.anim"))
		tracks.shedKill     = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xShedKill.anim"))
		tracks.stunnedStart = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xStunStart.anim"))
		tracks.stunnedLoop  = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xStunLoop.anim"))
		tracks.stunnedEnd   = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xStunEnd.anim"))
		tracks.hateEntangle = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xEntangle.anim"))
		tracks.hateRotten   = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xRotten.anim"))
		tracks.hateEye      = AnimLib.Track.fromfile(AssetGetPathFromFilename("1xEye.anim"))

		currentTrack   = tracks.idle
		animator.track = currentTrack

		lowerAnimator        = AnimLib.Animator.new()
		lowerAnimator.rig    = figure
		lowerAnimator.looped = true
		lowerAnimator.track  = tracks.idle
		lowerAnimator.weight = 0

		task.defer(function()
			if lowerAnimator then
				lowerAnimator.weight = 1
			end
		end)

		skillSnapAnimTime = 0

		SetOverrideMovesetMusic(AssetGetContentId("1XCHASE.mp3"), "I, OF THE STORM", 1)
		setupFlingTouched(figure)

		refillBench()

		ContextActions:BindAction("hatred_m1", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill or isM1Active then return end
			isM1Active   = true
			flingActive  = true
			m1AnimTime   = 0
			playSound("1XM1.mp3", root)
			currentTrack   = tracks.m1
			animator.track = currentTrack
			task.spawn(function()
				task.wait(0.95)
				flingActive = false
				isM1Active  = false
				lastState   = "none"
			end)
		end, true, Enum.UserInputType.MouseButton1)

		ContextActions:BindAction("hatred_mass", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill      = true
			eyeActive      = true
			hum.WalkSpeed   = MASS_SLOW_SPEED
			hum.JumpPower   = 0
			playSound("1XMASS.mp3", root)
			currentTrack    = tracks.hateMass
			animator.track  = currentTrack
			animator.looped = false
			animationTime   = 0
			task.wait(2.7667)
			usingSkill      = false
			eyeActive     = false
			animator.looped = true
			hum.WalkSpeed   = 8
			hum.JumpPower   = 50
			lastState       = "none"
			animationTime   = 0
		end, true, Enum.KeyCode.E)

		ContextActions:BindAction("hatred_kill", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill     = true
			lowerMuted     = true
			hum.WalkSpeed  = 0
			hum.JumpPower  = 0
			playSound("1XKILL.mp3", root)
			currentTrack   = tracks.kill
			animator.track = currentTrack
			animationTime  = 0
			spawnVictimNPC(CFrame.new(0,0,0), "1xVictim.anim", 2.1)
			task.wait(2.1)
			usingSkill    = false
			lowerMuted    = false
			hum.WalkSpeed = 8
			hum.JumpPower = 50
			lastState     = "none"
		end, true, Enum.KeyCode.Z)

		ContextActions:BindAction("hatred_intro", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill     = true
			lowerMuted     = true
			hum.WalkSpeed  = 0
			hum.JumpPower  = 0
			playSound("1xIntro.mp3", root)
			currentTrack   = tracks.intro
			animator.track = currentTrack
			animationTime  = 0
			task.wait(3.3333)
			usingSkill    = false
			lowerMuted    = false
			hum.WalkSpeed = 8
			hum.JumpPower = 50
			lastState     = "none"
		end, true, Enum.KeyCode.One)

		ContextActions:BindAction("hatred_outro", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill     = true
			lowerMuted     = true
			hum.WalkSpeed  = 0
			hum.JumpPower  = 0
			playSound("1xOutro.mp3", root)
			currentTrack   = tracks.outro
			animator.track = currentTrack
			animationTime  = 0
			spawnVictimNPC(CFrame.new(0,0,0), "1xOutroVictim.anim", 8.5667)
			task.wait(8.5667)
			usingSkill    = false
			lowerMuted    = false
			hum.WalkSpeed = 8
			hum.JumpPower = 50
			lastState     = "none"
		end, true, Enum.KeyCode.P)

		ContextActions:BindAction("hatred_shed_kill", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill     = true
			lowerMuted     = true
			hum.WalkSpeed  = 0
			hum.JumpPower  = 0
			playSound("1XSHEDKILL.mp3", root)
			currentTrack   = tracks.shedKill
			animator.track = currentTrack
			animationTime  = 0
			spawnVictimNPC(CFrame.new(0,0,0), "1xShedVictim.anim", 4.2667)
			task.wait(4.2667)
			usingSkill    = false
			lowerMuted    = false
			hum.WalkSpeed = 8
			hum.JumpPower = 50
			lastState     = "none"
		end, true, Enum.KeyCode.Two)

		ContextActions:BindAction("hatred_stun", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill     = true
			lowerMuted     = true
			hum.WalkSpeed  = 0
			hum.JumpPower  = 0
			playSound("1XSTUNSTART.mp3", root)
			currentTrack   = tracks.stunnedStart
			animator.track = currentTrack
			animationTime  = 0
			task.wait(2.4833)
			currentTrack   = tracks.stunnedLoop
			animator.track = currentTrack
			animationTime  = 0
			task.wait(2.6667)
			playSound("1XSTUNEND.mp3", root)
			currentTrack   = tracks.stunnedEnd
			animator.track = currentTrack
			animationTime  = 0
			task.wait(0.8359)
			usingSkill    = false
			lowerMuted    = false
			hum.WalkSpeed = 8
			hum.JumpPower = 50
			lastState     = "none"
		end, true, Enum.KeyCode.Three)

		ContextActions:BindAction("hatred_entanglement", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill      = true
			eyeActive      = true
			hum.WalkSpeed   = ENTANGLE_SLOW_SPEED
			hum.JumpPower   = 0
			playSound("1XENTANGLE.mp3", root)
			currentTrack    = tracks.hateEntangle
			animator.track  = currentTrack
			animator.looped = false
			animationTime   = 0
			task.wait(1.4333)
			usingSkill      = false
			eyeActive     = false
			animator.looped = true
			hum.WalkSpeed   = 8
			hum.JumpPower   = 50
			lastState       = "none"
			animationTime   = 0
		end, true, Enum.KeyCode.R)

		ContextActions:BindAction("hatred_rotten", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill     = true
			lowerMuted     = true
			hum.WalkSpeed  = 0
			hum.JumpPower  = 0
			playSound("1XROTTEN.mp3", root)
			currentTrack   = tracks.hateRotten
			animator.track = currentTrack
			animationTime  = 0

			destroyAllMinions()

			task.delay(2.05, function()
				if usingSkill then spawnOneMinion(1) end
			end)
			task.delay(2.15, function()
				if usingSkill then spawnOneMinion(2) end
			end)
			task.delay(2.25, function()
				if usingSkill then
					spawnOneMinion(3)
					refillBench()
				end
			end)

			task.wait(3.5167)
			usingSkill    = false
			lowerMuted    = false
			hum.WalkSpeed = 8
			hum.JumpPower = 50
			lastState     = "none"
		end, true, Enum.KeyCode.Q)

		ContextActions:BindAction("hatred_eye", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill     = true
			eyeActive      = true
			hum.WalkSpeed  = EYE_SLOW_SPEED
			hum.JumpPower  = 0
			playSound("1XEYE.mp3", root)
			currentTrack   = tracks.hateEye
			animator.track = currentTrack
			animationTime  = 0
			task.wait(1.6167)
			usingSkill    = false
			eyeActive     = false
			hum.WalkSpeed = 8
			hum.JumpPower = 50
			lastState     = "none"
		end, true, Enum.KeyCode.T)

		ContextActions:BindAction("hatred_sprint", function(_, state)
			if state == Enum.UserInputState.Begin then
				isSprinting = not isSprinting
				ContextActions:SetTitle("hatred_sprint", isSprinting and "Walk" or "Sprint")
			end
		end, true, Enum.KeyCode.LeftShift)

		ContextActions:SetTitle("hatred_m1",           "M1")
		ContextActions:SetTitle("hatred_mass",          "Mass")
		ContextActions:SetTitle("hatred_kill",          "Kill")
		ContextActions:SetTitle("hatred_intro",         "Intro")
		ContextActions:SetTitle("hatred_outro",         "Outro")
		ContextActions:SetTitle("hatred_shed_kill",     "Shed Kill")
		ContextActions:SetTitle("hatred_stun",          "Stun")
		ContextActions:SetTitle("hatred_entanglement",  "Entangle")
		ContextActions:SetTitle("hatred_rotten",        "Rejuvenate")
		ContextActions:SetTitle("hatred_eye",           "Unstable Eye")
		ContextActions:SetTitle("hatred_sprint",        "Sprint")

		ContextActions:SetPosition("hatred_m1",           UDim2.new(1, -70,  1, -70))
		ContextActions:SetPosition("hatred_mass",         UDim2.new(1, -140, 1, -70))
		ContextActions:SetPosition("hatred_kill",         UDim2.new(1, -210, 1, -70))
		ContextActions:SetPosition("hatred_intro",        UDim2.new(1, -280, 1, -70))
		ContextActions:SetPosition("hatred_sprint",       UDim2.new(1, -350, 1, -70))
		ContextActions:SetPosition("hatred_shed_kill",    UDim2.new(1, -70,  1, -150))
		ContextActions:SetPosition("hatred_stun",         UDim2.new(1, -140, 1, -150))
		ContextActions:SetPosition("hatred_entanglement", UDim2.new(1, -210, 1, -150))
		ContextActions:SetPosition("hatred_rotten",       UDim2.new(1, -280, 1, -150))
		ContextActions:SetPosition("hatred_eye",          UDim2.new(1, -350, 1, -150))
		ContextActions:SetPosition("hatred_outro",        UDim2.new(1, -70, 1, -230))
	end

	m.Update = function(dt, figure)
		if not animator then return end
		local hum  = figure:FindFirstChildOfClass("Humanoid")
		local root = figure:FindFirstChild("HumanoidRootPart")
		if not hum then return end

		local now = os.clock()
		for i = #activeVictims, 1, -1 do
			local data = activeVictims[i]
			if data.dummy and data.dummy.Parent then
				data.anim:Step(now - data.start)
			else
				table.remove(activeVictims, i)
			end
		end

		for i = #activeMinions, 1, -1 do
			local md = activeMinions[i]
			if not md.model or not md.model.Parent then
				table.remove(activeMinions, i)
			else
				if not md.spawnDone then
					local elapsed = now - md.spawnStart
					md.spawnAnim:Step(elapsed)
					if elapsed >= 1.8333 then md.spawnDone = true end
				else
					runMinionAI(md, dt)
				end
			end
		end

		local locoState = "idle"
		if not usingSkill then
			if hum.MoveDirection.Magnitude > 0.1 then
				locoState = isSprinting and "run" or "walk"
			end

			if lastState ~= locoState then
				animationTime = 0
				lastState     = locoState
			end

			local newTrack
			if locoState == "idle" then
				newTrack      = tracks.idle
				hum.WalkSpeed = 8
			elseif locoState == "walk" then
				newTrack      = tracks.walk
				hum.WalkSpeed = 8
			elseif locoState == "run" then
				newTrack      = tracks.run
				hum.WalkSpeed = 27.5
			end

			if lowerAnimator and newTrack and lowerAnimator.track ~= newTrack then
				lowerAnimator.track  = newTrack
				lowerAnimator.looped = true
			end

			if not isM1Active then
				if currentTrack ~= newTrack then
					currentTrack   = newTrack
					animator.track = currentTrack
				end
			end
		end

		animationTime += dt

		if isM1Active then
			if lowerAnimator and not lowerMuted then
				lowerAnimator.looped = true
				lowerAnimator:Step(animationTime)

				local legSnapshot = {}
				for _, motor in ipairs(figure:GetDescendants()) do
					if motor:IsA("Motor6D") and LEG_JOINTS[motor.Name] then
						legSnapshot[motor] = motor.Transform
					end
				end

				m1AnimTime += dt
				animator.looped = false
				animator:Step(m1AnimTime)

				for motor, cf in pairs(legSnapshot) do
					motor.Transform = cf
				end
			else
				m1AnimTime += dt
				animator.looped = false
				animator:Step(m1AnimTime)
			end

		elseif usingSkill then
			if lowerAnimator and not lowerMuted then
				stepSkillMotor6D(figure, dt, locoState)
			else
				animator:Step(animationTime)
			end

		elseif legSnapSkills then
			if lowerAnimator then
				lowerAnimator.track  = tracks.idle
				lowerAnimator.looped = true
				lowerAnimator:Step(animationTime)

				local legSnapshot = {}
				for _, motor in ipairs(figure:GetDescendants()) do
					if motor:IsA("Motor6D") and LEG_JOINTS[motor.Name] then
						legSnapshot[motor] = motor.Transform
					end
				end

				animator.looped = false
				animator:Step(animationTime)

				for motor, cf in pairs(legSnapshot) do
					motor.Transform = cf
				end
			else
				animator.looped = false
				animator:Step(animationTime)
			end

		else
			animator.looped = true
			animator:Step(animationTime)
			if lowerAnimator and not lowerMuted then
				lowerAnimator.looped = true
				lowerAnimator:Step(animationTime)
			end
		end
	end

	m.Destroy = function()
		clearObserve()
		destroyAllMinions()
		voidActive        = false
		voidHit           = false
		isSprinting       = false
		lowerMuted        = false
		eyeActive         = false
		skillSnapAnimTime = 0
		for _, conn in ipairs(touchConns) do conn:Disconnect() end
		table.clear(touchConns)
		for _, data in ipairs(activeVictims) do
			if data.dummy then data.dummy:Destroy() end
		end
		activeVictims = {}
		usedFriendIds = {}
		ContextActions:UnbindAction("hatred_m1")
		ContextActions:UnbindAction("hatred_mass")
		ContextActions:UnbindAction("hatred_kill")
		ContextActions:UnbindAction("hatred_intro")
		ContextActions:UnbindAction("hatred_outro")
		ContextActions:UnbindAction("hatred_shed_kill")
		ContextActions:UnbindAction("hatred_stun")
		ContextActions:UnbindAction("hatred_entanglement")
		ContextActions:UnbindAction("hatred_rotten")
		ContextActions:UnbindAction("hatred_eye")
		ContextActions:UnbindAction("hatred_sprint")
		isM1Active    = false
		m1AnimTime    = 0
		lowerAnimator = nil
		animator      = nil
		tracks        = {}
		currentTrack  = nil
		figureRef     = nil
		flingActive   = false
		usingSkill    = false
		legSnapSkills = false
	end

	return m
end)

return modules
