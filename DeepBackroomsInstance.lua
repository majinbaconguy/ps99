--[[ 
	by @pirategames and @majinbacon
	a PS99 auto farm script for the backrooms update event
	updates at: discord.gg/k2mSRWgfhX
]]--

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local name, version = identifyexecutor()

if name == "Xeno" or name == "Solara" then
	Players.LocalPlayer:Kick("Unsupported")
	return
end

local Network = require(game.ReplicatedStorage.Library.Client.Network)
local InstancingCmds = require(game.ReplicatedStorage.Library.Client.InstancingCmds)
local MiscItem = require(game.ReplicatedStorage.Library.Items.MiscItem)
local EggCmds = require(game.ReplicatedStorage.Library.Client.EggCmds)
local CustomEggsCmds = require(game.ReplicatedStorage.Library.Client.CustomEggsCmds)
local PlayerPet = require(game.ReplicatedStorage.Library.Client.PlayerPet)
local Signal = require(game.ReplicatedStorage.Library.Signal)
local Types = require(game.ReplicatedStorage.Library.Items.Types)
local AbstractItem = require(game.ReplicatedStorage.Library.Items.AbstractItem)
local NumberShorten = require(game.ReplicatedStorage.Library.Functions.NumberShorten)
local InventoryCmds = require(game.ReplicatedStorage.Library.Client.InventoryCmds)
local Save = require(game.ReplicatedStorage.Library.Client.Save)

local seenPets = {}
task.spawn(function()
	while (not Save.Get()) do
		task.wait()
	end
	
	local container = InventoryCmds.Container(Players.LocalPlayer)
	local petType = Types.TypeUnchecked("Pet")
	if container and petType then
		for itemUID, item in pairs(container:All(petType)) do
			local exclusiveLevel = item:GetExclusiveLevel()
			if exclusiveLevel and exclusiveLevel > 3 then
				seenPets[itemUID] = true
			end
		end
	end
end)

local oldCalculate = PlayerPet.CalculateSpeedMultiplier
PlayerPet.CalculateSpeedMultiplier = function(self, ...)
	if _G.InfinitePetSpeed then
		return 100000
	end
	return oldCalculate(self, ...)
end

local localPlayer = Players.LocalPlayer
local enterPosition = nil
local roomsToStore = {
	"DeepCoinRoom1", "DeepCoinRoom2", "DeepCoinRoom3",
	"DeepChestRoom1", "DeepChestRoom2", "DeepChestRoom3",
	"DeepFreeEggRoom1", "DeepFreeEggRoom2", "DeepLockedEggRoom",
	"GameMastersStage"
}
local doneCleaning = false
local httpRequest = request or http_request or (syn and syn.request)

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name = "PS99 Backrooms Script",
	LoadingTitle = "Loading...",
	LoadingSubtitle = "by Pirate Games",
	Theme = "Default",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "DeepBackroomsPS99",
		FileName = "Config"
	},
	KeySystem = false
})

local Tab = Window:CreateTab("Main", 4483362458)
local MiniBossTab = Window:CreateTab("Boss Chest", 4483362458)
local MiscTab = Window:CreateTab("Misc", 4483362458)
local StatusLabel = Tab:CreateLabel("Status: Idle")

_G.ScannedRooms = {}
_G.ScannedRoomsMap = {}
_G.VistedRooms = {}
_G.IsScanning = false
_G.Teleporting = false
_G.AutoHatch = false
_G.AutoTPBestEgg = false
_G.AutoMiniBoss = false
_G.AutoTPLockedEgg = false
_G.AutoTPAnomaly = false
_G.InfinitePetSpeed = false
_G.AutoTapper = false

_G.SelectedLockedEggMult = "Any"

local EggDropdown
local FreeEggTPButton
local AutoBestEgg
local LockedEggTarget
local LockedEggTPButton
local AutoLockedEgg
local AnomalyTPButton
local AutoAnomaly
local AutoHatch
local DisableHatchAnimation
local BreakablesRoomTPButton
local DeepChestRoomTPButton
local BossTPButton
local AutoFarmBoss
local RejoinButton
local ServerHopButton
local InfPetSpeedButton
local AutoTapperToggle

local function getCharacter()
	return localPlayer.Character or localPlayer.CharacterAdded:Wait()
end

local character = getCharacter()
if character then
	local enterPart = workspace:WaitForChild("__THINGS")
		:WaitForChild("Instances")
		:WaitForChild("Backrooms")
		:WaitForChild("Teleports")
		:WaitForChild("Enter")
	character:PivotTo(enterPart.CFrame)
end

