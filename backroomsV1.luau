if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

if typeof(require) ~= "function" then
	Players.LocalPlayer:Kick("not supported")
	return
end

local Network = require(game.ReplicatedStorage.Library.Client.Network)
local InstancingCmds = require(game.ReplicatedStorage.Library.Client.InstancingCmds)
local MiscItem = require(game.ReplicatedStorage.Library.Items.MiscItem)
local EggCmds = require(game.ReplicatedStorage.Library.Client.EggCmds)
local CustomEggsCmds = require(game.ReplicatedStorage.Library.Client.CustomEggsCmds)
local PlayerPet = require(game.ReplicatedStorage.Library.Client.PlayerPet)
local InventoryCmds = require(game.ReplicatedStorage.Library.Client.InventoryCmds)
local CurrencyCmds = require(game.ReplicatedStorage.Library.Client.CurrencyCmds)

local localPlayer = Players.LocalPlayer

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
		FolderName = "BackroomsPS99",
		FileName = "Config"
	},
	KeySystem = false
})

local Tab = Window:CreateTab("Main", 4483362458)
local MiniBossTab = Window:CreateTab("Mini Boss", 4483362458)
local StatusLabel = Tab:CreateLabel("Status: Idle")

_G.ScannedRooms = {}
_G.VistedRooms = {}
_G.IsScanning = false
_G.Teleporting = false
_G.AutoHatch = false
_G.SelectedEgg = "Any"
_G.AutoTPBestEgg = false
_G.AutoTPGauntlet = false
_G.AutoTPTitanic = false
_G.AutoMiniBoss = false

_G.CurrentGauntletRoom = nil
_G.CurrentTitanicRoom = nil

local EggDropdown
local FreeEggTPButton
local AutoBestEgg
local GauntletTPButton
local TitanicTPButton
local AutoGauntletEggToggle
local AutoTitanicEggToggle
local AutoHatch
local DisableHatchAnimation
local MiniBossTPButton
local AutoFarmMiniBoss
local BreakablesRoomTPButton

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

