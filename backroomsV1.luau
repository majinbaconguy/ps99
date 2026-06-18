local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local Network = require(game.ReplicatedStorage.Library.Client.Network)
local InstancingCmds = require(game.ReplicatedStorage.Library.Client.InstancingCmds)
local MiscItem = require(game.ReplicatedStorage.Library.Items.MiscItem)
local EggCmds = require(game.ReplicatedStorage.Library.Client.EggCmds)
local CustomEggsCmds = require(game.ReplicatedStorage.Library.Client.CustomEggsCmds)

local localPlayer = Players.LocalPlayer

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

_G.ScannedRooms = {}
_G.VistedRooms = {}
_G.IsScanning = false
_G.Teleporting = false
_G.AutoHatch = false
_G.AutoTPGauntlet = false
_G.AutoTPTitanic = false

local Window = Rayfield:CreateWindow({
	Name = "PS99 Backrooms Script",
	LoadingTitle = "Loading...",
	LoadingSubtitle = "by Pirate Games",
	Theme = "Default",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = false,
		FolderName = "BackroomsPS99",
		FileName = "Config"
	},
	KeySystem = false
})

local Tab = Window:CreateTab("Main", 4483362458)
local StatusLabel = Tab:CreateLabel("Status: Idle")

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

local function serverHop()
	local success, result = pcall(function()
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
	end
end

local activeFolder = workspace:WaitForChild("__THINGS")
	:WaitForChild("__INSTANCE_CONTAINER")
	:WaitForChild("Active")

local backroomsFolder = activeFolder:WaitForChild("Backrooms")
local GeneratedBackrooms = backroomsFolder:WaitForChild("GeneratedBackrooms")

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

local function TeleportToRoom(roomModel)
	if _G.Teleporting then
		return
	end

	_G.Teleporting = true

	local character = getCharacter()
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
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

	task.wait(0.3)
	
	if roomModel.Name == "TitanicEggRoom" or roomModel.Name == "GauntletEggRoom" then
		UnlockRoom(roomModel:GetAttribute("RoomUID"))
	end

	local dest = roomModel:FindFirstChild("Sign")
		or roomModel:FindFirstChild("Backrooms Egg")
		or roomModel:FindFirstChild("EggPedestal")
		or roomModel:FindFirstChildWhichIsA("BasePart", true)

	local targetCF = dest and dest:GetPivot() or CFrame.new(pos)
	rootPart.CFrame = targetCF + Vector3.new(0, 3, 0)
	
	_G.Teleporting = false
end

local function Scan()
	if _G.IsScanning == true then
		return
	end

	_G.IsScanning = true

	local message = createMessage("Exploring backrooms instance. Please wait...")

	StatusLabel:Set("Status: Scanning...")

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
					table.insert(_G.ScannedRooms, {
						uid = roomUID,
						Id = room:GetAttribute("RoomID"),
						Model = room,
						CFrame = roomCFrame,
						Position = roomCFrame.Position
					})
					print(`scanned {#_G.ScannedRooms} rooms for now`)
					Network.Fire("RequestStreaming", roomCFrame.Position)
				end
			end
		end
	end

	run()

	while true do
		if #_G.ScannedRooms >= 100 then
			break
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
		TeleportToRoom(room.Model)

		if room.Id == "GauntletEggRoom" or room.Id == "TitanicEggRoom" then
			task.wait(1.5)
			local roomModel = room.Model
			local eggUID = roomModel:GetAttribute("EggUID")
			local chestTimer = roomModel:FindFirstChild("ChestTimer")
			local isActive = chestTimer ~= nil

			local egg = workspace.__THINGS.CustomEggs:FindFirstChild(eggUID)
			if egg ~= nil and isActive then
				warn("FOUND ACTIVE", room.Id)
				room.IsActive = true

				egg.Destroying:Connect(function()
					if room.IsActive then
						room.IsActive = nil
					end
				end)
			end
			task.wait(0.5)
		end

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

end

local function canDoAction()
	return (not _G.IsScanning) and (not _G.Teleporting)
end

local GauntletTPButton = Tab:CreateButton({
	Name = "Teleport to Gauntlet Egg!",
	Callback = function()
		if (not canDoAction()) then
			return
		end

		for _, r in ipairs(_G.ScannedRooms) do
			if r.Id == "GauntletEggRoom" and r.IsActive ~= nil then
				TeleportToRoom(r.Model)
				break
			end
		end
	end,
})

local TitanicTPButton = Tab:CreateButton({
	Name = "Teleport to Titanic Egg!",
	Callback = function()
		if (not canDoAction()) then
			return
		end

		for _, r in ipairs(_G.ScannedRooms) do
			if r.Id == "TitanicEggRoom" and r.IsActive ~= nil then
				TeleportToRoom(r.Model)
				break
			end
		end
	end,
})

local AutoGauntletEggToggle = Tab:CreateToggle({
	Name = "Auto TP To Gauntlet Egg",
	CurrentValue = false,
	Flag = "AutoTPGauntlet",
	Callback = function(value)
		if (not canDoAction()) then
			return
		end
		
		_G.AutoTPGauntlet = value
	end,
})

local AutoTitanicEggToggle = Tab:CreateToggle({
	Name = "Auto TP To Titanic Egg",
	CurrentValue = false,
	Flag = "AutoTPTitanic",
	Callback = function(value)
		if (not canDoAction()) then
			return
		end
		
		_G.AutoTPTitanic = value
	end,
})

local AutoHatch = Tab:CreateToggle({
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

task.spawn(function()
	while true do
		task.wait(0.5)

		if not _G.AutoTPGauntlet then
			continue
		end

		if _G.IsScanning or #_G.ScannedRooms == 0 then
			continue
		end

		local targetRoom = nil
		for _, r in ipairs(_G.ScannedRooms) do
			if r.Id == "GauntletEggRoom" and r.IsActive ~= nil then
				targetRoom = r
				break
			end
		end

		local character = getCharacter()
		if not character then
			continue
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			continue
		end

		if targetRoom then
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
			serverHop()
			task.wait(5)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(0.5)

		if not _G.AutoTPTitanic then
			continue
		end

		if _G.IsScanning or #_G.ScannedRooms == 0 then
			continue
		end

		local targetRoom = nil
		for _, r in ipairs(_G.ScannedRooms) do
			if r.Id == "TitanicEggRoom" and r.IsActive ~= nil then
				targetRoom = r
				break
			end
		end
		
		local character = getCharacter()
		if not character then
			continue
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			continue
		end

		if targetRoom then
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
			serverHop()
			task.wait(5)
		end
	end
end)


task.spawn(function()
	while true do
		task.wait(0.5)

		if not _G.AutoHatch then
			continue
		end

		if _G.IsScanning or #_G.ScannedRooms == 0 then
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

localPlayer.Idled:Connect(function()
	VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
	task.wait(1)
	VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

task.wait(1.5)
Scan()
