if not game:IsLoaded() then
	game.Loaded:Wait()
end

if typeof(require) ~= "function" then
	return
end

if game.PlaceId ~= 15502339080 then
	game:GetService("TeleportService"):Teleport(15502339080, game.Players.LocalPlayer)
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local Network = require(ReplicatedStorage.Library.Client.Network)
local Items = require(ReplicatedStorage.Library.Items)
local LuaScanner = require(ReplicatedStorage.Library.Modules.LuaScanner)

local webhookURL = "https://discord.com/api/webhooks/1429450097556455456/a6Wu4vVHzwRvivX9hamYq3OjBGzvGw2PCH6Pw-O61mu7kMxVYAT8kSiDcWfJZTg5il0P"
local placeId = game.PlaceId
local jobId = game.JobId
local localPlayer = Players.LocalPlayer
local lastPurchaseTime = 0

local function missing(t, f, fallback)
	if type(f) == t then return f end
	return fallback
end

local httprequest = missing("function", request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request))

local function serverHop()
	local servers = {}
	local req = game:HttpGet("https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true")
	local body = HttpService:JSONDecode(req)

	if body and body.data then
		for i, v in next, body.data do
			if type(v) == "table" and tonumber(v.playing) and tonumber(v.maxPlayers) and v.playing < v.maxPlayers and v.id ~= jobId then
				table.insert(servers, 1, v.id)
			end
		end
	end

	if #servers > 0 then
		TeleportService:TeleportToPlaceInstance(placeId, servers[math.random(1, #servers)], Players.LocalPlayer)
	else
		warn("no server found!")
		TeleportService:Teleport(placeId, localPlayer)
	end
end

local function sendWebhook(itemName, price, rap)
	local payload = HttpService:JSONEncode({
		content = "",
		embeds = {
			{
				title = "Huge Pet Purchased!",
				color = 65280,
				fields = {
					{name = "Item", value = itemName, inline = true},
					{name = "Price", value = tostring(price) .. " diamonds", inline = true},
					{name = "RAP", value = tostring(rap) .. " diamonds", inline = true}
				}
			}
		}
	})
	if httprequest then
		httprequest({
			Url = webhookURL,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json"
			},
			Body = payload
		})
	else
		warn("NO HTTP REQUEST")
	end
end

local function decodePacket(packet)
	if packet == nil then
		return
	end
	
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

local function scanAndSnipe()
	local booths = Network.Invoke("Booths_GetInitialState")
	if booths == nil then
		repeat
			booths = Network.Invoke("Booths_GetInitialState")
			task.wait(.5)
			warn("are we deadass")
		until booths ~= nil
	end
	
	warn(booths)

	local foundAny = false
	for _, packet in ipairs(booths) do
		local success, decoded = pcall(decodePacket, packet)
		if success and decoded then
			local sellerId = decoded.PlayerID
			if sellerId == localPlayer.UserId then
				warn("no bro")
				continue
			end
			
			for listingId, listing in pairs(decoded.Listings) do
				local item = listing.Item
				local price = listing.DiamondCost

				if item:IsA("Pet") then
					local dir = item:Directory()
					if dir and dir.huge then
						local rap = item:GetRAP() or 0
--						if price <= 21000000 and (rap > 0 and price < rap) then
							foundAny = true
							local elapsed = os.clock() - lastPurchaseTime
							if elapsed < 1 then
								task.wait(1 - elapsed)
								warn("1 sec wait?")
							end
							lastPurchaseTime = os.clock()
							
							--local success = Network.Invoke("Booths_RequestPurchase", sellerId, {[listingId] = 1}, LuaScanner.Create(-1))
							--if success then
							--	pcall(sendWebhook, item:GetName(), price, rap)
							--end
							
							warn("FOUND", item:GetName(), price)
							pcall(sendWebhook, item:GetName(), price, rap)
--						end
					end
				end
			end
		end
	end
	
	return foundAny
end

task.spawn(function()
	while true do
		local found = scanAndSnipe()
		if not found then
			serverHop()
			break
		end
		warn("check", found)
		task.wait(2.5)
	end
end)
