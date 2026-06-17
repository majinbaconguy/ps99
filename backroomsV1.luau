task.spawn(function()
	local StarterPlayer = game:GetService("StarterPlayer")
	local StarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts", 5)
	local scripts = StarterPlayerScripts and StarterPlayerScripts:WaitForChild("Scripts", 5)
	local gameScripts = scripts and scripts:FindFirstChild("Core")
	local idleTracking = gameScripts and gameScripts:FindFirstChild("Idle Tracking")
	if idleTracking and idleTracking:IsA("LocalScript") then
		idleTracking.Enabled = false
		warn("DISABLED IDLE TRACKING")
	else
		warn("CANT FIND IDLE TRACKING")
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function getCharacter()
	return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function createMessage(msg)
	local message = Instance.new("Message", workspace)
	message.Text = msg
	return message
end

if _G.ExecutedScript ~= nil then
	createMessage("Script was rexecuted rejoining the game...")
	task.delay(2, function()
		game:GetService("TeleportService"):Teleport(game.PlaceId, game.Players.LocalPlayer)
	end)
	return
end

_G.ExecutedScript = true

local character = getCharacter()
if character then
	local enterPart = workspace:WaitForChild("__THINGS"):WaitForChild("Instances"):WaitForChild("Backrooms"):WaitForChild("Teleports"):WaitForChild("Enter")
	character:PivotTo(enterPart.CFrame)
end

local InstancingCmds = require(game.ReplicatedStorage.Library.Client.InstancingCmds)
local Network = require(game.ReplicatedStorage.Library.Client.Network)
local CustomEggsCmds = require(game.ReplicatedStorage.Library.Client.CustomEggsCmds)
local EggCmds = require(game.ReplicatedStorage.Library.Client.EggCmds)
local MiscItem = require(game.ReplicatedStorage.Library.Items.MiscItem)
local PlayerPet = require(game.ReplicatedStorage.Library.Client.PlayerPet)

local activeFolder = workspace:WaitForChild("__THINGS"):WaitForChild("__INSTANCE_CONTAINER"):WaitForChild("Active")
local backroomsFolder = activeFolder:WaitForChild("Backrooms")
local GeneratedBackrooms = backroomsFolder:WaitForChild("GeneratedBackrooms")

local scannedRooms = {}
local scannedUIDs = {}
local visitedAnchors = {}
local scanRunning = false
local scanCompleted = false
local tpRunning = false

local Window = Rayfield:CreateWindow({
	Name = "PS99 Backrooms Script",
	LoadingTitle = "Loading...",
	LoadingSubtitle = "by Pirate Games",
	Theme = "Default",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "BackroomsScanner",
		FileName = "Config"
	},
	KeySystem = false
})

local Tab = Window:CreateTab("Main", 4483362458)
local MiniBossTab = Window:CreateTab("Mini Boss", 4483362458)
local StatusLabel = Tab:CreateLabel("Status: Idle")

local selectedEggType = "Any"
local EggDropdown = Tab:CreateDropdown({
	Name = "Target Egg Type",
	Options = {"Any", "Smile", "Flower", "Swirl"},
	CurrentValue = "Any",
	Flag = "TargetEggType",
	Callback = function(Option)
		local val = typeof(Option) == "table" and Option[1] or Option
		if not val or val == "None" or val == "" then
			selectedEggType = "Any"
		else
			selectedEggType = val
		end
	end,
})

local autoFindBest = false
local AutoFindBestToggle
local AutoTPGauntletToggle
local AutoTPTitanicToggle
local AutoFarmMiniBossToggle

AutoFindBestToggle = Tab:CreateToggle({
	Name = "Auto TP to Best Egg",
	CurrentValue = false,
	Flag = "AutoFindBest",
	Callback = function(Value)
		autoFindBest = Value
		if Value then
			if AutoTPGauntletToggle then AutoTPGauntletToggle:Set(false) end
			if AutoTPTitanicToggle then AutoTPTitanicToggle:Set(false) end
			if AutoFarmMiniBossToggle then AutoFarmMiniBossToggle:Set(false) end
		end
	end,
})

