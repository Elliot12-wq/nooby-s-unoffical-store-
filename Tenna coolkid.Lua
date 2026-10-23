local modules = {}
table.insert(modules, function()
	local m = {}
	m.ModuleType = "MOVESET"
	m.Name = "Tenna coolkid"
	m.Description = "coming straight from your house!\n\ntwo people has this, Nooby and tuan anh. OF COURSE you can't exclude Berry!!\n\nMade by Berry, Suggested moveset"
	m.InternalName = "Tenna"
	m.Assets = {
		"TvCoolIdle.anim",
		"TvCoolWalk.anim",
		"TvCoolRun.anim",
		"TvCoolM1.anim",
		"TvCoolCorrupt.anim",
		"TvCoolKill.anim",
		"TvCoolVictim.anim",
		"TvCoolStunStart.anim",
		"TvCoolStunLoop.anim",
		"TvCoolStunEnd.anim",
		"TvCoolDelivery.anim",
		"TvCoolWalkspeedStart.anim",
		"TvCoolWalkspeedLoop.anim",
		"TvCoolWalkspeedHit.anim",
		"TvCoolWalkspeedEnd.anim",
		"TvCoolMinionSpawn.anim",
		"TvCoolMinionIdle.anim",
		"TvCoolMinionHit.anim",
		"TvCoolMinionWalk.anim",
		"TvCoolIntro.anim",
		"TvCoolOutro.anim",

		"Coming straight from your house.mp3",
		"TvCoolM1.mp3",
		"TvCoolKill.mp3",
		"TvCoolKillVoice.mp3",
		"TvCoolKillVoice2.mp3",
		"TvCoolKillVoice3.mp3",
		"TvCoolCorrupt.mp3",
		"TvCoolRandomVoice.mp3",
		"TvCoolRandomVoice2.mp3",
		"TvCoolRandomVoice3.mp3",
		"TvCoolRandomVoice4.mp3",
		"TvCoolRandomVoice5.mp3",
		"TvCoolIdleVoice.mp3",
		"TvCoolIntro.mp3",
		"TvCoolOutro.mp3",
		"TvCoolWalkspeedStart.mp3",
      "TvCoolWalkspeedLoop.mp3",
		"TvCoolWalkspeedHit.mp3",
		"TvCoolWalkspeedHitVoice.mp3",
		"TvCoolWalkspeedEnd.mp3",
		"TvCoolkidMinionSpawn.mp3",
	}
	m.Config = function(parent) end

	local Players    = game:GetService("Players")
	local Debris     = game:GetService("Debris")
	local UIS        = game:GetService("UserInputService")
	local Player     = Players.LocalPlayer
	local animator   = nil
	local tracks     = {}
	local currentTrack  = nil
	local animationTime = 0
	local lastState     = "none"
	local usingSkill    = false
	local isSprinting   = false
	local flingActive   = false
	local touchConns    = {}
	local figureRef     = nil
	local activeVictims = {}
	local lastIdleVoice = 0

	local isM1Active    = false
	local m1AnimTime    = 0
	local lowerAnimator = nil
	local voidActive    = false
	local voidHit       = false
	local activeMinions = {}
	local cachedMinionAppearances = {}
	local appearancesCached = false

	local activeVoiceSound = nil
	local outroActive      = false
	local outroConnection  = nil

	local killVoiceSfx = {
		"TvCoolKillVoice.mp3",
		"TvCoolKillVoice2.mp3",
		"TvCoolKillVoice3.mp3",
	}
	local randomVoiceSfx = {
		"TvCoolRandomVoice.mp3",
		"TvCoolRandomVoice2.mp3",
		"TvCoolRandomVoice3.mp3",
		"TvCoolRandomVoice4.mp3",
		"TvCoolRandomVoice5.mp3",
	}
	local idleVoiceSfx = {
		"TvCoolIdleVoice.mp3",
	}

	local function playSound(id, parent)
		local s = Instance.new("Sound")
		s.SoundId = AssetGetContentId(id)
		s.Volume  = 1.5
		s.Parent  = parent
		s:Play()
		Debris:AddItem(s, 8)
		return s
	end
	local function playVoice(id, parent)
		if activeVoiceSound and activeVoiceSound.Parent then
			activeVoiceSound:Stop()
			activeVoiceSound:Destroy()
		end
		local s = Instance.new("Sound")
		s.SoundId = AssetGetContentId(id)
		s.Volume  = 1.5
		s.Parent  = parent
		s:Play()
		activeVoiceSound = s
		Debris:AddItem(s, 8)
		return s
	end
	local function playRandomVoice(tbl, parent)
		return playVoice(tbl[math.random(1, #tbl)], parent)
	end
	local function loadAnim(fig, file, looped)
		local a     = AnimLib.Animator.new()
		a.rig       = fig
		a.track     = AnimLib.Track.fromfile(AssetGetPathFromFilename(file))
		a.looped    = looped or false
		a.speed     = 1
		a.weight    = 0
		return a
	end
	local function setupFlingTouched(figure)
		local function hookPart(part)
			local conn = part.Touched:Connect(function(hit)
				if not hit or not hit.Parent then return end
				local target = hit.Parent
				if target:IsA("Accessory") then target = target.Parent end
				if target == figure then return end
				if target == Player.Character then return end
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
			local hDesc_ok = pcall(function()
				local hum = dummy:FindFirstChildOfClass("Humanoid")
				if hum and hum.RigType == Enum.HumanoidRigType.R15 then
					local desc = hum:GetAppliedDescription()
					dummy:Destroy()
					dummy = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
				end
			end)
			if not dummy then return end
			dummy.Name   = "TvVictim"
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
				dummy.PrimaryPart = root
				dummy:PivotTo(myRoot.CFrame * offsetCFrame)
			end
			local ok, dAnim = pcall(function() return loadAnim(dummy, animName, false) end)
			if ok and dAnim then
				dAnim.weight = 1
				table.insert(activeVictims, { anim = dAnim, dummy = dummy, start = os.clock() })
			end
			Debris:AddItem(dummy, duration + 0.3)
		end)
	end
	local function prefetchMinionAppearances(count)
		local appearances = {}
		local friendIds = {}
		pcall(function()
			local pages = Players:GetFriendsAsync(Player.UserId)
			while true do
				for _, info in ipairs(pages:GetCurrentPage()) do
					table.insert(friendIds, info.Id)
					if #friendIds >= count * 3 then break end
				end
				if pages.IsFinished or #friendIds >= count * 3 then break end
				pages:AdvanceToNextPageAsync()
			end
		end)
		for i = #friendIds, 2, -1 do
			local j = math.random(1, i)
			friendIds[i], friendIds[j] = friendIds[j], friendIds[i]
		end
		for _, uid in ipairs(friendIds) do
			if #appearances >= count then break end
			local desc
			pcall(function() desc = Players:GetHumanoidDescriptionFromUserId(uid) end)
			if desc then table.insert(appearances, desc) end
		end
		if #appearances < count then
			for _, p in ipairs(Players:GetPlayers()) do
				if #appearances >= count then break end
				if p ~= Player then
					local desc
					pcall(function() desc = Players:GetHumanoidDescriptionFromUserId(p.UserId) end)
					if desc then table.insert(appearances, desc) end
				end
			end
		end
		while #appearances < count do
			table.insert(appearances, Instance.new("HumanoidDescription"))
		end
		return appearances
	end
	local function buildMinionModel(offsetCFrame, humanoidDesc)
		if not figureRef then return nil end
		local dummy
		if humanoidDesc then
			pcall(function()
				dummy = Players:CreateHumanoidModelFromDescription(humanoidDesc, Enum.HumanoidRigType.R6)
			end)
		end
		if not dummy then
			pcall(function()
				figureRef.Archivable = true
				dummy = figureRef:Clone()
				figureRef.Archivable = false
			end)
		end
		if not dummy then return nil end
		dummy.Name   = "TvSquad"
		dummy.Parent = workspace
		for _, v in ipairs(dummy:GetDescendants()) do
			if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("Sound")
			or v:IsA("ScreenGui") or v:IsA("BillboardGui") or v:IsA("SurfaceGui") then
				v:Destroy()
			elseif v:IsA("BasePart") then
				v.Massless   = false
				v.CanCollide = true
				v.CanTouch   = true
				v.CanQuery   = true
				v.Anchored   = false
			end
		end
		local myRoot = figureRef:FindFirstChild("HumanoidRootPart") or figureRef:FindFirstChild("Torso")
		local dRoot  = dummy:FindFirstChild("HumanoidRootPart") or dummy:FindFirstChild("Torso")
		if myRoot and dRoot then
			dummy.PrimaryPart = dRoot
			dummy:PivotTo(myRoot.CFrame * offsetCFrame)
		end
		if dRoot then dRoot.Anchored = true end
		return dummy
	end
	local function getClosestPlayer(minionRoot)
		local bestDist   = math.huge
		local bestTarget = nil
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= Player and p.Character then
				local pRoot = p.Character:FindFirstChild("HumanoidRootPart")
				if pRoot then
					local dist = (pRoot.Position - minionRoot.Position).Magnitude
					if dist < bestDist then
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
	local function moveMinionToward(minionRoot, targetPos, speed, dt)
		local dir = (targetPos - minionRoot.Position)
		dir = Vector3.new(dir.X, 0, dir.Z)
		local mag = dir.Magnitude
		if mag < 0.5 then return true end
		local step = dir.Unit * speed * dt
		if step.Magnitude > mag then step = dir end
		minionRoot.CFrame = CFrame.new(minionRoot.Position + step, minionRoot.Position + dir.Unit)
		return false
	end
	local function runCoolkidMinionAI(md, dt)
		local root = md.model:FindFirstChild("HumanoidRootPart")
		if not root or not md.model.Parent then return false end
		local now = os.clock()
		md.animTime = md.animTime + dt
		md.animator:Step(md.animTime)
		if md.isFading then
			md.fadeElapsed = md.fadeElapsed + dt
			local alpha = math.clamp(1 - (md.fadeElapsed / 1.0), 0, 1)
			for _, part in ipairs(md.model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 1 - alpha
				elseif part:IsA("Decal") or part:IsA("Texture") then
					part.Transparency = 1 - alpha
				end
			end
			if md.fadeElapsed >= 1.0 then
				md.model:Destroy()
				return false
			end
			return true
		end
		if md.isAttacking then
			local elapsed = now - md.attackStart
			if elapsed >= 0.6667 then
				md.isAttacking = false
				md.isFading    = true
				md.fadeElapsed = 0
			end
			return true
		end
		local target, dist = getClosestPlayer(root)
		if target and target.Character then
			local pRoot = target.Character:FindFirstChild("HumanoidRootPart")
			if pRoot then
				if dist <= 4 then
					minionSetAnim(md, "attack", false)
					md.isAttacking = true
					md.attackStart = now
					ReanimateFling(target.Character)
				else
					minionSetAnim(md, "walk", true)
					moveMinionToward(root, pRoot.Position, 8, dt)
				end
			end
		else
			minionSetAnim(md, "idle", true)
		end
		return true
	end
	local function spawnTvMinion(side, humanoidDesc)
		if not figureRef then return end
		local offset = (side == "left") and CFrame.new(-4, 0, 0) or CFrame.new(4, 0, 0)
		local model  = buildMinionModel(offset, humanoidDesc)
		if not model then return end
		local dRoot = model:FindFirstChild("HumanoidRootPart")
		local spawnAnim = loadAnim(model, "TvCoolMinionSpawn.anim", false)
		spawnAnim.weight = 1
		local minionTracks = {
			idle   = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolMinionIdle.anim")),
			walk   = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolMinionWalk.anim")),
			attack = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolMinionHit.anim")),
		}
		local minionAnim        = AnimLib.Animator.new()
		minionAnim.rig          = model
		minionAnim.track        = minionTracks.idle
		minionAnim.looped       = true
		minionAnim.speed        = 1
		minionAnim.weight       = 1
		local minionData = {
			model          = model,
			animator       = minionAnim,
			tracks         = minionTracks,
			currentAnimKey = "idle",
			animTime       = 0,
			spawnAnim      = spawnAnim,
			spawnStart     = os.clock(),
			spawnDone      = false,
			spawnDuration  = 1.1667,
			isAttacking    = false,
			attackStart    = 0,
			isFading       = false,
			fadeElapsed    = 0,
		}
		table.insert(activeMinions, minionData)
		Debris:AddItem(model, 300)
		task.spawn(function()
			task.wait(minionData.spawnDuration)
			if model and model.Parent and dRoot then
				dRoot.Anchored = false
			end
		end)
	end
	local function destroyAllMinions()
		for _, md in ipairs(activeMinions) do
			if md.model and md.model.Parent then md.model:Destroy() end
		end
		activeMinions = {}
	end

	m.Init = function(figure)
		figureRef = figure
		local hum  = figure:FindFirstChildOfClass("Humanoid")
		local root = figure:FindFirstChild("HumanoidRootPart")
		if not hum or not root then return end

		animator        = AnimLib.Animator.new()
		animator.rig    = figure
		animator.looped = true

		tracks.idle           = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolIdle.anim"))
		tracks.walk           = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolWalk.anim"))
		tracks.run            = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolRun.anim"))
		tracks.m1             = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolM1.anim"))
		tracks.corrupt        = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolCorrupt.anim"))
		tracks.kill           = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolKill.anim"))
		tracks.stunnedStart   = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolStunStart.anim"))
		tracks.stunnedLoop    = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolStunLoop.anim"))
		tracks.stunnedEnd     = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolStunEnd.anim"))
		tracks.delivery       = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolDelivery.anim"))
		tracks.walkspeedStart = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolWalkspeedStart.anim"))
		tracks.walkspeedLoop  = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolWalkspeedLoop.anim"))
		tracks.walkspeedHit   = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolWalkspeedHit.anim"))
		tracks.walkspeedFail  = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolWalkspeedEnd.anim"))
		tracks.intro          = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolIntro.anim"))
		tracks.outro          = AnimLib.Track.fromfile(AssetGetPathFromFilename("TvCoolOutro.anim"))

		currentTrack   = tracks.idle
		animator.track = currentTrack

		lowerAnimator        = AnimLib.Animator.new()
		lowerAnimator.rig    = figure
		lowerAnimator.looped = true
		lowerAnimator.track  = tracks.idle
		lowerAnimator.weight = 1

		lastIdleVoice = os.clock()
		SetOverrideMovesetMusic(AssetGetContentId("Coming straight from your house.mp3"), "It's tv time", 1)
		setupFlingTouched(figure)
		task.spawn(function()
			cachedMinionAppearances = prefetchMinionAppearances(2)
			appearancesCached = true
		end)

		ContextActions:BindAction("tenna_m1", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill or isM1Active then return end
			isM1Active  = true
			flingActive = true
			m1AnimTime  = 0
			playSound("TvCoolM1.mp3", root)
			currentTrack   = tracks.m1
			animator.track = currentTrack
			task.spawn(function()
				task.wait(0.8833)
				flingActive = false
				isM1Active  = false
				lastState   = "none"
			end)
		end, true, Enum.UserInputType.MouseButton1)

		ContextActions:BindAction("tenna_corrupt", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill    = true
			flingActive   = true
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			playSound("TvCoolCorrupt.mp3", root)
			playRandomVoice(randomVoiceSfx, root)
			currentTrack   = tracks.corrupt
			animator.track = currentTrack
			animationTime  = 0
			task.wait(0.6667)
			flingActive   = false
			usingSkill    = false
			hum.WalkSpeed = 8
			hum.JumpPower = 50
			lastState     = "none"
		end, true, Enum.KeyCode.E)

		ContextActions:BindAction("tenna_kill", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill    = true
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			playSound("TvCoolKill.mp3", root)
			playRandomVoice(killVoiceSfx, root)
			currentTrack   = tracks.kill
			animator.track = currentTrack
			animationTime  = 0
			spawnVictimNPC(
				CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(0), 0),
				"TvCoolVictim.anim",
				3.3333
			)
			task.wait(1.8333)
			usingSkill    = false
			hum.WalkSpeed = 8
			hum.JumpPower = 50
			lastState     = "none"
		end, true, Enum.KeyCode.Z)

		ContextActions:BindAction("tenna_stun", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill    = true
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			playRandomVoice(randomVoiceSfx, root)
			currentTrack   = tracks.stunnedStart
			animator.track = currentTrack
			animationTime  = 0
			task.wait(0.8333)
			currentTrack   = tracks.stunnedLoop
			animator.track = currentTrack
			animationTime  = 0
			task.wait(0.8333)
			currentTrack   = tracks.stunnedEnd
			animator.track = currentTrack
			animationTime  = 0
			task.wait(1.0833)
			usingSkill    = false
			hum.WalkSpeed = 8
			hum.JumpPower = 50
			lastState     = "none"
		end, true, Enum.KeyCode.Three)

		ContextActions:BindAction("tenna_delivery", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill    = true
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			playSound("TvCoolkidMinionSpawn.mp3", root)
			playRandomVoice(randomVoiceSfx, root)
			currentTrack   = tracks.delivery
			animator.track = currentTrack
			animationTime  = 0
			destroyAllMinions()
			local minionAppearances
			if appearancesCached and #cachedMinionAppearances >= 2 then
				minionAppearances = cachedMinionAppearances
				task.spawn(function()
					appearancesCached       = false
					cachedMinionAppearances = prefetchMinionAppearances(2)
					appearancesCached       = true
				end)
			else
				minionAppearances       = prefetchMinionAppearances(2)
				cachedMinionAppearances = minionAppearances
				appearancesCached       = true
			end
			task.delay(0.90, function()
				if usingSkill then spawnTvMinion("left",  minionAppearances[1]) end
			end)
			task.delay(1.73, function()
				if usingSkill then spawnTvMinion("right", minionAppearances[2]) end
			end)
			task.wait(3.0000)
			usingSkill    = false
			hum.WalkSpeed = 8
			hum.JumpPower = 50
			lastState     = "none"
		end, true, Enum.KeyCode.R)

		ContextActions:BindAction("tenna_walk", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill  = true
			voidHit     = false
			voidActive  = false
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			playSound("TvCoolWalkspeedStart.mp3", root)
			playRandomVoice(randomVoiceSfx, root)
			currentTrack   = tracks.walkspeedStart
			animator.track = currentTrack
			animationTime  = 0
			task.wait(0.4000)
			local loopSnd   = Instance.new("Sound")
			loopSnd.SoundId = AssetGetContentId("TvCoolWalkspeedLoop.mp3")
			loopSnd.Volume  = 1.5
			loopSnd.Looped  = true
			loopSnd.Parent  = root
			loopSnd:Play()
			currentTrack   = tracks.walkspeedLoop
			animator.track = currentTrack
			animationTime  = 0
			voidActive     = true
			local hrp       = figure:FindFirstChild("HumanoidRootPart")
			local startTime = os.clock()
			local lockedDir = hrp and hrp.CFrame.LookVector or Vector3.new(0, 0, -1)
			hum.AutoRotate  = false
			local bv        = Instance.new("BodyVelocity")
			bv.Velocity     = lockedDir * 90
			bv.MaxForce     = Vector3.new(1e5, 0, 1e5)
			bv.P            = 1e5
			bv.Parent       = hrp
			while (os.clock() - startTime < 1.34) and not voidHit and usingSkill do
				task.wait()
			end
			bv:Destroy()
			hum.AutoRotate = true
			hum.WalkSpeed  = 0
			voidActive     = false
			loopSnd:Stop()
			loopSnd:Destroy()
			if voidHit and usingSkill then
				playVoice("TvCoolWalkspeedHitVoice.mp3", root)
				currentTrack   = tracks.walkspeedHit
				animator.track = currentTrack
				animationTime  = 0
				flingActive    = true
				task.wait(1.0667)
				flingActive    = false
			else
				playSound("TvCoolWalkspeedEnd.mp3", root)
				currentTrack   = tracks.walkspeedFail
				animator.track = currentTrack
				animationTime  = 0
				task.wait(1.0667)
			end
			usingSkill    = false
			hum.WalkSpeed = 8
			hum.JumpPower = 50
			lastState     = "none"
		end, true, Enum.KeyCode.Q)

      ContextActions:BindAction("tenna_intro", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill    = true
			flingActive   = true
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			playSound("TvCoolIntro.mp3", root)
			currentTrack   = tracks.intro
			animator.track = currentTrack
			animationTime  = 0
			task.wait(2.0833)
			flingActive   = false
			usingSkill    = false
			hum.WalkSpeed = 8
			hum.JumpPower = 50
			lastState     = "none"
		end, true, Enum.KeyCode.Four)

		ContextActions:BindAction("tenna_outro", function(_, state)
			if state ~= Enum.UserInputState.Begin then return end
			if outroActive then
				outroActive = false
				if outroConnection then
					outroConnection:Disconnect()
					outroConnection = nil
				end
				if activeVoiceSound and activeVoiceSound.Parent then
					activeVoiceSound:Stop()
					activeVoiceSound:Destroy()
					activeVoiceSound = nil
				end
				if not usingSkill then
					currentTrack   = tracks.idle
					animator.track = currentTrack
					animationTime  = 0
					lastState      = "none"
				end
				return
			end
			outroActive    = true
			local outroSnd = playSound("TvCoolOutro.mp3", root)
			currentTrack   = tracks.outro
			animator.track = currentTrack
			animationTime  = 0
			if outroConnection then
				outroConnection:Disconnect()
				outroConnection = nil
			end
			outroConnection = outroSnd.Ended:Connect(function()
				outroActive = false
				if outroConnection then
					outroConnection:Disconnect()
					outroConnection = nil
				end
				if not usingSkill then
					currentTrack   = tracks.idle
					animator.track = currentTrack
					animationTime  = 0
					lastState      = "none"
				end
			end)
		end, true, Enum.KeyCode.F)

		ContextActions:BindAction("tenna_sprint", function(_, state)
			if state == Enum.UserInputState.Begin then
				isSprinting = not isSprinting
				ContextActions:SetTitle("tenna_sprint", isSprinting and "Walk" or "Sprint")
			end
		end, true, Enum.KeyCode.LeftShift)

		ContextActions:SetTitle("tenna_m1",       "M1")
		ContextActions:SetTitle("tenna_corrupt",   "Corrupt")
		ContextActions:SetTitle("tenna_kill",      "Kill")
		ContextActions:SetTitle("tenna_stun",      "Stun")
		ContextActions:SetTitle("tenna_delivery",  "Delivery")
		ContextActions:SetTitle("tenna_walk",      "Walkspeed")
		ContextActions:SetTitle("tenna_sprint",    "Sprint")
      ContextActions:SetTitle("tenna_intro",     "Intro")
		ContextActions:SetTitle("tenna_outro",     "Outro")

		ContextActions:SetPosition("tenna_m1",       UDim2.new(1, -70,  1, -70))
		ContextActions:SetPosition("tenna_corrupt",  UDim2.new(1, -140, 1, -70))
		ContextActions:SetPosition("tenna_kill",     UDim2.new(1, -210, 1, -70))
		ContextActions:SetPosition("tenna_walk",     UDim2.new(1, -280, 1, -70))
		ContextActions:SetPosition("tenna_sprint",   UDim2.new(1, -350, 1, -70))
		ContextActions:SetPosition("tenna_stun",     UDim2.new(1, -70,  1, -150))
		ContextActions:SetPosition("tenna_delivery", UDim2.new(1, -140, 1, -150))
		ContextActions:SetPosition("tenna_outro",    UDim2.new(1, -210, 1, -150))
		ContextActions:SetPosition("tenna_intro",    UDim2.new(1, -280, 1, -150))
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
					if elapsed >= md.spawnDuration then
						md.spawnDone = true
					end
				else
					runCoolkidMinionAI(md, dt)
				end
			end
		end

		if not usingSkill and not outroActive then
			if os.clock() - lastIdleVoice >= 20 then
				lastIdleVoice = os.clock()
				if root then
					if math.random() < 0.4 then
						playRandomVoice(idleVoiceSfx, root)
					end
				end
			end

			local state = "idle"
			if hum.MoveDirection.Magnitude > 0.1 then
				state = isSprinting and "run" or "walk"
			end
			if lastState ~= state then
				animationTime = 0
				lastState     = state
			end
			local newTrack
			if state == "idle" then
				newTrack      = tracks.idle
				hum.WalkSpeed = 8
			elseif state == "walk" then
				newTrack      = tracks.walk
				hum.WalkSpeed = 8
			elseif state == "run" then
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

		if outroActive then
			animationTime += dt
			animator.looped = true
			animator:Step(animationTime)
			return
		end

		animationTime += dt

		if isM1Active then
			local LEG_JOINTS = { ["Left Hip"] = true, ["Right Hip"] = true }
			if lowerAnimator then
				local preSnapshot = {}
				for _, motor in ipairs(figure:GetDescendants()) do
					if motor:IsA("Motor6D") then
						preSnapshot[motor] = motor.Transform
					end
				end
				lowerAnimator.looped = true
				lowerAnimator:Step(animationTime)
				local legSnapshot = {}
				for _, motor in ipairs(figure:GetDescendants()) do
					if motor:IsA("Motor6D") and LEG_JOINTS[motor.Name] then
						legSnapshot[motor] = motor.Transform
					end
				end
				for motor, cf in pairs(preSnapshot) do
					if not LEG_JOINTS[motor.Name] then
						motor.Transform = cf
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
		else
			animator.looped = true
			animator:Step(animationTime)
		end
	end

	m.Destroy = function()
		destroyAllMinions()
		outroActive = false
		if outroConnection then
			outroConnection:Disconnect()
			outroConnection = nil
		end
		if activeVoiceSound and activeVoiceSound.Parent then
			activeVoiceSound:Stop()
			activeVoiceSound:Destroy()
		end
		activeVoiceSound = nil
		voidActive  = false
		voidHit     = false
		isSprinting = false
		flingActive = false
		usingSkill  = false
		for _, conn in ipairs(touchConns) do conn:Disconnect() end
		table.clear(touchConns)
		for _, data in ipairs(activeVictims) do
			if data.dummy then data.dummy:Destroy() end
		end
		activeVictims = {}
		ContextActions:UnbindAction("tenna_m1")
		ContextActions:UnbindAction("tenna_corrupt")
		ContextActions:UnbindAction("tenna_kill")
		ContextActions:UnbindAction("tenna_stun")
		ContextActions:UnbindAction("tenna_delivery")
		ContextActions:UnbindAction("tenna_walk")
		ContextActions:UnbindAction("tenna_sprint")
		ContextActions:UnbindAction("tenna_intro")
		ContextActions:UnbindAction("tenna_outro")
		isM1Active    = false
		m1AnimTime    = 0
		lowerAnimator = nil
		animator      = nil
		tracks        = {}
		currentTrack  = nil
		figureRef     = nil
	end

	return m
end)
return modules