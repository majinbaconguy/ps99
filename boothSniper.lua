if not game:IsLoaded() then
	game.Loaded:Wait()
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Network = require(ReplicatedStorage.Library.Client.Network)
local Items = require(ReplicatedStorage.Library.Items)
local LuaScanner = require(ReplicatedStorage.Library.Modules.LuaScanner)

local function decodePacket(packet)
	local decoded = {
		PlayerID = packet.PlayerID,
		BoothID = packet.BoothID,
		Listings = {}
	}
	for k, v in pairs(packet.Listings) do
		local itemData = v.ItemData
		if itemData then
			local success, item = pcall(function()
				return Items.From(itemData.class, itemData.data):SetUID(itemData.uid)
			end)
			if success and item then
				decoded.Listings[k] = {
					Item = item,
					DiamondCost = v.DiamondCost
				}
			end
		end
	end
	return decoded
end

local function checkBooth(decodedPacket)
	local sellerId = decodedPacket.PlayerID
	if sellerId == LocalPlayer.UserId then 
		return 
	end
	
	for listingId, listing in pairs(decodedPacket.Listings) do
		local item = listing.Item
		local price = listing.DiamondCost
		
		if item:IsA("Pet") then
			local dir = item:Directory()
			if dir and dir.huge then
				local rap = item:GetRAP() or 0
				print(rap, dir.name)
			end
		end
	end
end

local function onBroadcast(player, packet)
	if not packet then return end
	local success, decoded = pcall(decodePacket, packet)
	if success and decoded then
		checkBooth(decoded)
	end
end

Network.Fired("Booths_Broadcast"):Connect(onBroadcast)

local initialBooths = Network.Invoke("Booths_GetInitialState")
if initialBooths then
	for _, packet in ipairs(initialBooths) do
		local success, decoded = pcall(decodePacket, packet)
		if success and decoded then
			checkBooth(decoded)
		end
	end
end
