if not game:IsLoaded() then
	game.Loaded:Wait()
end

local TeleportService = game:GetService("TeleportService")
if _G.BackroomsFarmingScriptLoaded then
	TeleportService:Teleport(game.PlaceId, game.Players.LocalPlayer)
	return
end
_G.BackroomsFarmingScriptLoaded = true

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name = "Backrooms Farming Script",
	LoadingTitle = "Backrooms Farmer",
	LoadingSubtitle = "by Antigravity",
	ConfigurationSaving = {
		Enabled = false,
		FolderName = nil,
		FileName = "BackroomsFarmingConfig"
	},
	Discord = {
		Enabled = false,
		Invite = "noinvite",
		RememberJoins = true
	},
	KeySystem = false
})

local Tab = Window:CreateTab("Main", nil)
local MiscTab = Window:CreateTab("Misc", nil)

local autoClaim = false
local autoMiniBoss = false
local infPetsSpeed = false
local claimedRewards = {}
local isScanning = false

local function bindMessage(msg)
	local message = Instance.new("Message", workspace)
	message.Text = msg
	game.Debris:AddItem(message, 4)
end

if typeof(require) ~= "function" then
	bindMessage("EXECUTOR NOT SUPPORTED")
	return
end

local Network = require(game.ReplicatedStorage.Library.Client.Network)
local MiscItem = require(game.ReplicatedStorage.Library.Items.MiscItem)

local function getInstanceId()
	return game.Players.LocalPlayer:GetAttribute("InstanceId") or "Backrooms"
end

local function getRoomsTable()
	local ClientModule = require(game.Workspace.__THINGS.__INSTANCE_CONTAINER.Active.Backrooms.ClientModule)
	local getfenv = getfenv
	local getupvalues = debug.getupvalues or getupvalues
	if not getfenv or not getupvalues then return nil end
	local env = getfenv(ClientModule.OnJoin)
	if not env then return nil end
	local getRoom = env.getRoom
	if not getRoom then return nil end
	for _, v in pairs(getupvalues(getRoom)) do
		if typeof(v) == "table" then
			return v
		end
	end
	return nil
end

local function isClaimed(rewardModel)
	local animated = rewardModel:FindFirstChild("Animated")
	if animated then
		local top = animated:FindFirstChild("Top")
		if top and top:IsA("BasePart") and top.Transparency > 0.9 then
			return true
		end
	end
	return false
end

local function getRoomUid(instance)
	local current = instance
	while current and current ~= workspace do
		local roomUid = current:GetAttribute("RoomUID")
		if roomUid then
			return roomUid
		end
		current = current.Parent
	end
	return nil
end

local function getGeneratedBackrooms()
	local things = workspace:FindFirstChild("__THINGS")
	if not things then return nil end
	local instanceContainer = things:FindFirstChild("__INSTANCE_CONTAINER")
	if not instanceContainer then return nil end
	local active = instanceContainer:FindFirstChild("Active")
	if not active then return nil end
	local backrooms = active:FindFirstChild("Backrooms")
	if not backrooms then return nil end
	return backrooms:FindFirstChild("GeneratedBackrooms")
end

local function getRoomCFrame(room)
	for _, child in ipairs(room:GetChildren()) do
		if child:IsA("BasePart") then
			local nameLower = child.Name:lower()
			if nameLower == "carpet" or nameLower == "baseplate" or nameLower == "floor" or nameLower == "ground" then
				return child.CFrame * CFrame.new(0, 3, 0)
			end
		end
	end
	for _, child in ipairs(room:GetChildren()) do
		if child:IsA("BasePart") then
			local nameLower = child.Name:lower()
			if nameLower:find("carpet") or nameLower:find("baseplate") or nameLower:find("floor") or nameLower:find("ground") then
				return child.CFrame * CFrame.new(0, 3, 0)
			end
		end
	end
	return room:GetPivot() * CFrame.new(0, 8, 0)
end

local function getRewards()
	local rewards = {}
	local generatedBackrooms = getGeneratedBackrooms()
	if generatedBackrooms then
		for _, descendant in ipairs(generatedBackrooms:GetDescendants()) do
			if descendant.Name == "RandomReward" and descendant:IsA("Model") then
				table.insert(rewards, descendant)
			end
		end
	end
	return rewards
end

local function claimReward(rewardModel)
	if not rewardModel or not rewardModel.Parent then
		return false, "Invalid reward model"
	end
	local roomUid = getRoomUid(rewardModel)
	if not roomUid then
		return false, "Could not find RoomUID"
	end
	local character = game.Players.LocalPlayer.Character
	if not character then
		return false, "Player character not found"
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false, "HumanoidRootPart not found"
	end
	local pivot = rewardModel:GetPivot()
	hrp.CFrame = pivot * CFrame.new(0, 3, 0)
	local success, result = pcall(function()
		return Network.Invoke("Instancing_InvokeCustomFromClient", getInstanceId(), "AbstractRoom_InvokeServer", roomUid, "ClaimRandomReward", rewardModel)
	end)
	if not success then
		return false, tostring(result)
	end
	return result
