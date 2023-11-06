--The module that gets called below *is* on my profile. Though, is has no contents of any value besides the current release version, which is returned to your output window.
--(Some people (like myself) don't usually like when scripts call to modules outside of their game.)
--You can disable calling for this remote module by setting the "_AutoUpdate_" attribute checkbox in this script's properties to false





--[[NATIVE MENU OPTIONAL SETTINGS]]--
-- CUSTOM KEYBINDS ARE NOT WORKING AT THE MOMENT. THIS IS SUBJECT TO CHANGE IN A LATER UPDATE
local CustomKeybinds = {  -- Enum.KeyCode.?
	KeyboardMouse = {}; -- Strictly PC users
	Keyboard = {}; 		-- Keyboard enabled devices without an enabled mouse
	Gamepad = {};		-- Controller
}

-------------------------------------



local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")

local MainController = script:FindFirstChild("BetaSunrayIntensityController") or script:WaitForChild("SunrayIntensityController",5)

local SICSCoreId = 15024209529
local NativeUIAssetID = 15038123726
local potentialNewCore
local potentialNewNativeUI

local SICS_Server_Version = "2.3"

local autoUpdateDevSettings = {
	skipUpdate = false;
	currentRetry = 0;
	maxRetries = 4;
}

function addCoreAttributes(target)
	for attribute, value in pairs(script:GetAttributes()) do
		target:SetAttribute(attribute, value)
	end
	MainController:SetAttribute("SICS_Server_Version", SICS_Server_Version)
end

function addCoreTags(target)
	for i, tagName in pairs(script:GetTags()) do
		target:AddTag(tagName)
	end
end

function addNewCoreClone(plr)
	local clonedSystem = MainController:Clone()
	clonedSystem.Parent = plr.PlayerGui
	clonedSystem.Enabled = true
	clonedSystem:SetAttribute("SICS_Server_Version", SICS_Server_Version)
	--// Updates from client-side system
	clonedSystem.DataStore.UpdateData.OnServerEvent:Connect(function(plr, dataName, dataValue)
		if not plr or not plr.SICS or not plr.SICS:FindFirstChild(dataName) then return warn("Data location not found") end
		plr.SICS[dataName].Value = dataValue
	end)
end

function getUISavedData(plr)
	local DataStore2 = require(1936396537)
	local Settings = require(MainController.DataStore)

	for dataName,valueTable in pairs(Settings) do
		local datastore = DataStore2(dataName, plr)
		local where = valueTable.Where
		if valueTable.Where ~= "Player" then
			if plr:findFirstChild(valueTable.Where) then
				where = plr[valueTable.Where]
			else
				local folder = Instance.new("Folder", plr)
				folder.Name = valueTable.Where
				where = folder
			end
		end

		if valueTable.Where == "Player" then
			where = plr
		end

		--// Creates the Value
		local val = Instance.new(valueTable.What,where)
		val.Name = dataName
		val.Value = valueTable.Value

		--// Loading
		if datastore:Get() ~= nil then -- If datastore already exists
			val.Value = datastore:Get() -- loads in player's data
			require(MainController.Settings):SetSetting(dataName, datastore:Get()) -- Update attribute value
		end

		--// Saving
		val.Changed:connect(function() -- if Value changes 
			datastore:Set(val.Value) -- Sets Datastore value to changed Value
		end)
	end
end

function addNativeUI(plr)
	if autoUpdateDevSettings.currentRetry > autoUpdateDevSettings.maxRetries then return warn("SICS max retries exceeded! Relying on last still existing system.") end
	local plrGui = plr:WaitForChild("PlayerGui",10)
	local Success, result = pcall(InsertService.LoadAsset, InsertService, NativeUIAssetID)
	if Success and result then
		potentialNewNativeUI = result:WaitForChild("SICSPanel",10)
		potentialNewNativeUI.Enabled  = false
		potentialNewNativeUI:FindFirstChildOfClass("Frame").Size = UDim2.new(0,0,1,0)
		potentialNewNativeUI.Parent = plrGui
		result:Destroy()
		warn("Initilized the latest native SICS UI")
		return getUISavedData(plr)
	else
		autoUpdateDevSettings.currentRetry += 1
		warn("Failed to fetch the SICS UI! Retrying...")
		task.wait(1)
	end
	task.wait()
	return checkForUpdate()
end

function addToExistingPlayers(playerList)
	for i,plr in pairs(playerList) do
		if plr then
			addNewCoreClone(plr)
			addNativeUI(plr)
		end
	end
end

function addKeybinds(targetModule)
	-- Setup custom keybinds
	if script:GetAttribute("AllowNativeUI") then 
		local KeybindModule = require(MainController.Keybinds)
		for attribute,value in pairs(script:GetAttributes()) do
			if string.find(attribute, "Bind") then
				MainController.Keybinds:SetAttribute(attribute, value)
			end
		end
	end
end

function checkForTestExperience()
	-- Test Experience SICSNativeUI ID - 15038856671
	if game.GameId == 4664865401 or game.PlaceId == 13400902755 then
		NativeUIAssetID = 15038856671
	end
end

function checkForUpdate()
	if autoUpdateDevSettings.currentRetry > autoUpdateDevSettings.maxRetries then return warn("SICS max retries exceeded! Relying on last still existing system.") end
	local Success, result = pcall(InsertService.LoadAsset, InsertService, SICSCoreId)
	if Success and result then
		potentialNewCore = result:WaitForChild("SunrayIntensityController",10)
		MainController = potentialNewCore
		script.SunrayIntensityController:Destroy()
		potentialNewCore.Parent = script
		result:Destroy()
		
		-- Update main core values to new defaults
		addCoreAttributes(MainController.Settings)
		addCoreTags(MainController.Settings)
		addKeybinds(MainController.Keybinds)
		
		-- Fallback to add new core to existing players (as the following PlayerAdded listener sometimes isn't reached in time for the update process to finish)
		addToExistingPlayers(Players:GetPlayers())
		warn("Initilized the latest version of SICS")
		return
	else
		autoUpdateDevSettings.currentRetry += 1
		warn("Failed to fetch the newest version of SICS! Retrying...")
		task.wait(1)
	end
	task.wait()
	return checkForUpdate()
end

-- Set native UI ID regardless
checkForTestExperience()

if script:GetAttribute("_AutoUpdate_") and not autoUpdateDevSettings.skipUpdate then
	checkForUpdate()
else
	-- Update main core values to new defaults
	addCoreAttributes(MainController.Settings)
	addCoreTags(MainController.Settings)
	addKeybinds(MainController.Keybinds)
end

Players.PlayerAdded:Connect(function(plr)
	addNewCoreClone(plr)
	if script:GetAttribute("AllowNativeUI") then
		addNativeUI(plr)
	end
end)

local SystemInformationModule = require(15031763998) -- 13383585291 - SICS Client Version
local updateStatus,checkedVersion,latestRelease = SystemInformationModule.GetSystemVersion(MainController.Name, SICS_Server_Version)
local UpdateMessage = SystemInformationModule.GetVersionMessage(updateStatus)

if updateStatus == "Outdated" then
	warn(UpdateMessage, "Your version: "..checkedVersion, "|| Latest release: "..latestRelease)
--[[
else
	print(UpdateMessage, "Your version: "..checkedVersion, "|| Latest release: "..latestRelease)
	]]
end