local function createMessage(msg)
	if workspace:FindFirstChildOfClass("Message") then
		return
	end
	local message = Instance.new("Message", workspace)
	message.Text = msg
	return message
end

local function getThumbnailUrl(iconId)
	if not iconId or not httpRequest then
		warn("no http/icon")
		return nil
	end

	local default = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. iconId .. "&width=420&height=420&format=png"

	local success, response = pcall(function()
		return httpRequest({
			Url = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. iconId .. "&size=420x420&format=Png&isCircular=false",
			Method = "GET"
		})
	end)

	if not success or response.StatusCode ~= 200  then
		warn("NO DATA FOR IMAGE 111")
		return default
	end

	local decoded = HttpService:JSONDecode(response.Body)
	if not decoded or not decoded.data then
		warn("NO DATA FOR IMAGE 222")
		return default
	end

	local imageUrl = decoded.data[1].imageUrl
	if not imageUrl then
		warn("NO DATA FOR IMAGE 333")
		return default
	end

	return imageUrl
end

local function sendWebhook(data)
	if getgenv().webhook == "" or getgenv().webhook == nil then
		warn("NO WEBHOOK!!")
		return
	end

	if not httpRequest then
		warn("HOLY BAD 111")
		return
	end

	local body = HttpService:JSONEncode(data)
	if not body then
		warn("HOLY BAD 222")
		return
	end

	local success, response = pcall(function()
		return httpRequest({
			Url = getgenv().webhook,
			Method = "POST",
			Headers = {	["Content-Type"] = "application/json" },
			Body = body
		})
	end)

	if not success then
		warn("HOLY BAD 333", tostring(response))
	end
end

local function serverHop(reason)
	local message = createMessage(reason)

	local success = pcall(function()
		local api = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"

		local function list(cursor)
			local raw = game:HttpGet(api .. ((cursor and "&cursor=" .. cursor) or ""))
			return HttpService:JSONDecode(raw)
		end

		local servers = list()
		for _, server in ipairs(servers.data) do
			if server.playing < server.maxPlayers and server.id ~= game.JobId then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, localPlayer)
				return true
			end
		end
	end)

	if not success then
		TeleportService:Teleport(game.PlaceId, localPlayer)
	else
		game.Debris:AddItem(message, 10)
	end
end

if _G.ExecutedScript ~= nil then
	createMessage("Script was re-executed rejoining the game...")
	task.delay(2, function()
		TeleportService:Teleport(game.PlaceId, game.Players.LocalPlayer)
	end)
	return
end

_G.ExecutedScript = true

local function getGeneratedBackrooms()
	local container = workspace:FindFirstChild("__THINGS"):FindFirstChild("__INSTANCE_CONTAINER")
	if not container then
		return nil
	end

	local active = container:FindFirstChild("Active")
	if not active then
		return nil
	end

	local backrooms = active:WaitForChild("Backrooms", 3)
	if not backrooms then
		return nil
	end

	return backrooms:FindFirstChild("GeneratedBackrooms")
end

local function findRoomDataByUID(roomUID)
	local roomData = _G.ScannedRoomsMap[roomUID]
	if roomData then
		return roomData
	end
	return nil
end

local function findRoomModelByUID(roomUID)
	local folder = getGeneratedBackrooms()
	if not folder then 
		return nil 
	end

	for _, roomModel in ipairs(folder:GetChildren()) do
		if roomModel:GetAttribute("RoomUID") == roomUID then
			return roomModel
		end
	end

	return nil
end

local function getNearestEgg(character)
	if typeof(character) ~= "Model" then
		return
	end

	local closestEgg = nil
	local minDist = 40

	for _, egg in pairs(CustomEggsCmds.All()) do
		if egg._position then
			local dist = (egg._position - character:GetPivot().Position).Magnitude
			if dist < minDist then
				minDist = dist
				closestEgg = egg
			end
		end
	end

	return closestEgg
end

local function isPlayerInRoom(roomData)
	if roomData == nil then 
		return false 
	end

	local character = getCharacter()
	if not character then 
		return false 
	end

	local roomCFrame, roomSize = roomData.Model:GetBoundingBox()
	if not roomCFrame or not roomSize then
		return false
	end

	local localPoint = roomCFrame:PointToObjectSpace(character:GetPivot().Position)
	local limitX = (roomSize.X / 2) + 20
	local limitY = (roomSize.Y / 2) + 35
	local limitZ = (roomSize.Z / 2) + 20

	return math.abs(localPoint.X) <= limitX
		and math.abs(localPoint.Y) <= limitY
		and math.abs(localPoint.Z) <= limitZ