local autoTPGauntlet = false
AutoTPGauntletToggle = Tab:CreateToggle({
	Name = "Auto TP to Active Gauntlet Room",
	CurrentValue = false,
	Flag = "AutoTPGauntlet",
	Callback = function(Value)
		autoTPGauntlet = Value
		if Value then
			if AutoFindBestToggle then AutoFindBestToggle:Set(false) end
			if AutoTPTitanicToggle then AutoTPTitanicToggle:Set(false) end
			if AutoFarmMiniBossToggle then AutoFarmMiniBossToggle:Set(false) end
		end
	end,
})

local autoTPTitanic = false
AutoTPTitanicToggle = Tab:CreateToggle({
	Name = "Auto TP to Active Titanic Room",
	CurrentValue = false,
	Flag = "AutoTPTitanic",
	Callback = function(Value)
		autoTPTitanic = Value
		if Value then
			if AutoFindBestToggle then AutoFindBestToggle:Set(false) end
			if AutoTPGauntletToggle then AutoTPGauntletToggle:Set(false) end
			if AutoFarmMiniBossToggle then AutoFarmMiniBossToggle:Set(false) end
		end
	end,
})

local function setHatchAnimation(enabled)
	local pscripts = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerScripts")
	local scripts = pscripts and pscripts:FindFirstChild("Scripts")
	local gameScripts = scripts and scripts:FindFirstChild("Game")
	local eggFront = gameScripts and gameScripts:FindFirstChild("Egg Opening Frontend")
	if eggFront and eggFront:IsA("LocalScript") then
		eggFront.Enabled = enabled
	end
end

local autoHatchEnabled = false
local AutoHatchToggle = Tab:CreateToggle({
	Name = "Auto Hatch Eggs",
	CurrentValue = false,
	Flag = "AutoHatchEnabled",
	Callback = function(Value)
		autoHatchEnabled = Value
	end,
})

local hideHatchAnimation = false
local HideHatchAnimationToggle = Tab:CreateToggle({
	Name = "Hide Hatch Animation",
	CurrentValue = false,
	Flag = "HideHatchAnimation",
	Callback = function(Value)
		if scanRunning then return end
		hideHatchAnimation = Value
		setHatchAnimation(not Value)
	end,
})

local function getBestEggRoom()
	local bestRoom = nil
	local maxMult = -1
	for _, room in ipairs(scannedRooms) do
		if room.RoomID == "FreeEggRoom" and room.EggMultiplier then
			local matchesEgg = true
			if selectedEggType ~= "Any" then
				matchesEgg = false
				if room.EggName and string.find(string.lower(room.EggName), string.lower(selectedEggType)) then
					matchesEgg = true
				end
			end
			if matchesEgg and room.EggMultiplier > maxMult then
				maxMult = room.EggMultiplier
				bestRoom = room
			end
		end
	end
	return bestRoom
end

local function getActiveTitanicRoom()
	for _, room in ipairs(scannedRooms) do
		if room.RoomID == "TitanicEggRoom" and room.IsActive then
			return room
		end
	end
	return nil
end

local function getActiveGauntletRoom()
	for _, room in ipairs(scannedRooms) do
		if room.RoomID == "GauntletEggRoom" and room.IsActive then
			return room
		end
	end
	return nil
end

local function getActiveMiniBossRoom()
	for _, room in ipairs(scannedRooms) do
		if room.RoomID == "MiniBossRoom" or room.Name == "MiniBossRoom" then
			return room
		end
	end
	return nil
end

local function findRoomModel(roomUID)
	for _, child in ipairs(GeneratedBackrooms:GetChildren()) do
		if child:GetAttribute("RoomUID") == roomUID then
			return child
		end
	end
	return nil
end

