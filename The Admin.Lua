local modules = {}

table.insert(modules, function()

	local m = {}
	m.ModuleType = "MOVESET"
	m.Name = "The Admin"
	m.Description = "NO, ITS MINE, *Panicked Pants* ITS MINE!\n\nBerrys take on Admin noli (way different from Mr eye's admin noli)\n\nMade by Berry"
	m.InternalName = "Admin_Noli"

	m.Assets = {
		"AdminIdle.anim",
		"AdminWalk.anim",
		"AdminVoidRun.anim",
		"AdminM1.anim",
		"AdminNova.anim",
		"AdminKill.anim",
		"AdminVictim.anim",
		"AdminIntro.anim",
		"AdminOutro.anim",
		"AdminStunStart.anim",
		"AdminStunLoop.anim",
		"AdminStunEnd.anim",
		"AdminObservStart.anim",
		"AdminObservLoop.anim",
		"AdminObservTeleport.anim",
		"AdminVoidStart.anim",
		"AdminVoidLoop.anim",
		"AdminVoidHit.anim",
		"AdminVoidEnd.anim",
		"AdminVoidSlam.anim",
		"AdminVoidVictim.anim",

		"AdminAmbience.mp3",
		"AdminM1.mp3",
		"AdminNova.mp3",
		"AdminKill.mp3",
		"AdminIntro.mp3",
		"AdminOutro.mp3",
		"AdminStun.mp3",
		"AdminVoidStart.mp3",
		"AdminVoidLoop.mp3",
		"AdminVoidSlam.mp3",
		"AdminVoidEnd.mp3",
		"AdminObservTeleporting.mp3",
		"AdminObservTeleportVoice.mp3",
		"AdminNovaVoice.mp3",
		"AdminNovaVoice2.mp3",
		"AdminNovaVoice3.mp3",
		"AdminNovaVoice4.mp3",
		"AdminNovaVoice5.mp3",
		"AdminKillVoice.mp3",
		"AdminKillVoice2.mp3",
		"AdminKillVoice3.mp3",
		"AdminKillVoice4.mp3",
		"AdminKillVoice5.mp3",
		"AdminKillVoice6.mp3",
		"AdminKillVoice7.mp3",
		"AdminKillVoice8.mp3",
		"AdminKillVoice9.mp3",
		"AdminKillVoice10.mp3",
		"AdminKillVoice11.mp3",
		"AdminStunVoice.mp3",
		"AdminStunVoice2.mp3",
		"AdminStunVoice3.mp3",
		"AdminStunVoice4.mp3",
		"AdminStunVoice5.mp3",
		"AdminStunVoice6.mp3",
		"AdminStunVoice7.mp3",
		"AdminStunVoice8.mp3",
		"AdminSlamVoice.mp3",
		"AdminSlamVoice2.mp3",
		"AdminSlamVoice3.mp3",
		"AdminVoidEndVoice.mp3",
		"AdminVoidEndVoice2.mp3",
		"AdminVoidEndVoice3.mp3",
		"AdminVoidHit1.mp3",
		"AdminVoidHit2.mp3",
		"AdminVoidHit3.mp3",
		"AdminVoidHit4.mp3",
		"AdminVoidHit5.mp3",
		"AdminVoidLoopEffect1.mp3",
		"AdminVoidLoopEffect2.mp3",
		"AdminObservStart.mp3",
		"AdminObservTeleporting.mp3",
		"AdminObservTeleportingVoice.mp3",
		"AdminIdleVoice.mp3",
		"AdminIdleVoice2.mp3",
		"adminIdleVoice3.mp3",
		"AdminIdleVoice4.mp3",
		"AdminIdleVoice5.mp3",
		"AdminIdleVoice6.mp3",
		"AdminIdleVoice7.mp3",
		"AdminIdleVoice8.mp3",
		"AdminIdleVoice9.mp3",
		"Final protocol.mp3",
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
	local lastIdleVoice = 0
	local isSprinting   = false
	local flingActive   = false
	local touchConns    = {}
	local figureRef     = nil
	local activeVictims = {}

	local observeConn   = nil
	local inObserveLoop = false
	local observeTarget = nil

	local isM1Active    = false
	local m1AnimTime    = 0
	local lowerAnimator = nil

	local lastUsingSkill      = false
	local voidActive          = false
	local voidHit             = false
	local isVoidDashing       = false
	local voidDashTimer       = 0
	local voidWindowTimer     = 0
	local voidMarkedTable     = {}
	local voidPurpleHighlights = {}
	local secondWindupActive  = false
	local secondWindupSound   = nil
	local voidHitCount        = 0
	local secondWindupVersion = 0
	local voidFirstUse        = true

	local activeVoiceSound = nil
	local bgSound          = nil

	local LEG_JOINTS = { ["Left Hip"] = true, ["Right Hip"] = true }

	local killVoiceSfx = {
		"AdminKillVoice.mp3",
		"AdminKillVoice2.mp3",
		"AdminKillVoice3.mp3",
		"AdminKillVoice4.mp3",
		"AdminKillVoice5.mp3",
		"AdminKillVoice6.mp3",
		"AdminKillVoice7.mp3",
		"AdminKillVoice8.mp3",
		"AdminKillVoice9.mp3",
		"AdminKillVoice10.mp3",
		"AdminKillVoice11.mp3",
	}
	local novaVoiceSfx = {
		"AdminNovaVoice.mp3",
		"AdminNovaVoice2.mp3",
		"AdminNovaVoice3.mp3",
		"AdminNovaVoice4.mp3",
		"AdminNovaVoice5.mp3",
	}
	local stunVoiceSfx = {
		"AdminStunVoice.mp3",
		"AdminStunVoice2.mp3",
		"AdminStunVoice3.mp3",
		"AdminStunVoice4.mp3",
		"AdminStunVoice5.mp3",
		"AdminStunVoice6.mp3",
		"AdminStunVoice7.mp3",
		"AdminStunVoice8.mp3",
	}
	local observTeleportVoiceSfx = {
		"AdminObservTeleportVoice.mp3",
	}
	local voidHitSfx = {
		"AdminVoidHit1.mp3",
		"AdminVoidHit2.mp3",
		"AdminVoidHit3.mp3",
		"AdminVoidHit4.mp3",
		"AdminVoidHit5.mp3",
	}
	local voidEndVoiceSfx = {
		"AdminVoidEndVoice.mp3",
		"AdminVoidEndVoice2.mp3",
		"AdminVoidEndVoice3.mp3",
	}
	local slamVoiceSfx = {
		"AdminSlamVoice.mp3",
		"AdminSlamVoice2.mp3",
		"AdminSlamVoice3.mp3",
	}
	local voidLoopEffectSfx = {
		"AdminVoidLoopEffect1.mp3",
		"AdminVoidLoopEffect2.mp3",
	}
	local idleVoiceSfx = {
		"AdminIdleVoice.mp3",
		"AdminIdleVoice2.mp3",
		"adminIdleVoice3.mp3",
		"AdminIdleVoice4.mp3",
		"AdminIdleVoice5.mp3",
		"AdminIdleVoice6.mp3",
		"AdminIdleVoice7.mp3",
		"AdminIdleVoice8.mp3",
		"AdminIdleVoice9.mp3",
	}

	local function clearVoidMarkedESP()
		for _, hl in pairs(voidPurpleHighlights) do
			if hl then hl:Destroy() end
		end
		table.clear(voidPurpleHighlights)
		table.clear(voidMarkedTable)
		voidHitCount = 0
		secondWindupVersion += 1
	end

	local function applyPurpleESP(targetModel)
		if not targetModel then return end
		if voidPurpleHighlights[targetModel] then
			voidPurpleHighlights[targetModel]:Destroy()
		end
		local hl = Instance.new("Highlight")
		hl.FillColor           = Color3.fromRGB(170, 0, 255)
		hl.FillTransparency    = 0.4
		hl.OutlineColor        = Color3.fromRGB(255, 255, 255)
		hl.OutlineTransparency = 0
		hl.Adornee             = targetModel
		hl.Parent              = targetModel
		voidPurpleHighlights[targetModel] = hl
		voidMarkedTable[targetModel]      = true
	end

	local function removeSingleTargetMark(targetModel)
		if not targetModel then return end
		voidMarkedTable[targetModel] = nil
		if voidPurpleHighlights[targetModel] then
			voidPurpleHighlights[targetModel]:Destroy()
			voidPurpleHighlights[targetModel] = nil
		end
	end

	local function playSound(id, parent)
		local s = Instance.new("Sound")
		s.SoundId = AssetGetContentId(id)
		s.Volume  = 1.5
		s.Parent  = parent
		s:Play()
		Debris:AddItem(s, 10)
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
		Debris:AddItem(s, 11)
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
				if not target:FindFirstChildOfClass("Humanoid") then return end
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
			pcall(function()
				local hum = dummy:FindFirstChildOfClass("Humanoid")
				if hum and hum.RigType == Enum.HumanoidRigType.R15 then
					local desc = hum:GetAppliedDescription()
					dummy:Destroy()
					dummy = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
				end
			end)
			if not dummy then return end
			dummy.Name   = "AdminVictim"
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

	local function clearObserve()
		inObserveLoop = false
		observeTarget = nil
		if observeConn then
			observeConn:Disconnect()
			observeConn = nil
		end
	end

	m.Init = function(figure)
		figureRef = figure
		local hum  = figure:FindFirstChildOfClass("Humanoid")
		local root = figure:FindFirstChild("HumanoidRootPart")
		if not hum or not root then return end

		animator        = AnimLib.Animator.new()
		animator.rig    = figure
		animator.looped = true

		tracks.idle          = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminIdle.anim"))
		tracks.walk          = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminWalk.anim"))
		tracks.run           = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminVoidRun.anim"))
		tracks.m1            = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminM1.anim"))
		tracks.nova          = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminNova.anim"))
		tracks.kill          = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminKill.anim"))
		tracks.intro         = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminIntro.anim"))
		tracks.outro         = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminOutro.anim"))
		tracks.stunnedStart  = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminStunStart.anim"))
		tracks.stunnedLoop   = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminStunLoop.anim"))
		tracks.stunnedEnd    = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminStunEnd.anim"))
		tracks.obserStart    = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminObservStart.anim"))
		tracks.obserLoop     = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminObservLoop.anim"))
		tracks.obserTeleport = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminObservTeleport.anim"))
		tracks.voidWindup    = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminVoidStart.anim"))
		tracks.voidLoop      = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminVoidLoop.anim"))
		tracks.voidHit       = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminVoidHit.anim"))
		tracks.voidEnd       = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminVoidEnd.anim"))
		tracks.slam          = AnimLib.Track.fromfile(AssetGetPathFromFilename("AdminVoidSlam.anim"))

		currentTrack   = tracks.idle
		animator.track = currentTrack

		lowerAnimator        = AnimLib.Animator.new()
		lowerAnimator.rig    = figure
		lowerAnimator.looped = true
		lowerAnimator.track  = tracks.idle
		lowerAnimator.weight = 1

		voidFirstUse  = true
		lastIdleVoice = os.clock()
		SetOverrideMovesetMusic(AssetGetContentId("Final protocol.mp3"), "Final Protocol.CMD", 1)

		bgSound          = Instance.new("Sound")
		bgSound.SoundId  = AssetGetContentId("AdminAmbience.mp3")
		bgSound.Volume   = 1
		bgSound.Looped   = true
		bgSound.Parent   = root
		bgSound:Play()

		setupFlingTouched(figure)

		ContextActions:BindAction("adm_m1", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill = true
			task.spawn(function()
				flingActive    = true
				isM1Active     = true
				m1AnimTime     = 0
				playSound("AdminM1.mp3", root)
				currentTrack   = tracks.m1
				animator.track = currentTrack
				animationTime  = 0
				task.wait(0.85)
				isM1Active  = false
				flingActive = false
				usingSkill  = false
				lastState   = "none"
			end)
		end, true, Enum.UserInputType.MouseButton1)

		ContextActions:BindAction("adm_nova", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill = true
			task.spawn(function()
				flingActive    = true
				playSound("AdminNova.mp3", root)
				playRandomVoice(novaVoiceSfx, root)
				currentTrack   = tracks.nova
				animator.track = currentTrack
				animationTime  = 0
				task.wait(1.3167)
				flingActive = false
				usingSkill  = false
				lastState   = "none"
			end)
		end, true, Enum.KeyCode.E)

		ContextActions:BindAction("adm_kill", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill = true
			task.spawn(function()
				hum.WalkSpeed = 0
				hum.JumpPower = 0
				playSound("AdminKill.mp3", root)
				playRandomVoice(killVoiceSfx, root)
				currentTrack   = tracks.kill
				animator.track = currentTrack
				animationTime  = 0
				spawnVictimNPC(
					CFrame.new(0, 0, -3) * CFrame.Angles(0, math.pi, 0),
					"AdminVictim.anim",
					4.2
				)
				task.wait(4.2)
				usingSkill    = false
				hum.WalkSpeed = 8
				hum.JumpPower = 50
				lastState     = "none"
			end)
		end, true, Enum.KeyCode.Z)

		ContextActions:BindAction("adm_intro", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill = true
			task.spawn(function()
				hum.WalkSpeed = 0
				hum.JumpPower = 0
				playSound("AdminIntro.mp3", root)
				currentTrack   = tracks.intro
				animator.track = currentTrack
				animationTime  = 0
				task.wait(5.55)
				usingSkill    = false
				hum.WalkSpeed = 8
				hum.JumpPower = 50
				lastState     = "none"
			end)
		end, true, Enum.KeyCode.One)

		ContextActions:BindAction("adm_outro", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill = true
			task.spawn(function()
				hum.WalkSpeed = 0
				hum.JumpPower = 0
				playSound("AdminOutro.mp3", root)
				currentTrack   = tracks.outro
				animator.track = currentTrack
				animationTime  = 0
				task.wait(3.55)
				usingSkill    = false
				hum.WalkSpeed = 8
				hum.JumpPower = 50
				lastState     = "none"
			end)
		end, true, Enum.KeyCode.Two)

		ContextActions:BindAction("adm_stun", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill = true
			task.spawn(function()
				hum.WalkSpeed = 0
				hum.JumpPower = 0
				playSound("AdminStun.mp3", root)
				playRandomVoice(stunVoiceSfx, root)
				currentTrack   = tracks.stunnedStart
				animator.track = currentTrack
				animationTime  = 0
				task.wait(1.3)
				currentTrack   = tracks.stunnedLoop
				animator.track = currentTrack
				animationTime  = 0
				task.wait(1.6333)
				currentTrack   = tracks.stunnedEnd
				animator.track = currentTrack
				animationTime  = 0
				task.wait(0.9833)
				usingSkill    = false
				hum.WalkSpeed = 8
				hum.JumpPower = 50
				lastState     = "none"
			end)
		end, true, Enum.KeyCode.Three)

		ContextActions:BindAction("adm_observe", function(_, state)
			if state ~= Enum.UserInputState.Begin or usingSkill then return end
			usingSkill = true
			task.spawn(function()
				clearObserve()
				hum.WalkSpeed = 0
				hum.JumpPower = 0

				playSound("AdminObservStart.mp3", root)
				isM1Active     = true
				m1AnimTime     = 0
				currentTrack   = tracks.obserStart
				animator.track = currentTrack
				animator.looped = false
				animationTime  = 0
				task.wait(0.7667)
				isM1Active     = false

				inObserveLoop   = true
				currentTrack    = tracks.obserLoop
				animator.track  = currentTrack
				animator.looped = true
				animationTime   = 0

				observeConn = UIS.InputBegan:Connect(function(input, gp)
					if gp then return end
					if not inObserveLoop then return end
					if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then
						local camera = workspace.CurrentCamera
						if not camera then return end
						local screenPos = input.Position
						local unitRay   = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
						local rp        = RaycastParams.new()
						rp.FilterDescendantsInstances = {figure}
						rp.FilterType = Enum.RaycastFilterType.Exclude
						local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, rp)
						observeTarget = result and result.Position or (unitRay.Origin + unitRay.Direction * 100)
						inObserveLoop = false
						if observeConn then observeConn:Disconnect() observeConn = nil end
					end
				end)

				while inObserveLoop and usingSkill do task.wait(0.03) end

				animator.looped = false

				if observeTarget and usingSkill then
					local hrp = figure:FindFirstChild("HumanoidRootPart")
					currentTrack   = tracks.obserTeleport
					animator.track = currentTrack
					animationTime  = 0
					playSound("AdminObservTeleporting.mp3", root)
					playSound("AdminObservTeleportingVoice.mp3", root)
					task.wait(1.45)
					if hrp and observeTarget and usingSkill then
						local look = hrp.CFrame.LookVector
						hrp.CFrame = CFrame.new(observeTarget + Vector3.new(0, 3, 0),
						                        observeTarget + Vector3.new(0, 3, 0) + look)
					end
					playRandomVoice(observTeleportVoiceSfx, root)
					task.wait(1.85)
				end

				clearObserve()
				usingSkill    = false
				hum.WalkSpeed = 8
				hum.JumpPower = 50
				lastState     = "none"
			end)
		end, true, Enum.KeyCode.R)

		local function doVoidDash(isCombo)
			local hrp = figure:FindFirstChild("HumanoidRootPart")
			if not hrp then return end

			if isCombo then
				if secondWindupSound then
					secondWindupSound:Stop()
					secondWindupSound:Destroy()
					secondWindupSound = nil
				end
				secondWindupActive = false
			else
				playSound("AdminVoidStart.mp3", root)
				currentTrack   = tracks.voidWindup
				animator.track = currentTrack
				animationTime  = 0
				task.wait(0.9833)
			end

			local function makeLoopSnd(id)
				local s = Instance.new("Sound")
				s.SoundId = AssetGetContentId(id)
				s.Volume  = 1.5
				s.Looped  = true
				s.Parent  = root
				s:Play()
				return s
			end

			local loopSnd       = makeLoopSnd("AdminVoidLoop.mp3")
			local loopEffect1   = makeLoopSnd("AdminVoidLoopEffect1.mp3")
			local loopEffect2   = makeLoopSnd("AdminVoidLoopEffect2.mp3")

			local function stopAllLoops()
				loopSnd:Stop();     loopSnd:Destroy()
				loopEffect1:Stop(); loopEffect1:Destroy()
				loopEffect2:Stop(); loopEffect2:Destroy()
			end

			currentTrack   = tracks.voidLoop
			animator.track = currentTrack
			animationTime  = 0
			isVoidDashing  = true
			voidDashTimer  = 3.5

			while isVoidDashing do
				local dt2 = RunService.Heartbeat:Wait()
				voidDashTimer = voidDashTimer - dt2

				local cam     = workspace.CurrentCamera
				local look    = cam and cam.CFrame.LookVector or hrp.CFrame.LookVector
				local moveVec = Vector3.new(look.X, 0, look.Z).Unit
				local newPos  = hrp.Position + moveVec * 50 * dt2
				hrp.CFrame    = CFrame.new(newPos, newPos + moveVec)

				local rp = RaycastParams.new()
				rp.FilterDescendantsInstances = {figure}
				rp.FilterType = Enum.RaycastFilterType.Blacklist

				local checkOffsets = {
					Vector3.new(0,    0,    0),
					Vector3.new(3.2,  0,   -1),
					Vector3.new(-3.2, 0,   -1),
					Vector3.new(1.5,  1.5,  0),
					Vector3.new(-1.5,-1.5,  0),
				}

				local hitDetected = false
				local hitModel

				for _, offset in ipairs(checkOffsets) do
					local originPos = hrp.CFrame:PointToWorldSpace(offset)
					local result    = workspace:Raycast(originPos, moveVec * 6.5, rp)
					if result and result.Instance then
						local maybeModel = result.Instance:FindFirstAncestorOfClass("Model")
						local maybeHum   = maybeModel and maybeModel:FindFirstChildOfClass("Humanoid")
						local maybePlr   = maybeModel and Players:GetPlayerFromCharacter(maybeModel)
						if maybeHum and maybeModel ~= figure and maybePlr and maybePlr ~= Player then
							hitModel    = maybeModel
							hitDetected = true
							break
						end
					end
				end

				if hitDetected then
					stopAllLoops()
					isVoidDashing = false

					local isMarked = voidMarkedTable[hitModel] == true

					if isMarked then
						clearVoidMarkedESP()
						playSound("AdminVoidSlam.mp3", root)
						playRandomVoice(slamVoiceSfx, root)
						flingActive    = true
						currentTrack   = tracks.slam
						animator.track = currentTrack
						animationTime  = 0
						spawnVictimNPC(
							CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi, 0),
							"AdminVoidVictim.anim",
							0.5333
						)
						task.wait(3.4167)
						ReanimateFling(hitModel)
						flingActive   = false
						usingSkill    = false
						hum.WalkSpeed = 8
						hum.JumpPower = 50
						lastState     = "none"
					else
						applyPurpleESP(hitModel)
						voidHitCount = math.min(voidHitCount + 1, 4)

						playRandomVoice(voidHitSfx, root)
						currentTrack   = tracks.voidHit
						animator.track = currentTrack
						animationTime  = 0
						task.wait(0.65)

						usingSkill    = false
						hum.WalkSpeed = 8
						hum.JumpPower = 50
						lastState     = "none"

						secondWindupActive = true
						secondWindupVersion += 1
						local myVer = secondWindupVersion

						if secondWindupSound then
							secondWindupSound:Stop()
							secondWindupSound:Destroy()
							secondWindupSound = nil
						end
						local sws = Instance.new("Sound")
						sws.SoundId = AssetGetContentId("AdminVoidEnd.mp3")
						sws.Volume  = 1.5
						sws.Parent  = root
						sws:Play()
						secondWindupSound = sws
						Debris:AddItem(sws, 10)

						task.delay(2, function()
							if secondWindupActive and secondWindupVersion == myVer then
								secondWindupActive = false
								secondWindupSound  = nil
								clearVoidMarkedESP()
								voidHitCount = 0
							end
						end)
					end
					return
				end

				if voidDashTimer <= 0 then
					stopAllLoops()
					isVoidDashing = false
					playRandomVoice(voidEndVoiceSfx, root)
					currentTrack   = tracks.voidEnd
					animator.track = currentTrack
					animationTime  = 0
					task.wait(0.9667)
					clearVoidMarkedESP()
					usingSkill    = false
					hum.WalkSpeed = 8
					hum.JumpPower = 50
					lastState     = "none"
					return
				end
			end

			loopSnd:Stop(); loopSnd:Destroy()
			isVoidDashing = false
			usingSkill    = false
			hum.WalkSpeed = 8
			hum.JumpPower = 50
			lastState     = "none"
		end

		ContextActions:BindAction("adm_void", function(_, state)
			if state ~= Enum.UserInputState.Begin or isVoidDashing then return end
			if usingSkill then return end

			usingSkill    = true
			hum.WalkSpeed = 0
			hum.JumpPower = 0

			if next(voidMarkedTable) ~= nil and secondWindupActive then
				task.spawn(function() doVoidDash(true) end)
				return
			end

			secondWindupActive = false
			if secondWindupSound then
				secondWindupSound:Stop()
				secondWindupSound:Destroy()
				secondWindupSound = nil
			end
			clearVoidMarkedESP()

			voidHit    = false
			voidActive = false
			task.spawn(function() doVoidDash(false) end)
		end, true, Enum.KeyCode.Q)

		ContextActions:BindAction("adm_sprint", function(_, state)
			if state == Enum.UserInputState.Begin then
				isSprinting = not isSprinting
				ContextActions:SetTitle("adm_sprint", isSprinting and "Walk" or "Sprint")
			end
		end, true, Enum.KeyCode.LeftShift)

		ContextActions:SetTitle("adm_m1",      "M1")
		ContextActions:SetTitle("adm_nova",    "Nova")
		ContextActions:SetTitle("adm_kill",    "Kill")
		ContextActions:SetTitle("adm_void",    "Void")
		ContextActions:SetTitle("adm_intro",   "Intro")
		ContextActions:SetTitle("adm_outro",   "Outro")
		ContextActions:SetTitle("adm_stun",    "Stun")
		ContextActions:SetTitle("adm_observe", "Observe")
		ContextActions:SetTitle("adm_sprint",  "Sprint")

		ContextActions:SetPosition("adm_m1",      UDim2.new(1, -70,  1, -70))
		ContextActions:SetPosition("adm_nova",    UDim2.new(1, -140, 1, -70))
		ContextActions:SetPosition("adm_kill",    UDim2.new(1, -210, 1, -70))
		ContextActions:SetPosition("adm_void",    UDim2.new(1, -280, 1, -70))
		ContextActions:SetPosition("adm_sprint",  UDim2.new(1, -350, 1, -70))
		ContextActions:SetPosition("adm_intro",   UDim2.new(1, -70,  1, -150))
		ContextActions:SetPosition("adm_outro",   UDim2.new(1, -140, 1, -150))
		ContextActions:SetPosition("adm_stun",    UDim2.new(1, -210, 1, -150))
		ContextActions:SetPosition("adm_observe", UDim2.new(1, -280, 1, -150))
	end

	m.Update = function(dt, figure)
		if not animator then return end
		local hum  = figure:FindFirstChildOfClass("Humanoid")
		local root = figure:FindFirstChild("HumanoidRootPart")
		if not hum then return end

		if bgSound then
			if usingSkill and not lastUsingSkill then
				bgSound:Pause()
			elseif not usingSkill and lastUsingSkill then
				bgSound:Resume()
			end
		end
		lastUsingSkill = usingSkill

		if voidWindowTimer > 0 then
			voidWindowTimer = voidWindowTimer - dt
			if voidWindowTimer <= 0 then
				voidWindowTimer = 0
				clearVoidMarkedESP()
			end
		end

		local now = os.clock()
		for i = #activeVictims, 1, -1 do
			local data = activeVictims[i]
			if data.dummy and data.dummy.Parent then
				data.anim:Step(now - data.start)
			else
				table.remove(activeVictims, i)
			end
		end

		if not usingSkill then
			if os.clock() - lastIdleVoice >= 20 then
				lastIdleVoice = os.clock()
				if root and math.random() < 0.4 then
					playRandomVoice(idleVoiceSfx, root)
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

		animationTime += dt

		if isM1Active then
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
			if inObserveLoop then
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
					animator.looped = true
					animator:Step(animationTime)
					for motor, cf in pairs(legSnapshot) do
						motor.Transform = cf
					end
				else
					animator.looped = true
					animator:Step(animationTime)
				end
			else
				animator.looped = true
				animator:Step(animationTime)
			end
		end
	end

	m.Destroy = function()
		clearObserve()
		clearVoidMarkedESP()
		voidActive         = false
		voidHit            = false
		isVoidDashing      = false
		voidDashTimer      = 0
		voidWindowTimer    = 0
		secondWindupActive = false
		voidFirstUse       = true
		if secondWindupSound then
			secondWindupSound:Stop()
			secondWindupSound:Destroy()
			secondWindupSound = nil
		end
		if bgSound and bgSound.Parent then
			bgSound:Stop()
			bgSound:Destroy()
		end
		bgSound = nil
		if activeVoiceSound and activeVoiceSound.Parent then
			activeVoiceSound:Stop()
			activeVoiceSound:Destroy()
		end
		activeVoiceSound = nil
		isSprinting  = false
		flingActive  = false
		usingSkill   = false
		for _, conn in ipairs(touchConns) do conn:Disconnect() end
		table.clear(touchConns)
		for _, data in ipairs(activeVictims) do
			if data.dummy then data.dummy:Destroy() end
		end
		activeVictims = {}
		ContextActions:UnbindAction("adm_m1")
		ContextActions:UnbindAction("adm_nova")
		ContextActions:UnbindAction("adm_kill")
		ContextActions:UnbindAction("adm_intro")
		ContextActions:UnbindAction("adm_outro")
		ContextActions:UnbindAction("adm_stun")
		ContextActions:UnbindAction("adm_observe")
		ContextActions:UnbindAction("adm_void")
		ContextActions:UnbindAction("adm_sprint")
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