end

local function getBestEggRoom()
	local bestRoom = nil
	local maxMult = -1

	for _, room in ipairs(_G.ScannedRooms) do
		if string.match(room.Id, "DeepFreeEggRoom") ~= nil and room.EggMultiplier ~= nil then
			if room.EggMultiplier > maxMult then
				maxMult = room.EggMultiplier
				bestRoom = room
			end
		end
	end

	return bestRoom
end

local function getBestLockedEggRoom()
	local bestRoom = nil
	local maxMult = -1
	local targetMult = (_G.SelectedLockedEggMult and _G.SelectedLockedEggMult ~= "Any")
		and tonumber(string.match(_G.SelectedLockedEggMult, "%d+"))
		or nil

	for _, room in ipairs(_G.ScannedRooms) do
		if room.Id == "DeepLockedEggRoom" and room.EggMultiplier ~= nil then
			if (not room.ExpireTime) or (room.ExpireTime - workspace:GetServerTimeNow() > 0) then
				local isMatch = (not targetMult) or room.EggMultiplier >= targetMult

				if isMatch and room.EggMultiplier > maxMult then
					maxMult = room.EggMultiplier
					bestRoom = room
				end
			end
		end
	end

	return bestRoom
end

local function keyCheck()
	local keyItem = MiscItem("Deep Backrooms Crayon Key")
	if keyItem and keyItem:HasAny() then
		return true
	end
	return false
end

local function UnlockRoom(roomUID)
	if _G.IsScanning == true then
		return
	end

	local character = getCharacter()
	if not character then
		return
	end

	local ownsKey = keyCheck()
	if not ownsKey then
		return
	end

	local activeInstance = InstancingCmds.Get()
	if not activeInstance then
		return
	end

	local roomData = findRoomDataByUID(roomUID)
	if not roomData then 
		warn("NO ROOM DATA 2")
		return 
	end

	local roomModel = roomData.Model
	local lockedDoors = roomModel:FindFirstChild("LockedDoors")
	if not lockedDoors then 
		warn("IS NOT A LOCKED ROOM")
		return 
	end

	local lockedPart = nil
	for _, child in ipairs(lockedDoors:GetChildren()) do
		local lock = child:FindFirstChild("Lock")
		if lock and lock.Transparency < 1 then
			lockedPart = lock
			break
		end
	end

	if not lockedPart then
		warn("doesnt exist lock part")
		return 
	end

	character:PivotTo(CFrame.new(lockedPart.Position))
	activeInstance:FireCustom("AbstractRoom_FireServer", roomUID, "UnlockDoors")
end

local function TeleportToRoom(roomUID, isScanning)
	if _G.Teleporting then
		return
	end

	_G.Teleporting = true

	local character = getCharacter()
	if not character then
		_G.Teleporting = false
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		_G.Teleporting = false
		return
	end

	local roomData = findRoomDataByUID(roomUID)
	if not roomData then
		warn("NO ROOM DATA")
		_G.Teleporting = false
		return
	end

	local roomModel = roomData.Model
	local roomId = roomData.Id
	local pos = roomData.Position

	local centerCF = roomModel:GetBoundingBox()

	local forceField = Instance.new("ForceField")
	forceField.Visible = false
	forceField.Parent = character

	Network.Fire("RequestStreaming", pos)

	rootPart.Anchored = true
	character:PivotTo(centerCF + Vector3.new(0, 10, 0))

	task.delay(2.5, function()
		if forceField and forceField.Parent then 
			forceField:Destroy() 
		end

		if (not isScanning) then
			rootPart.Anchored = false
		end
	end)

	if (not isScanning) then
		task.wait(1.5)

		local targetObj = roomModel:FindFirstChild("Sign")
			or roomModel:FindFirstChild("Backrooms Egg")
			or roomModel:FindFirstChild("BillboardAdornee")
			or roomModel.PrimaryPart
			or roomModel:FindFirstChildWhichIsA("BasePart", true)

		character:PivotTo((targetObj and targetObj.CFrame or CFrame.new(pos)) + Vector3.new(0, 15, 0))

		if roomId == "DeepLockedEggRoom" then
			local activeInstance = InstancingCmds.Get()
			if activeInstance then
				local ok, playerDataList = pcall(function()
					return activeInstance:InvokeCustom("AbstractRoom_GetPlayerData")
				end)

				if not ok then
					warn("FAILED TO GET PLR DATA", playerDataList)
					return
				end

				for _, roomInfo in ipairs(playerDataList) do
					if roomInfo.uid == roomUID then
						local expireTime = roomInfo.data and roomInfo.data.UnlockExpireTimestamp or nil
						if expireTime then
							roomData.ExpireTime = expireTime
						end
						break
					end
				end
			else
				warn("not in instance??")
			end
		end

		if roomId == "DeepLockedEggRoom" or roomId == "GameMastersStage" then
			UnlockRoom(roomUID)
		end

		task.wait(0.3)

		character:PivotTo((targetObj and targetObj.CFrame or CFrame.new(pos)) + Vector3.new(0, 15, 0))
	end

	_G.Teleporting = false