end

task.spawn(function()
	while true do
		task.wait(0.35)
		if autoClaim then
			local rewards = getRewards()
			for _, reward in ipairs(rewards) do
				if autoClaim and not claimedRewards[reward] and not isClaimed(reward) then
					local success, err = claimReward(reward)
					claimedRewards[reward] = true
					if not success then
						Rayfield:Notify({
							Title = "Error",
							Content = "Failed: " .. tostring(err),
							Duration = 3.0
						})
					end
				end
			end
		end
	end
end)

local function findMiniBossRoom()
	local generatedBackrooms = getGeneratedBackrooms()
	if generatedBackrooms then
		for _, room in ipairs(generatedBackrooms:GetChildren()) do
			if room:GetAttribute("RoomID") == "MiniBossRoom" or room.Name == "MiniBossRoom" then
				return room
			end
		end
	end
	return nil
end

local function getRoomsList()
	local rooms = {}
	local generatedBackrooms = getGeneratedBackrooms()
	if generatedBackrooms then
		for _, room in ipairs(generatedBackrooms:GetChildren()) do
			if room:IsA("Model") then
				table.insert(rooms, room)
			end
		end
	end
	return rooms
end

local function hasDaydreamKey()
	local keyItem = MiscItem("Backrooms Crayon Key")
	if keyItem and keyItem:HasAny() then
		return true
	end
	return false
end

local function getActiveChests(bossRoom)
	local daydreamChests = {}
	local bossChest = nil
	local BreakableCmds = require(game.ReplicatedStorage.Library.Client.BreakableCmds)
	local chests = BreakableCmds.AllByInstanceAndClass("Chest")
	if chests then
		local roomCenter = getRoomCFrame(bossRoom).Position
		for _, model in pairs(chests) do
			if model and model.Parent then
				local breakableId = model:GetAttribute("BreakableID") or model.Name
				if typeof(breakableId) == "string" then
					local chestPos = model:GetPivot().Position
					local flatDist = (Vector3.new(chestPos.X, 0, chestPos.Z) - Vector3.new(roomCenter.X, 0, roomCenter.Z)).Magnitude
					if flatDist < 55 then
						if breakableId == "Daydream Mimic Chest" then
							table.insert(daydreamChests, model)
						elseif breakableId == "Daydream Mimic Boss" then
							bossChest = model
						end
					end
				end
			end
		end
	end
	return daydreamChests, bossChest
end

local function sendPetsToTarget(breakableModel)
	local PlayerPet = require(game.ReplicatedStorage.Library.Client.PlayerPet)
	local pets = PlayerPet.GetByPlayer(game.Players.LocalPlayer)
	if pets then
		for _, pet in pairs(pets) do
			if pet and typeof(pet) == "table" and typeof(pet.SetTarget) == "function" then
				pcall(function()
					pet:SetTarget(breakableModel)
				end)
			end
		end
	end
end

local function farmBoss(bossRoom)
	while autoMiniBoss and bossRoom.Parent do
		local daydreamChests, bossChest = getActiveChests(bossRoom)
		local character = game.Players.LocalPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			if #daydreamChests > 0 then
				local targetChest = daydreamChests[1]
				if targetChest and targetChest.Parent then
					hrp.Anchored = false
					character:MoveTo(targetChest:GetPivot().Position + Vector3.new(0, 10, 0))
					task.wait(0.1)
					hrp.Anchored = true
					sendPetsToTarget(targetChest)
					while targetChest.Parent and autoMiniBoss and bossRoom.Parent do
						local currentChests = getActiveChests(bossRoom)
						local stillExists = false
						for _, chest in ipairs(currentChests) do
							if chest == targetChest then
								stillExists = true
								break
							end
						end
						if not stillExists then
							break
						end
						sendPetsToTarget(targetChest)
						task.wait(0.5)
					end
				end
			elseif bossChest and bossChest.Parent then
				hrp.Anchored = false
				character:MoveTo(bossChest:GetPivot().Position + Vector3.new(0, 10, 0))
				task.wait(0.1)
				hrp.Anchored = true
				sendPetsToTarget(bossChest)
				task.wait(0.5)
			else
				hrp.Anchored = false
				character:MoveTo(getRoomCFrame(bossRoom).Position + Vector3.new(0, 10, 0))
				task.wait(0.1)
				hrp.Anchored = true
				task.wait(0.5)
			end
		else
			task.wait(0.5)
		end
	end
	local character = game.Players.LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = false
	end