local function unlockRoomDoors(roomUID, isDeepRoom)
	local roomModel = findRoomModel(roomUID)
	if not roomModel then return end
	local LockedDoors = roomModel:FindFirstChild("LockedDoors")
	if not LockedDoors then return end
	local isLocked = false
	for _, child in ipairs(LockedDoors:GetChildren()) do
		local Lock = child:FindFirstChild("Lock")
		if Lock and Lock.Transparency < 0.5 then
			isLocked = true
			break
		end
	end
	if not isLocked then return end
	local keyItem = MiscItem(isDeepRoom and "Deep Backrooms Crayon Key" or "Backrooms Crayon Key")
	if keyItem and keyItem:HasAny() then
		local activeInstance = InstancingCmds.Get()
		if activeInstance then
			activeInstance:FireCustom("AbstractRoom_FireServer", roomUID, "UnlockDoors")
		end
	end
end

local function teleportToRoom(room)
	if tpRunning then return end
	tpRunning = true
	local character = getCharacter()
	if character and room then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = true
			local roofCFrame = room.ScanCFrame or room.CFrame
			local roomModel = findRoomModel(room.RoomUID)
			if roomModel then
				local cf, size = roomModel:GetBoundingBox()
				local roofY = cf.Position.Y + size.Y / 2
				roofCFrame = CFrame.new(cf.Position.X, roofY + 10, cf.Position.Z)
			end
			Network.Fire("RequestStreaming", roofCFrame.Position)
			character:PivotTo(roofCFrame)
			task.wait(0.65)
			roomModel = findRoomModel(room.RoomUID)
			if roomModel then
				if room.RoomID == "FreeEggRoom" or room.Name == "FreeEggRoom" then
					local dest = roomModel:FindFirstChild("Sign") or roomModel:WaitForChild("Sign", 0.5)
					if dest then
						character:PivotTo(dest:GetPivot() + Vector3.new(0, 3, 0))
					end
				elseif room.RoomID == "GauntletEggRoom" or room.Name == "GauntletEggRoom" then
					local lockedDoors = roomModel:FindFirstChild("LockedDoors")
					local door = lockedDoors and lockedDoors:FindFirstChild("Door")
					if door then
						character:PivotTo(door:GetPivot())
						task.wait(0.25)
					end
					unlockRoomDoors(room.RoomUID, room.DeepRoom)
					task.wait(0.15)
					local dest = roomModel:FindFirstChild("EggPedestal") or roomModel:WaitForChild("EggPedestal", 0.5)
					if dest then
						character:PivotTo(dest:GetPivot() + Vector3.new(0, 2.5, 0))
					end
				elseif room.RoomID == "TitanicEggRoom" or room.Name == "TitanicEggRoom" then
					local lockedDoors = roomModel:FindFirstChild("LockedDoors")
					local door = lockedDoors and lockedDoors:FindFirstChild("Door")
					if door then
						character:PivotTo(door:GetPivot())
						task.wait(0.25)
					end
					unlockRoomDoors(room.RoomUID, room.DeepRoom)
					task.wait(0.15)
					local dest = roomModel:FindFirstChild("FeatureAnchor") or roomModel:WaitForChild("FeatureAnchor", 0.5)
					if dest then
						character:PivotTo(dest:GetPivot())
					end
				elseif room.RoomID == "BreakableRoom" or room.Name == "BreakableRoom" then
					local dest = roomModel:FindFirstChild("BREAK_ZONE") or roomModel:WaitForChild("BREAK_ZONE", 0.5)
					if dest then
						character:PivotTo(dest:GetPivot() + Vector3.new(0, 5, 0))
					else
						character:PivotTo(room.CFrame)
					end
				elseif room.RoomID == "MiniBossRoom" or room.Name == "MiniBossRoom" then
					local lockedDoors = roomModel:FindFirstChild("LockedDoors")
					local door = lockedDoors and lockedDoors:FindFirstChild("Door")
					if door then
						character:PivotTo(door:GetPivot())
						task.wait(0.25)
					end
					unlockRoomDoors(room.RoomUID, room.DeepRoom)
					task.wait(0.15)
					character:PivotTo(room.CFrame)
				else
					character:PivotTo(room.CFrame)
				end
			else
				character:PivotTo(room.CFrame)
			end
			task.wait(0.15)
			hrp.Anchored = false
		end
	end
	tpRunning = false