local function serverHop(reason)
	local message = createMessage(reason)

	local success = pcall(function()
		local api = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
		local function list(cursor)
			local Raw = game:HttpGet(api .. ((cursor and "&cursor=" .. cursor) or ""))
			return HttpService:JSONDecode(Raw)
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

local activeFolder = workspace:WaitForChild("__THINGS")
	:WaitForChild("__INSTANCE_CONTAINER")
	:WaitForChild("Active")

local backroomsFolder = activeFolder:WaitForChild("Backrooms")
local GeneratedBackrooms = backroomsFolder:WaitForChild("GeneratedBackrooms")

local function findRoomDataByUID(roomUID)
	for _, roomData in ipairs(_G.ScannedRooms) do
		if roomData.uid == roomUID then
			return roomData
		end
	end
	return nil
end

local function findRoomModelByUID(roomUID)
	for _, roomModel in ipairs(GeneratedBackrooms:GetChildren()) do
		if roomModel:GetAttribute("RoomUID") == roomUID then
			return roomModel
		end
	end
	return nil
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

local function getBestEggRoom()
	local bestRoom = nil
	local maxMult = -1
	for _, room in ipairs(_G.ScannedRooms) do
		if room.Id == "FreeEggRoom" and room.EggMultiplier then
			local matchesEgg = _G.SelectedEgg == "Any"
				or (room.EggName and string.find(string.lower(room.EggName), string.lower(_G.SelectedEgg), 1, true) ~= nil)
			if matchesEgg and room.EggMultiplier > maxMult then
				maxMult = room.EggMultiplier
				bestRoom = room
			end
		end
	end
	return bestRoom
end

local function UnlockRoom(roomUID)
	local character = getCharacter()
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local roomModel = findRoomModelByUID(roomUID)
	if not roomModel then 
		return 
	end

	local LockedDoors = roomModel:FindFirstChild("LockedDoors")
	if not LockedDoors then 
		return 
	end

	local isLocked = false
	for _, child in ipairs(LockedDoors:GetChildren()) do
		local Lock = child:FindFirstChild("Lock")
		if Lock and Lock.Transparency < 0.5 then
			rootPart:PivotTo(Lock:GetPivot())
			isLocked = true
			break
		end
	end

	if not isLocked then 
		return 
	end

	local keyItem = MiscItem("Backrooms Crayon Key")
	if keyItem and keyItem:HasAny() then
		local activeInstance = InstancingCmds.Get()
		if activeInstance then
			activeInstance:FireCustom("AbstractRoom_FireServer", roomUID, "UnlockDoors")
		end
	end
end

local function TeleportToRoom(roomModel, ignore)
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

	local roomUID = roomModel:GetAttribute("RoomUID")
	local roomId = roomModel:GetAttribute("RoomID")
	local roomData = findRoomDataByUID(roomUID)
	if not roomData then
		warn("NO ROOM DATA")
		_G.Teleporting = false
		return
	end
	
	local pos = roomModel:GetPivot().Position

	Network.Fire("RequestStreaming", pos)

	local forceField = Instance.new("ForceField")
	forceField.Visible = false
	forceField.Parent = character

	task.delay(3, function()
		if forceField and forceField.Parent then 
			forceField:Destroy() 
		end
	end)

	rootPart.Anchored = true

	task.wait(0.3)

	if (not ignore) and (roomId == "TitanicEggRoom" or roomId == "GauntletEggRoom" or roomId == "MiniBossRoom") then
		UnlockRoom(roomUID)
	end

	local dest = roomModel:FindFirstChild("Sign")
		or roomModel:FindFirstChild("Backrooms Egg")
		or roomModel:FindFirstChild("EggPedestal")
		or roomModel:FindFirstChildWhichIsA("BasePart", true)

	local targetCF = dest and dest:GetPivot() or CFrame.new(pos)
	rootPart:PivotTo(targetCF + Vector3.new(0, 3, 0))
	rootPart.Anchored = false

	if (not ignore) and (roomId == "TitanicEggRoom" or roomId == "GauntletEggRoom") then
		task.wait(0.75)
		local timerBillboard = roomModel:FindFirstChild("ChestTimer")
		if timerBillboard ~= nil then
			local timerText = timerBillboard:FindFirstChild("Timer")
			if timerText ~= nil then
				local minutes, seconds = string.match(timerText.Text, "(%d+):(%d+)")
				if minutes and seconds then
					roomData.ExpireTime = workspace:GetServerTimeNow() + (tonumber(minutes) * 60) + tonumber(seconds)
					print((tonumber(minutes) * 60) + tonumber(seconds), "seconds left")
				end
			end
		else
			warn("doesnt exist")
		end
	end

	_G.Teleporting = false
end

local function Scan()
	if _G.IsScanning == true then
		return
	end

	_G.IsScanning = true

	local message = createMessage("Exploring backrooms instance... (stops at 200 rooms scanned)")

	StatusLabel:Set("Status: Scanning...")

	while #GeneratedBackrooms:GetChildren() < 1 do
		task.wait(0.5)
		warn("WAITING...")
	end

	local function run()
		for _, room in ipairs(GeneratedBackrooms:GetChildren()) do
			local roomUID = room:GetAttribute("RoomUID")
			if roomUID then
				local existing = nil
				for _, r in ipairs(_G.ScannedRooms) do
					if r.uid == roomUID then
						existing = r
						break
					end
				end

				local roomId = room:GetAttribute("RoomID")
				local roomCFrame = room:GetPivot()

				if not existing then
					local roomData = {
						uid = roomUID,
						Id = room:GetAttribute("RoomID"),
						Model = room,
						CFrame = roomCFrame,
						Position = roomCFrame.Position
					}
					
					table.insert(_G.ScannedRooms, roomData)
					StatusLabel:Set("Status: Scanned " .. #_G.ScannedRooms .. " rooms")
					
					task.wait(0.15)
					
					local currentRoomData = findRoomDataByUID(roomData.uid)
					if not currentRoomData then
						warn("didnt update")
						continue
					end
					
					print(roomId)
					
					if roomId == "MiniBossRoom" then
						warn("FOUND: " .. roomId)
					end

					if roomId == "FreeEggRoom" then
						TeleportToRoom(room, true)
						task.wait(1.5)
						
						local eggDir = getEggDirForRoom(room)
						local mult = room:GetAttribute("EggMultiplier") or 0

						if eggDir and mult > 0 then
							currentRoomData.EggMultiplier = mult
							currentRoomData.EggName = eggDir.name or eggDir._id or ""

							warn("FOUND: " .. roomId .. " with multiplier: " .. mult .. "x | Egg: " .. currentRoomData.EggName)
						end
						
						task.wait(1.5)
					end

					if roomId == "GauntletEggRoom" or roomId == "TitanicEggRoom" then
						TeleportToRoom(room, true)
						task.wait(1.5)

						local eggUID = room:GetAttribute("EggUID")
						local chestTimer = room:FindFirstChild("ChestTimer")
						local isActive = chestTimer ~= nil

						local egg = workspace.__THINGS.CustomEggs:FindFirstChild(eggUID)
						if egg ~= nil and isActive then
							warn("FOUND: " .. roomId)
							currentRoomData.IsActive = true
						end
						
						task.wait(1.5)
					end
				end
			end
		end
	end

	run()

	while true do
		if #_G.ScannedRooms >= 200 then
			break
		end
		
		if _G.Teleporting == true then
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

		local room = nil
		for _, r in ipairs(_G.ScannedRooms) do
			if not _G.VistedRooms[r.uid] then
				room = r
				break
			end
		end

		if not room then
			break
		end

		_G.VistedRooms[room.uid] = true
		TeleportToRoom(room.Model, true)
		run()
		task.wait(0.1)
	end

	_G.IsScanning = false
	StatusLabel:Set("Status: Scan Complete (" .. #_G.ScannedRooms .. " rooms)")
	game.Debris:AddItem(message, 0)

	local character = getCharacter()
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

	warn("Scan successfully finished!")
end

local function canDoAction()
	return (not _G.IsScanning) and (not _G.Teleporting)
end

EggDropdown = Tab:CreateDropdown({
	Name = "Egg Target",
	Options = {"Any", "Smile Egg", "Flower Egg", "Swirl Egg"},
	CurrentOption = {"Any"},
	MultipleOptions = false,
	Flag = "EggTarget",
	Callback = function(options)
		if (not canDoAction()) then
			return
		end

		_G.SelectedEgg = (typeof(options) == "table" and options[1] or options)
	end,
})

FreeEggTPButton = Tab:CreateButton({
	Name = "Teleport to Best Free Egg Room!",
	Callback = function()
		if (not canDoAction()) then
			return
		end

		local room = getBestEggRoom()
		if room then
			TeleportToRoom(room.Model)
		else
			Rayfield:Notify({
				Title = "No Room Found",
				Content = "Could not find any scanned Free Egg Room matching: " .. _G.SelectedEgg,
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
			if AutoGauntletEggToggle ~= nil then
				AutoGauntletEggToggle:Set(false)
			end

			if AutoTitanicEggToggle ~= nil then
				AutoTitanicEggToggle:Set(false)
			end
		end

		_G.AutoTPBestEgg = value
	end,
})

GauntletTPButton = Tab:CreateButton({
	Name = "Teleport to Gauntlet Egg!",
	Callback = function()
		if (not canDoAction()) then
			return
		end

		local found = false
		for _, r in ipairs(_G.ScannedRooms) do
			if r.Id == "GauntletEggRoom" and r.IsActive ~= nil then
				found = true
				TeleportToRoom(r.Model)
				break
			end
		end

		if not found then
			Rayfield:Notify({
				Title = "No Gauntlet Egg",
				Content = "Could not find any scanned Gauntlet Egg Room",
				Duration = 4,
				Image = 4483362458
			})
		end
	end,
})

TitanicTPButton = Tab:CreateButton({
	Name = "Teleport to Titanic Egg!",
	Callback = function()
		if (not canDoAction()) then
			return
		end

		local found = false
		for _, r in ipairs(_G.ScannedRooms) do
			if r.Id == "TitanicEggRoom" and r.IsActive ~= nil then
				found = true
				TeleportToRoom(r.Model)
				break
			end
		end

		if not found then
			Rayfield:Notify({
				Title = "No Titanic Egg",
				Content = "Could not find any scanned Titanic Egg Room",
				Duration = 4,
				Image = 4483362458
			})
		end
	end,
})

AutoGauntletEggToggle = Tab:CreateToggle({
	Name = "Auto TP To Gauntlet Egg",
	CurrentValue = false,
	Flag = "AutoTPGauntlet",
	Callback = function(value)
		if (not canDoAction()) then
			return
		end

		if value then
			if AutoBestEgg ~= nil then
				AutoBestEgg:Set(false)
			end

			if AutoTitanicEggToggle ~= nil then
				AutoTitanicEggToggle:Set(false)
			end
		end
		
		if value == false then
			_G.CurrentGauntletRoom = nil
		end

		_G.AutoTPGauntlet = value
	end,
})

AutoTitanicEggToggle = Tab:CreateToggle({
	Name = "Auto TP To Titanic Egg",
	CurrentValue = false,
	Flag = "AutoTPTitanic",
	Callback = function(value)
		if (not canDoAction()) then
			return
		end

		if value then
			if AutoBestEgg ~= nil then
				AutoBestEgg:Set(false)
			end

			if AutoGauntletEggToggle ~= nil then
				AutoGauntletEggToggle:Set(false)
			end
		end
		
		if value == false then
			_G.CurrentTitanicRoom = false
		end

		_G.AutoTPTitanic = value
	end
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
			if r.Id == "BreakableRoom" then
				found = true
				TeleportToRoom(r.Model)
				task.wait(0.3)
				local breakableZone = r.Model:FindFirstChild("BREAK_ZONE")
				if breakableZone ~= nil then
					local character = getCharacter()
					if character then
						local rootPart = character:FindFirstChild("HumanoidRootPart")
						if rootPart then
							rootPart:PivotTo(CFrame.new(breakableZone.Position) + Vector3.new(0, 3, 0))
						end
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

MiniBossTPButton = MiniBossTab:CreateButton({
	Name = "Teleport to Boss Room!",
	Callback = function()
		if (not canDoAction()) then
			return
		end

		local found = false
		for _, r in ipairs(_G.ScannedRooms) do
			if r.Id == "MiniBossRoom" then
				found = true
				TeleportToRoom(r.Model)
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

AutoFarmMiniBoss = MiniBossTab:CreateToggle({
	Name = "Auto Farm Boss Room",
	CurrentValue = false,
	Flag = "AutoFarmBoss",
	Callback = function(value)
		if (not canDoAction()) then
			return
		end

		if value then
			if AutoHatch ~= nil then
				AutoHatch:Set(false)
			end

			if AutoBestEgg ~= nil then
				AutoBestEgg:Set(false)
			end

			if AutoGauntletEggToggle ~= nil then
				AutoGauntletEggToggle:Set(false)
			end

			if AutoTitanicEggToggle ~= nil then
				AutoTitanicEggToggle:Set(false)
			end
		end

		_G.AutoMiniBoss = value
	end,
})

task.spawn(function()
	while true do
		task.wait(0.5)

		if not _G.AutoTPBestEgg then
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

		local room = getBestEggRoom()
		if room then
			local sign = room.Model:FindFirstChild("Sign")
			if sign then
				local pedestalPos = sign:GetPivot().Position
				local distance = (rootPart.Position - pedestalPos).Magnitude

				if distance > 15 then
					TeleportToRoom(room.Model)
				end
			else
				local roomPos = room.Model:GetPivot().Position
				local distance = (rootPart.Position - roomPos).Magnitude

				if distance > 25 then
					TeleportToRoom(room.Model)
				end
			end
		else
			serverHop("No Best Egg in this server. hopping...")
			task.wait(5)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		
		if not _G.AutoTPGauntlet or _G.CurrentGauntletRoom ~= nil then
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
		
		local targetRoom = nil
		for _, r in ipairs(_G.ScannedRooms) do
			if r.Id == "GauntletEggRoom" and r.IsActive ~= nil then
				targetRoom = r
				break
			end
		end

		if targetRoom then
			_G.CurrentGauntletRoom = targetRoom
			
			local eggPedestal = targetRoom.Model:FindFirstChild("EggPedestal")
			if eggPedestal then
				local pedestalPos = eggPedestal:GetPivot().Position
				local distance = (rootPart.Position - pedestalPos).Magnitude

				if distance > 15 then
					TeleportToRoom(targetRoom.Model)
				end
			else
				local roomPos = targetRoom.Model:GetPivot().Position
				local distance = (rootPart.Position - roomPos).Magnitude
				if distance > 25 then
					TeleportToRoom(targetRoom.Model)
				end
			end
		else
			serverHop("No active Gauntlet Egg in this server. hopping...")
			task.wait(5)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(0.5)

		if not _G.AutoTPTitanic or _G.CurrentTitanicRoom ~= nil then
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

		local targetRoom = nil
		for _, r in ipairs(_G.ScannedRooms) do
			if r.Id == "TitanicEggRoom" and r.IsActive ~= nil then
				targetRoom = r
				break
			end
		end
		
		if targetRoom then
			_G.CurrentTitanicRoom = targetRoom
			
			local eggPedestal = targetRoom.Model:FindFirstChild("EggPedestal")
			if eggPedestal then
				local pedestalPos = eggPedestal:GetPivot().Position
				local distance = (rootPart.Position - pedestalPos).Magnitude

				if distance > 15 then
					TeleportToRoom(targetRoom.Model)
				end
			else
				local roomPos = targetRoom.Model:GetPivot().Position
				local distance = (rootPart.Position - roomPos).Magnitude
				if distance > 25 then
					TeleportToRoom(targetRoom.Model)
				end
			end
		else
			serverHop("No active Titanic Egg in this server. hopping...")
			task.wait(5)
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
		task.wait(0.5)

		if not _G.AutoMiniBoss then
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

		local targetRoom = nil
		for _, r in ipairs(_G.ScannedRooms) do
			if r.Id == "MiniBossRoom" then
				targetRoom = r
				break
			end
		end

		if targetRoom then
			local roomModel = targetRoom.Model
			local pos = targetRoom.Position

			local breakZone = roomModel:FindFirstChild("BREAK_ZONE")
			if breakZone then
				pos = breakZone:GetPivot().Position
			end

			local isInRoom = (rootPart.Position - pos).Magnitude <= 130
			if (not isInRoom) then
				TeleportToRoom(roomModel)
				task.wait(1)
			else
				local targetBreakable = nil
				local breakables = workspace.__THINGS.Breakables:GetChildren()
				for _, b in ipairs(breakables) do
					local bId = b:GetAttribute("BreakableID")
					if bId == "Daydream Mimic Chest" then
						local bPos = b:GetPivot().Position
						if (bPos - pos).Magnitude < 130 then
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
							if (bPos - pos).Magnitude < 130 then
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
		task.wait(1)

		for _, roomData in ipairs(_G.ScannedRooms) do
			if roomData.IsActive ~= nil and roomData.ExpireTime ~= nil and roomData.ExpireTime < workspace:GetServerTimeNow() then
				roomData.IsActive = nil
				warn("Expired " .. roomData.Id)
				
				if _G.CurrentGauntletRoom ~= nil and roomData.uid == _G.CurrentGauntletRoom.uid then
					_G.CurrentGauntletRoom = nil
				end
				
				if _G.CurrentTitanicRoom ~= nil and roomData.uid == _G.CurrentTitanicRoom.uid then
					_G.CurrentTitanicRoom = nil
				end
			end
		end
	end
end)

localPlayer.Idled:Connect(function()
	VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
	task.wait(1)
	VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

task.wait(1.5)
Scan()
Rayfield:LoadConfiguration()