end

local function CleanupWalls()
	local folder = getGeneratedBackrooms()
	if not folder then
		doneCleaning = true
		return
	end

	if doneCleaning then
		return
	end

	for _, room in ipairs(folder:GetChildren()) do
		if room.Name == "Walls" then
			local children = room:GetChildren()

			for i = 1, #children do
				children[i]:Destroy()

				if i % 15 == 0 then
					RunService.Heartbeat:Wait()
				end
			end

			room:Destroy()
		end
	end

	doneCleaning = true
end

local function TPtoSpawn()
	local character = getCharacter()
	if not character then
		return
	end

	if typeof(enterPosition) ~= "Vector3" then
		return
	end

	Network.Fire("RequestStreaming", enterPosition)
	character:PivotTo(CFrame.new(enterPosition) + Vector3.new(0, 5, 0))
end

local function Scan()
	if _G.IsScanning then
		return
	end

	_G.IsScanning = true

	local character = getCharacter()
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local total = 0
	local message = createMessage("Exploring the backrooms! Please wait...")
	StatusLabel:Set("Status: Working...")

	local folder = getGeneratedBackrooms()
	if not folder then
		repeat
			task.wait(0.5)
			folder = getGeneratedBackrooms()
			warn("WAITING...")
		until folder and #folder:GetChildren() > 0
	end

	local deepSpawnRoom = folder:WaitForChild("DeepSpawnRoom", 3)
	if deepSpawnRoom then
		local spawnLocation = deepSpawnRoom:FindFirstChild("DEEP_SPAWN_LOCATION")
		if spawnLocation then
			enterPosition = spawnLocation.Position
			warn("SAVED", enterPosition)
			Network.Fire("RequestStreaming", enterPosition)
			character:PivotTo(CFrame.new(enterPosition) + Vector3.new(0, 5, 0))
		end
	end

	task.spawn(CleanupWalls)

	repeat
		message.Text = "CLEANING UP DEBRIS..."
		task.wait(0.5)
	until doneCleaning == true

	message.Text = "Exploring the backrooms! Please wait..."

	local function processRoom(room)
		if room:GetAttribute("DeepRoom") ~= true then
			return
		end

		local roomUID = room:GetAttribute("RoomUID")
		if not roomUID then
			return
		end

		local exists = _G.ScannedRoomsMap[roomUID]
		if not exists then
			local roomId = room:GetAttribute("RoomID")
			local roomCFrame = room:GetPivot()
			local mult = room:GetAttribute("EggMultiplier") or 0

			local roomData = {
				uid = roomUID,
				Id = roomId,
				Model = room,
				CFrame = roomCFrame,
				Position = roomCFrame.Position,
				EggMultiplier = mult > 0 and mult or nil
			}

			_G.ScannedRoomsMap[roomUID] = roomData
			table.insert(_G.ScannedRooms, roomData)
			total+=1

			StatusLabel:Set("Status: Scanned " .. #_G.ScannedRooms .. " rooms")

			if roomId == "DeepLockedEggRoom" or string.match(roomId, "DeepFreeEggRoom") ~= nil then
				warn(roomId .. " with " .. mult .. "x mult")
			elseif roomId == "GameMastersStage" then
				warn("Boss room", roomId)
			else
				print(roomId)
			end
		end
	end

	local function run()
		local folder = getGeneratedBackrooms()
		if not folder then
			return
		end

		local rooms = folder:GetChildren()
		for i = 1, #rooms do
			processRoom(rooms[i])
		end
	end

	run()

	while true do
		if #_G.ScannedRooms >= 400 then
			break
		end

		local character = getCharacter()
		if not character then
			continue
		end

		if _G.Teleporting == true then
			continue
		end

		local nearestRoom = nil
		local nearestDist = math.huge

		for i = 1, #_G.ScannedRooms do
			local room = _G.ScannedRooms[i]

			if _G.VistedRooms[room.uid] == nil then
				local dist = (room.Position - character:GetPivot().Position).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestRoom = room
				end
			end
		end

		if not nearestRoom then
			warn("No more unvisited rooms.")
			break
		end

		_G.VistedRooms[nearestRoom.uid] = true
		TeleportToRoom(nearestRoom.uid, true)
		task.wait(0.5)
		run()
	end

	table.clear(_G.VistedRooms)

	for i = 1, #_G.ScannedRooms do
		local room = _G.ScannedRooms[i]
		if room then
			local keep = table.find(roomsToStore, room.Id) ~= nil
			if not keep then
				table.remove(_G.ScannedRooms, i)
				_G.ScannedRoomsMap[room.uid] = nil
			end
		end
	end

	TPtoSpawn()
	rootPart.Anchored = false
	StatusLabel:Set("Status: Scan Complete! Scanned " .. total .. " rooms! with " .. #_G.ScannedRooms .. " valid rooms!")
	game.Debris:AddItem(message, 0)
	_G.IsScanning = false

	warn("Scan finished!")
end

local function canDoAction()
	return (not _G.IsScanning) and (not _G.Teleporting)
end

local function isAutoAnomlyActive()
	local anomalyActive = workspace:GetAttribute("BackroomsAnomalyActive")
	local endsAt = workspace:GetAttribute("BackroomsAnomalyEndsAt")

	return _G.AutoTPAnomaly and anomalyActive == true and type(endsAt) == "number" and endsAt >= workspace:GetServerTimeNow()
end

FreeEggTPButton = Tab:CreateButton({
	Name = "Teleport to Best Free Egg Room!",
	Callback = function()
		if (not canDoAction()) then
			return
		end

		local room = getBestEggRoom()
		if room then
			TeleportToRoom(room.uid)
		else
			Rayfield:Notify({
				Title = "No Room Found",
				Content = "Could not find any BEST FREE EGG ROOM!",
				Duration = 4,
				Image = 4483362458
			})
		end
	end,
})

AutoBestEgg = Tab:CreateToggle({
	Name = "Auto TP To Best Egg",
	CurrentValue = false,
	Flag = "AutoTPBestEgg",
	Callback = function(value)
		if (not canDoAction()) then
			return
		end

		if value then
			if AutoFarmBoss ~= nil and _G.AutoMiniBoss == true then
				AutoFarmBoss:Set(false)
			end
			if AutoLockedEgg ~= nil and _G.AutoTPLockedEgg == true then
				AutoLockedEgg:Set(false)
			end
		end

		_G.AutoTPBestEgg = value
	end,
})

LockedEggTarget = Tab:CreateDropdown({
	Name = "Locked Egg Mult Target!",
	Options = {"Any", "50x", "75x", "100x"},
	CurrentOption = {"Any"},
	MultipleOptions = false,
	Flag = "EggTarget",
	Callback = function(options)
		if (not canDoAction()) then
			return
		end

		_G.SelectedLockedEggMult = (typeof(options) == "table" and options[1] or options)
	end,
})

LockedEggTPButton = Tab:CreateButton({
	Name = "Teleport to Locked Egg Egg Room!",
	Callback = function()
		if (not canDoAction()) then
			return
		end

		local room = getBestLockedEggRoom()
		if room then
			TeleportToRoom(room.uid)
		else
			Rayfield:Notify({
				Title = "No Room Found",
				Content = "Could not find LOCKED EGG ROOM!",
				Duration = 4,
				Image = 4483362458
			})
		end
	end,
})

AutoLockedEgg = Tab:CreateToggle({
	Name = "Auto TP To Locked Egg",
	CurrentValue = false,
	Flag = "AutoTPLockedEgg",
	Callback = function(value)
		if (not canDoAction()) then
			return
		end

		if value then
			if AutoFarmBoss ~= nil and _G.AutoMiniBoss == true then
				AutoFarmBoss:Set(false)
			end
			if AutoBestEgg ~= nil and _G.AutoTPBestEgg == true then
				AutoBestEgg:Set(false)
			end
		end

		_G.AutoTPLockedEgg = value
	end,
})

AnomalyTPButton = Tab:CreateButton({
	Name = "Teleport to Active Anomaly! (250x Egg)",
	Callback = function()
		if (not canDoAction()) then
			return
		end

		local character = getCharacter()
		if not character then
			return
		end

		local isActive = workspace:GetAttribute("BackroomsAnomalyActive")
		local endsAt = workspace:GetAttribute("BackroomsAnomalyEndsAt")

		if not isActive or (type(endsAt) == "number" and workspace:GetServerTimeNow() > endsAt) then
			Rayfield:Notify({
				Title = "No Anomly",
				Content = "No Active Anomaly in this server!",
				Duration = 4,
				Image = 4483362458
			})
			return
		end

		local pos = workspace:GetAttribute("BackroomsAnomalyPos")
		if not pos then
			return
		end

		Network.Fire("RequestStreaming", pos)
		character:PivotTo(CFrame.new(pos) + Vector3.new(0, 5, 0))
	end,
})

AutoAnomaly = Tab:CreateToggle({
	Name = "Auto TP To Active Anomly (250x Egg)",
	CurrentValue = false,
	Flag = "AutoTPAnomaly",
	Callback = function(value)
		if (not canDoAction()) then
			return
		end

		_G.AutoTPAnomaly = value
	end,
})

AutoHatch = Tab:CreateToggle({
	Name = "Auto Hatch Eggs",
	CurrentValue = false,
	Flag = "AutoHatch",
	Callback = function(value)
		if (not canDoAction()) then
			return
		end
		_G.AutoHatch = value
	end,
})

DisableHatchAnimation = Tab:CreateToggle({
	Name = "Disable Hatch Animation",
	CurrentValue = false,
	Flag = "DisableHatchAnimation",
	Callback = function(value)
		if (not canDoAction()) then
			return
		end

		if workspace.CurrentCamera:FindFirstChild("Eggs") or workspace.CurrentCamera:FindFirstChild("Pets") then
			return
		end

		local scripts = localPlayer:WaitForChild("PlayerScripts")
		local scriptInstance = nil
		for _, descendant in ipairs(scripts:GetDescendants()) do
			if descendant.Name == "Egg Opening Frontend" then
				scriptInstance = descendant
				break
			end
		end

		if not scriptInstance then
			return
		end

		scriptInstance.Enabled = (not value)
	end,
})

BreakablesRoomTPButton = MiniBossTab:CreateButton({
	Name = "Teleport to nearest Breakable Room!",
	Callback = function()
		if (not canDoAction()) then
			return
		end

		local found = false
		for _, r in ipairs(_G.ScannedRooms) do
			if string.match(r.Id, "DeepCoinRoom") ~= nil then
				found = true
				TeleportToRoom(r.uid)
				task.wait(0.3)
				local roomModel = r.Model
				local breakZone = roomModel:FindFirstChild("BREAK_ZONE")
				if breakZone then
					local character = getCharacter()
					if character then
						character:PivotTo(CFrame.new(breakZone.Position) + Vector3.new(0, 5, 0))
					end
				end
				break
			end
		end

		if not found then
			Rayfield:Notify({
				Title = "No Breakable Room",
				Content = "Could not find any scanned Breakable Room",
				Duration = 4,
				Image = 4483362458
			})
		end
	end,
})

DeepChestRoomTPButton = MiniBossTab:CreateButton({
	Name = "Teleport to nearest MINI Chest Room!",
	Callback = function()
		if (not canDoAction()) then
			return
		end

		local found = false
		for _, r in ipairs(_G.ScannedRooms) do
			if string.match(r.Id, "DeepChestRoom") ~= nil then
				found = true
				TeleportToRoom(r.uid)
				task.wait(0.3)
				local roomModel = r.Model
				local breakZone = roomModel:FindFirstChild("BREAK_ZONE")
				if breakZone then
					local character = getCharacter()
					if character then
						character:PivotTo(CFrame.new(breakZone.Position) + Vector3.new(0, 5, 0))
					end
				end
				break
			end
		end

		if not found then
			Rayfield:Notify({
				Title = "No Breakable Room",
				Content = "Could not find any scanned MINI Chest Room",
				Duration = 4,
				Image = 4483362458
			})
		end
	end,
})

BossTPButton = MiniBossTab:CreateButton({
	Name = "Teleport to Boss Room!",
	Callback = function()
		if (not canDoAction()) then
			return
		end

		local found = false
		for _, r in ipairs(_G.ScannedRooms) do
			if r.Id == "GameMastersStage" then
				found = true
				TeleportToRoom(r.uid)
				task.wait(0.3)
				local roomModel = r.Model
				local breakZone = roomModel:FindFirstChild("BREAK_ZONE")
				if breakZone then
					local character = getCharacter()
					if character then
						character:PivotTo(CFrame.new(breakZone.Position) + Vector3.new(0, 5, 0))
					end
				end
				break
			end
		end

		if not found then
			Rayfield:Notify({
				Title = "No Boss Room",
				Content = "Could not find any scanned Boss Room",
				Duration = 4,
				Image = 4483362458
			})
		end
	end,
})

AutoFarmBoss = MiniBossTab:CreateToggle({
	Name = "Auto Farm Boss Room",
	CurrentValue = false,
	Flag = "AutoFarmBoss",
	Callback = function(value)
		if (not canDoAction()) then
			return
		end

		if value then
			if AutoHatch ~= nil and _G.AutoHatch == true then
				AutoHatch:Set(false)
			end
			if AutoBestEgg ~= nil and _G.AutoTPBestEgg == true then
				AutoBestEgg:Set(false)
			end
		end

		_G.AutoMiniBoss = value
	end,
})

InfPetSpeedButton = MiscTab:CreateToggle({
	Name = "Infinite Pet Speed",
	CurrentValue = false,
	Flag = "InfinitePetSpeed",
	Callback = function(value)
		_G.InfinitePetSpeed = value
	end,
})

AutoTapperToggle = MiscTab:CreateToggle({
	Name = "Auto Tapper",
	CurrentValue = false,
	Flag = "AutoTapper",
	Callback = function(value)
		if (not canDoAction()) then
			return
		end

		_G.AutoTapper = value
	end,
})

RejoinButton = MiscTab:CreateButton({
	Name = "Rejoin",
	Callback = function()
		TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
	end,
})

ServerHopButton = MiscTab:CreateButton({
	Name = "ServerHop",
	Callback = function()
		serverHop("Server Hopping...")
	end,
})

InfiniteYieldButton = MiscTab:CreateButton({
	Name = "Infinite Yield",
	Callback = function()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
	end,
})

task.spawn(function()
	while true do
		task.wait(1)

		if not _G.AutoTPBestEgg then
			continue
		end

		if isAutoAnomlyActive() then
			continue
		end

		if not canDoAction() then
			continue
		end

		local character = getCharacter()
		if not character then
			continue
		end

		local room = getBestEggRoom()
		if room then
			local isInRoom = isPlayerInRoom(room)
			if (not isInRoom) then
				TeleportToRoom(room.uid)
				task.wait(2)
			end
		else
			serverHop("No Best Egg in this server. hopping...")
			task.wait(5)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(1)

		if not _G.AutoTPLockedEgg then
			continue
		end

		if isAutoAnomlyActive() then
			continue
		end

		if not canDoAction() then
			continue
		end

		local character = getCharacter()
		if not character then
			continue
		end

		local room = getBestLockedEggRoom()
		if room then
			local isInRoom = isPlayerInRoom(room)
			if (not isInRoom) then
				TeleportToRoom(room.uid)
				task.wait(2)
			end
		else
			serverHop("No Best Egg in this server. hopping...")
			task.wait(5)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(1)

		if not _G.AutoTPAnomaly then
			continue
		end

		if not canDoAction() then
			continue
		end

		local character = getCharacter()
		if not character then
			continue
		end

		local isActive = workspace:GetAttribute("BackroomsAnomalyActive")
		local endsAt = workspace:GetAttribute("BackroomsAnomalyEndsAt")

		if not isActive or (type(endsAt) == "number" and workspace:GetServerTimeNow() > endsAt) then
			continue
		end

		local pos = workspace:GetAttribute("BackroomsAnomalyPos")
		if not pos then
			continue
		end

		local distance = (character:GetPivot().Position - pos).Magnitude
		if distance > 40 then
			Network.Fire("RequestStreaming", pos)
			character:PivotTo(CFrame.new(pos) + Vector3.new(0, 5, 0))
			task.wait(2)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(0.25)

		if not _G.AutoHatch then
			continue
		end

		if not canDoAction() then
			continue
		end

		local character = getCharacter()
		if not character then
			continue
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			continue
		end

		local egg = getNearestEgg(rootPart)
		if egg then
			pcall(function()
				Network.Invoke("CustomEggs_Hatch", egg._uid, EggCmds.GetMaxHatch(egg._dir))
			end)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(1)

		if not _G.AutoMiniBoss then
			continue
		end

		if isAutoAnomlyActive() then
			continue
		end

		if not canDoAction() then
			continue
		end

		local character = getCharacter()
		if not character then
			continue
		end

		local targetRoom = nil
		for _, r in ipairs(_G.ScannedRooms) do
			if r.Id == "GameMastersStage" then
				targetRoom = r
				break
			end
		end

		if targetRoom then
			local uid = targetRoom.uid
			local roomModel = targetRoom.Model
			local pos = targetRoom.Position

			local breakZone = roomModel:FindFirstChild("BREAK_ZONE")
			if breakZone then
				pos = breakZone:GetPivot().Position
			end

			local isInRoom = isPlayerInRoom(targetRoom)
			if (not isInRoom) then
				TeleportToRoom(uid)
				task.wait(2)
			else
				local targetBreakable = nil
				local breakables = workspace:FindFirstChild("__THINGS"):FindFirstChild("Breakables"):GetChildren()

				for _, breakable in ipairs(breakables) do
					local breakableId = breakable:GetAttribute("BreakableID")
					if breakableId == "Daydream Mimic Chest2" then
						local breakablePos = breakable:GetPivot().Position
						if (breakablePos - pos).Magnitude < 130 then
							targetBreakable = breakable
							break
						end
					end
				end

				if not targetBreakable then
					for _, breakable in ipairs(breakables) do
						local breakableId = breakable:GetAttribute("BreakableID")
						if breakableId == "Daydream Mimic Boss2" then
							local breakablePos = breakable:GetPivot().Position
							if (breakablePos - pos).Magnitude < 130 then
								targetBreakable = breakable
								break
							end
						end
					end
				end

				if targetBreakable then
					local breakableUID = targetBreakable:GetAttribute("BreakableUID")
					local breakablePos = targetBreakable:GetPivot().Position

					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid:MoveTo(breakablePos)
					end

					Network.UnreliableFire("Breakables_PlayerDealDamage", breakableUID)

					local activePets = PlayerPet.GetByPlayer(localPlayer)
					for _, pet in pairs(activePets) do
						if pet.cpet then
							pet:SetTarget(targetBreakable)
						end
					end
				end
			end
		else
			serverHop("No Boss Room in this server. hopping...")
			task.wait(5)
		end 
	end
end)

task.spawn(function()
	while true do
		task.wait(0.1)

		if not _G.AutoTapper then
			continue
		end

		local character = getCharacter()
		if not character then
			continue
		end

		local breakables = workspace:FindFirstChild("__THINGS"):FindFirstChild("Breakables"):GetChildren()
		local tapRange = 150
		local nearestDistance = math.huge
		local nearestBreakableUID = nil

		for _, breakable in ipairs(breakables) do
			local uid = breakable:GetAttribute("BreakableUID")
			if uid and (not breakable:GetAttribute("ManualDamage")) and (not breakable:GetAttribute("DisableDamage")) then
				local breakablePos = breakable:GetPivot().Position
				local distance = (breakablePos - character:GetPivot().Position).Magnitude

				if tapRange > distance and distance < nearestDistance then
					nearestDistance = distance
					nearestBreakableUID = uid
				end
			end
		end

		if nearestBreakableUID then
			Signal.Fire("AutoClicker_Nearby", nearestBreakableUID)
		end
	end
end)

Network.Fired("Items: Update"):Connect(function(player, packet, currencyPacket)
	if not packet or not packet.set then
		return
	end

	for classKey, items in pairs(packet.set) do
		if classKey == "Pet" then
			local classType = Types.TypeUnchecked(classKey)
			if classType then
				for itemUID, itemData in pairs(items) do
					if not seenPets[itemUID] then
						local item = classType:From(itemData)
						item:SetUID(itemUID)

						local exclusiveLevel = item:GetExclusiveLevel()
						if exclusiveLevel > 3 then
							seenPets[itemUID] = true

							local itemName = item:GetName()
							local itemIcon = item:GetIcon()
							local exists = item:GetExistCount()
							local rap = item:GetRAP()
							local thumbnailUrl = getThumbnailUrl(string.match(itemIcon, "%d+"))

							local embed = {
								title = "||" .. localPlayer.Name .. "|| just hatched a " .. itemName .. "!",
								color = 16753920,
								fields = {
									{
										name = "Exists",
										value = tostring(NumberShorten(exists)),
										inline = true
									},
									{
										name = "RAP",
										value = tostring(NumberShorten(rap)),
										inline = true
									}
								},
								footer = { text = "discord.gg/k2mSRWgfhX" },
								timestamp = DateTime.now():ToIsoDate()
							}

							if thumbnailUrl then
								embed.thumbnail = { url = thumbnailUrl }
							end

							local content = (getgenv().discordId == "" or getgenv().discordId == nil)
								and "@everyone"
								or 	"<@" .. getgenv().discordId .. ">"		

							sendWebhook({
								username = "Pirate Games Logger",
								avatar_url = "https://raw.githubusercontent.com/BuildIntoPirates/ps99/main/channels4_profile.jpg",
								content = content,
								embeds = { embed }
							})
						end
					end
				end
			end
		end
	end
end)

localPlayer.Idled:Connect(function()
	-- ANTI AFK
	Signal.Fire("ResetIdleTimer")
	VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
	task.wait(1)
	VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

task.wait(5) -- DO NOT REMOVE
Scan()
Rayfield:LoadConfiguration()