end

local function serverHop()
	local HttpService = game:GetService("HttpService")
	local TeleportService = game:GetService("TeleportService")
	local success, result = pcall(function()
		local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
		for _, server in ipairs(servers.data) do
			if server.playing < server.maxPlayers and server.id ~= game.JobId then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
				return true
			end
		end
	end)
	if not success then
		TeleportService:Teleport(game.PlaceId, LocalPlayer)
	end
end

local BestButton = Tab:CreateButton({
	Name = "Teleport to Best Egg Room",
	Callback = function()
		if scanRunning or tpRunning then return end
		local room = getBestEggRoom()
		if room then
			teleportToRoom(room)
		else
			createMessage("No suitable EggRoom found. Server hopping...")
			task.wait(1)
			serverHop()
		end
	end,
})

local GauntletButton = Tab:CreateButton({
	Name = "Teleport to Active Gauntlet Room",
	Callback = function()
		if scanRunning or tpRunning then return end
		local room = getActiveGauntletRoom()
		if room then
			teleportToRoom(room)
		else
			createMessage("No active Gauntlet Room found. Server hopping...")
			task.wait(1)
			serverHop()
		end
	end,
})

local TitanicButton = Tab:CreateButton({
	Name = "Teleport to Active Titanic Room",
	Callback = function()
		if scanRunning or tpRunning then return end
		local room = getActiveTitanicRoom()
		if room then
			teleportToRoom(room)
		else
			createMessage("No active Titanic Room found. Server hopping...")
			task.wait(1)
			serverHop()
		end
	end,
})

local function getNearestBreakableRoom()
	local character = getCharacter()
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local closestRoom = nil
	local minDist = math.huge
	for _, room in ipairs(scannedRooms) do
		if room.Name == "BreakableRoom" then
			local dist = (room.Position - hrp.Position).Magnitude
			if dist < minDist then
				minDist = dist
				closestRoom = room
			end
		end
	end
	return closestRoom
end

local BreakableButton = Tab:CreateButton({
	Name = "Teleport to Nearest Breakable Room",
	Callback = function()
		if scanRunning or tpRunning then return end
		local room = getNearestBreakableRoom()
		if room then
			teleportToRoom(room)
		else
			createMessage("No BreakableRoom found!")
		end
	end,
})

local autoFarmMiniBoss = false

AutoFarmMiniBossToggle = MiniBossTab:CreateToggle({
	Name = "Auto Farm Mini Boss",
	CurrentValue = false,
	Flag = "AutoFarmMiniBoss",
	Callback = function(Value)
		if scanRunning or tpRunning then return end
		local room = getActiveMiniBossRoom()
		if room then
			teleportToRoom(room)
		else
			createMessage("Mini Boss Room not found!")
		end
		autoFarmMiniBoss = Value
		if Value then
			if AutoFindBestToggle then AutoFindBestToggle:Set(false) end
			if AutoTPGauntletToggle then AutoTPGauntletToggle:Set(false) end
			if AutoTPTitanicToggle then AutoTPTitanicToggle:Set(false) end
		end
	end,
})

local MiniBossButton = MiniBossTab:CreateButton({
	Name = "Teleport to Mini Boss Room",
	Callback = function()
		if scanRunning or tpRunning then return end
		local room = getActiveMiniBossRoom()
		if room then
			teleportToRoom(room)
		else
			createMessage("Mini Boss Room not found!")
		end
	end,
})