end

local function scanMap()
	isScanning = true
	local character = game.Players.LocalPlayer.Character
	if not character then
		isScanning = false
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		isScanning = false
		return
	end
	hrp.Anchored = true
	local visited = {}
	while isScanning and autoMiniBoss do
		local bossRoom = findMiniBossRoom()
		if bossRoom then
			break
		end
		local rooms = getRoomsList()
		local moved = false
		for _, room in ipairs(rooms) do
			if not isScanning or not autoMiniBoss then
				break
			end
			local roomKey = room:GetAttribute("RoomUID") or room.Name
			if roomKey and not visited[roomKey] then
				visited[roomKey] = true
				hrp.CFrame = getRoomCFrame(room) * CFrame.new(0, 25, 0)
				moved = true
				task.wait(0.2)
				break
			end
		end
		if not moved then
			table.clear(visited)
			task.wait(0.2)
		end
	end
	hrp.Anchored = false
	isScanning = false
end

local toggleObj

local function bossFarmer()
	local bossRoom = findMiniBossRoom()
	if not bossRoom then
		scanMap()
		bossRoom = findMiniBossRoom()
	end
	if bossRoom and autoMiniBoss then
		local character = game.Players.LocalPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local lockedDoors = bossRoom:FindFirstChild("LockedDoors")
			local isLocked = false
			local lockCFrame = nil
			if lockedDoors then
				for _, door in ipairs(lockedDoors:GetChildren()) do
					local lock = door:FindFirstChild("Lock")
					if lock and lock:IsA("BasePart") then
						isLocked = true
						lockCFrame = lock.CFrame
						break
					end
				end
			end
			if isLocked and lockCFrame then
				hrp.CFrame = getRoomCFrame(bossRoom)
				task.wait(3.0)
				hrp.CFrame = lockCFrame * CFrame.new(0, 0, 2)
				task.wait(1.0)
				local roomsTable = getRoomsTable()
				if roomsTable then
					for uid, roomController in pairs(roomsTable) do
						if roomController.model == bossRoom then
							roomController:FireServer("UnlockDoors")
						end
					end
				end
				task.wait(1.0)
				hrp.CFrame = getRoomCFrame(bossRoom)
				task.wait(1.0)
			end
			Rayfield:Notify({
				Title = "MiniBossRoom Found",
				Content = "Successfully teleported to the MiniBossRoom and unlocked doors!",
				Duration = 5.0
			})
			farmBoss(bossRoom)
		end
	end
	autoMiniBoss = false
	task.spawn(function()
		toggleObj:Set(false)
	end)
end

toggleObj = Tab:CreateToggle({
	Name = "Auto Find MiniBossRoom",
	CurrentValue = false,
	Flag = "AutoFindMiniBoss",
	Callback = function(Value)
		autoMiniBoss = Value
		if Value then
			if not hasDaydreamKey() then
				Rayfield:Notify({
					Title = "Error",
					Content = "You do not have a Daydream Key in your inventory!",
					Duration = 5.0
				})
				task.spawn(function()
					toggleObj:Set(false)
				end)
				return
			end
			task.spawn(bossFarmer)
		else
			isScanning = false
		end
	end
})

Tab:CreateToggle({
	Name = "Auto Claim Rewards",
	CurrentValue = false,
	Flag = "AutoClaimToggle",
	Callback = function(Value)
		autoClaim = Value
	end
})

local function updateAllPetsSpeed()
	local PlayerPet = require(game.ReplicatedStorage.Library.Client.PlayerPet)
	local pets = PlayerPet.GetByPlayer(game.Players.LocalPlayer)
	if pets then
		for _, pet in pairs(pets) do
			if pet and typeof(pet) == "table" and pet.cpet then
				local mult = pet:CalculateSpeedMultiplier()
				pet.speedMult = mult
				pcall(function()
					pet.cpet:Broadcast("petSpeedMult", mult)
				end)
			end
		end
	end
end

local PlayerPet = require(game.ReplicatedStorage.Library.Client.PlayerPet)
if not _G.OriginalCalculateSpeedMultiplier then
	_G.OriginalCalculateSpeedMultiplier = PlayerPet.CalculateSpeedMultiplier
	PlayerPet.CalculateSpeedMultiplier = function(self)
		if infPetsSpeed then
			return 999999
		end
		return _G.OriginalCalculateSpeedMultiplier(self)
	end
end

MiscTab:CreateToggle({
	Name = "Infinite Pets Speed",
	CurrentValue = false,
	Flag = "InfPetsSpeed",
	Callback = function(Value)
		infPetsSpeed = Value
		updateAllPetsSpeed()
	end
})