local function floorTopOf(p1)
	local Baseplate = p1:FindFirstChild("Baseplate")
	if Baseplate and Baseplate:IsA("BasePart") then
		return Baseplate.Position + Vector3.new(0, Baseplate.Size.Y / 2, 0)
	end
	local v24 = nil
	local n1 = math.huge
	for _, descendant in ipairs(p1:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Size.Y < 4 and descendant.Size.X > 8 and descendant.Size.Z > 8 and n1 > descendant.Position.Y then
			n1 = descendant.Position.Y
			v24 = descendant
		end
	end
	if v24 then
		return v24.Position + Vector3.new(0, v24.Size.Y / 2, 0)
	end
	return p1:GetPivot().Position
end

local function landingSpot(p2)
	local v29 = floorTopOf(p2)
	local AccessPoints = p2:FindFirstChild("AccessPoints")
	if AccessPoints then
		local v2 = nil
		for _, v in ipairs({"ENTER", "ANY", "EXIT"}) do
			v2 = AccessPoints:FindFirstChild(v)
			if v2 then
				break
			end
		end
		if v2 and v2:IsA("BasePart") then
			local Position = p2:GetBoundingBox().Position
			local vector3 = Vector3.new(Position.X - v2.Position.X, 0, Position.Z - v2.Position.Z)
			if vector3.Magnitude > 0.1 then
				local v36 = v2.Position + vector3.Unit * 12
				return Vector3.new(v36.X, v29.Y, v36.Z)
			end
		end
	end
	return v29
end

local function getNearestEgg(hrp)
	local closestEgg = nil
	local minDist = 40
	for _, egg in pairs(CustomEggsCmds.All()) do
		if egg._position then
			local dist = (egg._position - hrp.Position).Magnitude
			if dist < minDist then
				minDist = dist
				closestEgg = egg
			end
		end
	end
	return closestEgg
end

local function getEggDirForRoom(roomModel)
	local sign = roomModel:FindFirstChild("Sign")
	if not sign then
		return nil
	end
	local closestEgg = nil
	local minDist = 50
	for _, egg in pairs(CustomEggsCmds.All()) do
		if egg._position then
			local dist = (egg._position - sign.Position).Magnitude
			if dist < minDist then
				minDist = dist
				closestEgg = egg
			end
		end
	end
	if closestEgg then
		return closestEgg._dir
	end
	return nil
end

local function scanStreamedRooms()
	for _, room in ipairs(GeneratedBackrooms:GetChildren()) do
		local roomUID = room:GetAttribute("RoomUID")
		if roomUID then
			local existing = nil
			for _, r in ipairs(scannedRooms) do
				if r.RoomUID == roomUID then
					existing = r
					break
				end
			end
			local eggName = nil
			if room.Name == "FreeEggRoom" then
				local eggDir = getEggDirForRoom(room)
				if eggDir then
					eggName = eggDir.name or eggDir._id or ""
				end
			end
			local isActive = false
			if room.Name == "GauntletEggRoom" or room.Name == "TitanicEggRoom" then
				isActive = room:FindFirstChild("ChestTimer") ~= nil
			end
			if not existing then
				local floorPos = landingSpot(room) + Vector3.new(0, 4, 0)
				local cf, size = room:GetBoundingBox()
				local roofY = cf.Position.Y + size.Y / 2
				local scanCFrame = CFrame.new(floorPos.X, roofY + 10, floorPos.Z)
				local roomCFrame = CFrame.new(cf.Position + Vector3.new(0, 15, 0))
				table.insert(scannedRooms, {
					Name = room.Name,
					Position = roomCFrame.Position,
					CFrame = roomCFrame,
					ScanCFrame = scanCFrame,
					RoomUID = roomUID,
					RoomID = room:GetAttribute("RoomID"),
					EggMultiplier = tonumber(room:GetAttribute("EggMultiplier")) or 1,
					LockedRoom = room:GetAttribute("LockedRoom") or room:FindFirstChild("LockedDoors") ~= nil,
					DeepRoom = room:GetAttribute("DeepRoom"),
					EggName = eggName,
					IsActive = isActive
				})
				scannedUIDs[roomUID] = true
				print("Scanned: " .. room.Name .. " | UID: " .. tostring(roomUID) .. (eggName and (" | Egg: " .. eggName) or "") .. (isActive and " | ACTIVE" or ""))
			else
				if existing.RoomID == "FreeEggRoom" and existing.EggName == nil and eggName ~= nil then
					existing.EggName = eggName
					print("Updated EggName for Room " .. tostring(roomUID) .. ": " .. eggName)
				end
				if (existing.RoomID == "GauntletEggRoom" or existing.RoomID == "TitanicEggRoom") and existing.IsActive ~= isActive then
					existing.IsActive = isActive
					print("Updated IsActive for " .. existing.RoomID .. " " .. tostring(roomUID) .. ": " .. tostring(isActive))
				end
			end
		end
	end
end

local function runBypassScanner()
	if scanRunning then
		return
	end
	scanRunning = true
	StatusLabel:Set("Status: Scanning...")
	local message = createMessage("Exploring backrooms instance. Please wait...")
	scanStreamedRooms()
	while true do
		local targetAnchor = nil
		for _, roomData in ipairs(scannedRooms) do
			if not visitedAnchors[roomData.RoomUID] then
				targetAnchor = roomData
				break
			end
		end
		if not targetAnchor then
			break
		end
		visitedAnchors[targetAnchor.RoomUID] = true
		local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.Anchored = true
				Network.Fire("RequestStreaming", targetAnchor.ScanCFrame.Position)
				character:PivotTo(targetAnchor.ScanCFrame)
				task.wait(0.35)
				hrp.Anchored = false
			end
		end
		scanStreamedRooms()
	end
	print("Scan complete. Total rooms: " .. #scannedRooms)
	StatusLabel:Set("Status: Scan Complete (" .. #scannedRooms .. " rooms)")
	game.Debris:AddItem(message, 0)
	scanCompleted = true
	if autoTPTitanic then
		local room = getActiveTitanicRoom()
		if room then
			teleportToRoom(room)
		else
			createMessage("Active Titanic Room not found. Server hopping...")
			task.wait(1)
			serverHop()
		end
	elseif autoTPGauntlet then
		local room = getActiveGauntletRoom()
		if room then
			teleportToRoom(room)
		else
			createMessage("Active Gauntlet Room not found. Server hopping...")
			task.wait(1)
			serverHop()
		end
	elseif autoFindBest then
		local room = getBestEggRoom()
		if room then
			teleportToRoom(room)
		else
			createMessage("Best EggRoom not found. Server hopping...")
			task.wait(1)
			serverHop()
		end
	elseif autoFarmMiniBoss then
		local room = getActiveMiniBossRoom()
		if room then
			teleportToRoom(room)
		else
			createMessage("Mini Boss Room not found. Server hopping...")
			task.wait(1)
			serverHop()
		end
	else
		local character = LocalPlayer.Character
		local activeInstance = InstancingCmds.Get()
		if character and activeInstance then
			local enterPosition = activeInstance.enterPosition
			local pos = enterPosition + Vector3.new(0, 3, 0)
			Network.Fire("RequestStreaming", pos)
			task.delay(0.25, function()
				if character.Parent and InstancingCmds.IsInInstance("Backrooms") then
					character:PivotTo(CFrame.new(pos))
				end
			end)
		end
	end
	scanRunning = false
end

task.spawn(function()
	while true do
		task.wait(0.5)
		if autoHatchEnabled and not scanRunning and not tpRunning then
			local character = getCharacter()
			if character then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local egg = getNearestEgg(hrp)
					if egg then
						pcall(function()
							Network.Invoke("CustomEggs_Hatch", egg._uid, EggCmds.GetMaxHatch(egg._dir))
						end)
					end
					for _, roomModel in ipairs(GeneratedBackrooms:GetChildren()) do
						if roomModel.Name == "FreeEggRoom" or roomModel.Name == "GauntletEggRoom" or roomModel.Name == "TitanicEggRoom" then
							local dest = nil
							local offset = Vector3.new(0, 3, 0)
							if roomModel.Name == "FreeEggRoom" then
								dest = roomModel:FindFirstChild("Sign")
								offset = Vector3.new(0, 3, 0)
							elseif roomModel.Name == "GauntletEggRoom" then
								dest = roomModel:FindFirstChild("EggPedestal")
								offset = Vector3.new(0, 2.5, 0)
							elseif roomModel.Name == "TitanicEggRoom" then
								dest = roomModel:FindFirstChild("FeatureAnchor")
								offset = Vector3.new(0, 0, 0)
							end
							if dest then
								local destPos = dest:GetPivot().Position
								local distToDest = (hrp.Position - destPos).Magnitude
								if distToDest < 60 then
									local targetCFrame = dest:GetPivot() + offset
									local distToTarget = (hrp.Position - targetCFrame.Position).Magnitude
									if distToTarget > 8 then
										hrp.Anchored = true
										character:PivotTo(targetCFrame)
										task.wait(0.1)
										hrp.Anchored = false
									end
									break
								end
							end
						end
					end
				end
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(0.85)
		if not scanRunning and scanCompleted and not tpRunning then
			local targetRoom = nil
			if autoTPTitanic then
				targetRoom = getActiveTitanicRoom()
				if not targetRoom then
					createMessage("Active Titanic Room not found. Server hopping...")
					task.wait(1)
					serverHop()
				end
			elseif autoTPGauntlet then
				targetRoom = getActiveGauntletRoom()
				if not targetRoom then
					createMessage("Active Gauntlet Room not found. Server hopping...")
					task.wait(1)
					serverHop()
				end
			elseif autoFindBest then
				targetRoom = getBestEggRoom()
			end
			if targetRoom then
				local character = getCharacter()
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local roomModel = findRoomModel(targetRoom.RoomUID)
					local dest = roomModel and (roomModel:FindFirstChild("Sign") or roomModel:FindFirstChild("EggPedestal") or roomModel:FindFirstChild("Backrooms Egg"))
					if dest then
						local dist = (hrp.Position - dest:GetPivot().Position).Magnitude
						if dist > 60 then
							teleportToRoom(targetRoom)
						end
					else
						teleportToRoom(targetRoom)
					end
				end
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(0.25)
		if autoFarmMiniBoss and not scanRunning and not tpRunning then
			local room = getActiveMiniBossRoom()
			if room then
				local character = getCharacter()
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local roomModel = findRoomModel(room.RoomUID)
					local inRoom = false
					local roomCenter = room.Position
					if roomModel then
						local breakZone = roomModel:FindFirstChild("BREAK_ZONE")
						if breakZone then
							roomCenter = breakZone.Position
						end
						local distToRoom = (hrp.Position - roomCenter).Magnitude
						if distToRoom <= 130 then
							inRoom = true
						end
					end
					if not inRoom then
						teleportToRoom(room)
						task.wait(1)
					else
						local targetBreakable = nil
						local breakables = workspace.__THINGS.Breakables:GetChildren()
						for _, b in ipairs(breakables) do
							local bId = b:GetAttribute("BreakableID")
							if bId == "Daydream Mimic Chest" then
								local bPos = b:GetPivot().Position
								if (bPos - roomCenter).Magnitude < 130 then
									targetBreakable = b
									break
								end
							end
						end
						if not targetBreakable then
							for _, b in ipairs(breakables) do
								local bId = b:GetAttribute("BreakableID")
								if bId == "Daydream Mimic Boss" then
									local bPos = b:GetPivot().Position
									if (bPos - roomCenter).Magnitude < 130 then
										targetBreakable = b
										break
									end
								end
							end
						end
						if targetBreakable then
							local bUID = targetBreakable:GetAttribute("BreakableUID")
							local bPos = targetBreakable:GetPivot().Position
							local humanoid = character:FindFirstChildOfClass("Humanoid")
							if humanoid then
								humanoid:MoveTo(bPos)
							end
							Network.UnreliableFire("Breakables_PlayerDealDamage", bUID)
							local activePets = PlayerPet.GetByPlayer(LocalPlayer)
							for _, pet in pairs(activePets) do
								if pet.cpet then
									pet:SetTarget(targetBreakable)
								end
							end
						end
					end
				end
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(2)
		if not scanRunning then
			pcall(scanStreamedRooms)
		end
	end
end)

local vu = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
	vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
	task.wait(1)
	vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

task.wait(1.5)
runBypassScanner()
Rayfield:LoadConfiguration()
