local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local RepStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local StarterGui = game:GetService("StarterGui")

local plr = Players.LocalPlayer

local CurrentCamera = workspace.CurrentCamera

local ConfigModule = script:WaitForChild("Settings",10)
local PresetsModule = script:WaitForChild("Presets",10)
local InputFunctionsModule = script:WaitForChild("InputFunctions",10)

local SunrayConfig = require(ConfigModule)
local SunrayPresets = require(PresetsModule)
local InputFunctions = require(InputFunctionsModule)
-------------------------------------------------------------------
--Fake sun stuff to track objects obscuring the player's view of the sun
local distFromCam = 500;
local SunPositionPart

--Essential Sky Assets and Values
local NearSunrays
local FarSunrays
local CurrentAngle
local Sky
local Forgiveness
local ForgivenessRadius

--Device Info
local isKeyboard
local isMobile
local isGamepad

--Debug Options
local enableDebugMessages = false

local function printDebug(msgString,optional1,optional2,optional3)
	if enableDebugMessages then
		if optional1 then
			print(msgString,optional1)
		elseif optional2 then
			print(msgString,optional1,optional2)
		elseif optional3 then
			print(msgString,optional1,optional2,optional3)
		else
			print(msgString)
		end
	end
end

if UIS.KeyboardEnabled and UIS.GamepadEnabled then
	isKeyboard = true
	isMobile = false
	isGamepad = true
elseif UIS.KeyboardEnabled and not UIS.GamepadEnabled then
	isKeyboard = true
	isMobile = false
	isGamepad = false
elseif UIS.TouchEnabled and not UIS.GamepadEnabled then
	isKeyboard = false
	isMobile = true
	isGamepad = false
elseif UIS.TouchEnabled and UIS.GamepadEnabled then
	isKeyboard = false
	isMobile = true
	isGamepad = true
end

--Create new fake sun part (located far away in the direction of the sun)
local function NewSunPart()
	if game.Workspace.CurrentCamera:FindFirstChild("SunPositionBrick") then
		game.Workspace.CurrentCamera.SunPositionBrick:Destroy() --Create a new fake sun in case the old one bugged out for any reason
	end

	local part = Instance.new("Part")
	part.Name = "SunPositionBrick"
	part.Anchored = true
	part.Material = Enum.Material.ForceField
	part.Reflectance = 1000
	part.Color = Color3.fromRGB(255,255,255)
	part.Size = Vector3.new() * SunrayConfig:GetSky().SunAngularSize
	part.Shape = Enum.PartType.Ball
	part.CastShadow = false
	part.Parent = workspace.CurrentCamera
	part.CanCollide = false
	SunPositionPart = part
end

NewSunPart()
------------------------------------------------------------------
repeat task.wait() Sky = SunrayConfig:GetSky() until SunrayConfig:GetSky() ~= nil
script.Parent = plr.PlayerScripts
local function getIgnoredParts()
	local ignoreList = {plr.Character,SunPositionPart}
	for i,tag in pairs(ConfigModule:GetTags()) do
		for i,taggedInstance in pairs(CollectionService:GetTagged(tag)) do
			table.insert(ignoreList,taggedInstance)
		end
	end
	return ignoreList
end

local function SunToCamera(Character) --Is sun on screen and unobstructed?
	local _, OnScreen = workspace.CurrentCamera:WorldToScreenPoint(SunPositionPart.Position)
	local ignoreList = getIgnoredParts()
	
	local PlayerRoot = Character:WaitForChild("HumanoidRootPart",3)
	local rayStartPart = CurrentCamera
	local rayfinishPart = SunPositionPart

	local rayStartPosition = rayStartPart.CFrame.Position
	local rayDestination = rayfinishPart.Position
	local rayDirection = rayDestination - rayStartPosition
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {ignoreList}
	raycastParams.IgnoreWater = true
	
	if SunrayConfig:GetSetting("IgnoreTerrain") then
		raycastParams:AddToFilter(workspace.Terrain)
	end
	
	local NumOfObstructions = #workspace.CurrentCamera:GetPartsObscuringTarget({workspace.CurrentCamera.CFrame.Position,SunPositionPart.Position},ignoreList)
	local result = workspace:Raycast(rayStartPosition, rayDirection * (rayStartPosition - rayDestination).magnitude,raycastParams)
	
	if not SunrayConfig:GetSetting("IgnoreTerrain") then --Terrain Obstruction
		if result and result.Material ~= nil then
			return "OSO"
		end
	end
	
	if OnScreen then
		if NumOfObstructions == 0 then
			return "OSU" -- On-screen & unobstructed
		else
			return "OSO" -- On-screen & obstructed
		end
	else
		return "OFS" --Sun is off-screen
	end
end

local function RoundNumber(NumberToRound,DecimalPlaces)
	if NumberToRound == nil then
		return
	end
	local Multiplier = 10^(DecimalPlaces or 2)
	local Number = math.floor(NumberToRound*Multiplier)/Multiplier
	return Number
end

local function getForgivenessRadius(currentForgiveness)
	local radius = RoundNumber(math.cos(math.rad(currentForgiveness)))
	return radius
end

local HorizonRadius = RoundNumber(math.cos(math.rad(90)))

local function SetSunPosition()
	SunPositionPart.Size = Vector3.new() * SunrayConfig:GetSky().SunAngularSize
	SunPositionPart.Position = workspace.CurrentCamera.CFrame.Position + Lighting:GetSunDirection() * distFromCam;
end

--Get Preset TweenInfo
local function GetPresetInfo()
	local ChosenPreset
	if SunrayConfig:GetSetting("ActivePreset") == nil or
		SunrayConfig:GetSetting("ActivePreset") == "" or
		string.lower(SunrayConfig:GetSetting("ActivePreset")) == "default" then
		ChosenPreset = SunrayPresets.default
		return ChosenPreset
	elseif string.lower(SunrayConfig:GetSetting("ActivePreset")) == "custom" then
		ChosenPreset = SunrayPresets.custom
		return ChosenPreset
	else
		ChosenPreset = SunrayPresets[string.lower(SunrayConfig:GetSetting("ActivePreset"))]
		return ChosenPreset
	end
end

function CreateSunrayEffect()
	for i,v in pairs(Lighting:GetChildren()) do
		if v:IsA("SunRaysEffect") then
			v:Destroy()
		end
	end

	--Add a new SunRaysEffect if one doesn't already exist
	local NewNearSunrays = Instance.new("SunRaysEffect",Lighting)
	NewNearSunrays.Name = "NearSunRays"
	NewNearSunrays.Intensity = 0.085
	NewNearSunrays.Spread = 0.1
	NearSunrays = NewNearSunrays

	local NewFarSunrays = Instance.new("SunRaysEffect",Lighting)
	NewFarSunrays.Name = "FarSunRays"
	NewFarSunrays.Intensity = SunrayConfig:GetSetting("NearSunRaysIntensity")
	NewFarSunrays.Spread = SunrayConfig:GetSetting("DefaultSpread")
	FarSunrays = NewFarSunrays
end

CreateSunrayEffect()
SunrayConfig:SetSetting("Forgiveness", Sky.SunAngularSize)

--Get the sun angle relative to the camera and return the result
local function RoundAngle(Value,decimalPlaces)
	local CurrentAngle = Value
	local Result = CurrentAngle
	local mult = 10^(decimalPlaces or 2)
	Result = math.floor(Result*mult) / mult
	return Result
end

--This function will do the actual updating of the sunray intensity. Prior calculations are done by a function located below
local function updateIntensity(newIntensityValue,isObstructed)
	if SunrayConfig.isNightActive then
		FarSunrays.Intensity = 0.02
		NearSunrays.Intensity = 0.025
		return
	else
		if NearSunrays.Intensity ~= SunrayConfig:GetSetting("NearSunRaysIntensity") then
			NearSunrays.Intensity = SunrayConfig:GetSetting("NearSunRaysIntensity")
		end
	end

	if string.lower(SunrayConfig:GetSetting("ActivePreset")) == "instant" then
		FarSunrays.Intensity = newIntensityValue - (newIntensityValue * SunrayConfig:GetSetting("Dampening"))
	else
		if isObstructed then
			local TweenIntensity = TweenService:Create(FarSunrays,SunrayConfig.ObstructedTweenInfo,{Intensity = newIntensityValue - (newIntensityValue * SunrayConfig:GetSetting("Dampening"))})
			TweenIntensity:Play()
		else
			local TweenIntensity = TweenService:Create(FarSunrays,GetPresetInfo(),{Intensity = newIntensityValue - (newIntensityValue * SunrayConfig:GetSetting("Dampening"))})
			TweenIntensity:Play()
		end
	end
end

--Double check wait for sunray creation
if FarSunrays == nil or NearSunrays == nil then
	repeat
		CreateSunrayEffect()
		task.wait(1)
	until Lighting[FarSunrays] ~= nil and Lighting[NearSunrays] ~= nil
end

--[[
	Every heartbeat this script checks the camera direction relative
		to the current position of the sun on the client
]]

local function tweakSunray()
	-- Make sure SunPositionPart (Fake sun, a physical object) exists
	if SunPositionPart == nil then
		repeat NewSunPart() task.wait(0.5) until SunPositionPart ~= nil
	end
	SetSunPosition() --This should always update first after the fake sun is confirmed to exist
	Forgiveness = SunrayConfig:GetSetting("Forgiveness")
	ForgivenessRadius = RoundNumber(math.cos(math.rad(Forgiveness)))
	local dirSun = Lighting:GetSunDirection()
	local dirCamera = CurrentCamera.CFrame.LookVector
	CurrentAngle = RoundAngle(dirSun:Dot(dirCamera))
	local CurrentAngleInversed = RoundNumber((CurrentAngle * -1))
	local RoundedDirectIntensity = RoundNumber(CurrentAngleInversed+(1-ForgivenessRadius)+ForgivenessRadius) * 2
	local chr = plr.Character or plr.CharacterAdded:Wait()
	local sunObstructed = SunToCamera(chr)
	FarSunrays.Spread = SunrayConfig:GetSetting("DefaultSpread")
	
	--Handle SunRaysEffect Intensity
	if Lighting.ClockTime >= 6 and Lighting.ClockTime < 18 then --Must be daytime for this to take effect
		if CurrentAngle >= HorizonRadius then -- (If within the horizon radius)
			if sunObstructed == "OSO" then -- OSU = On-screen & unobstructed || OSO = On-screen & obstructed || OFS = Sun is off-screen
				updateIntensity(SunrayConfig:GetSetting("IntensityObstructed"),true)
			elseif CurrentAngle >= ForgivenessRadius and sunObstructed == "OSU" then --Within forgiveness radius
				if Forgiveness >= 30 then
					updateIntensity((RoundNumber((-1 * (CurrentAngleInversed+(1-ForgivenessRadius)) - 1) * -1,2)),false)
				elseif Forgiveness <= 30 and Forgiveness >= 22 then
					updateIntensity((RoundNumber((-1 * (CurrentAngleInversed+(1-ForgivenessRadius)) - 1) * -1,2)),false)
				elseif Forgiveness < 22 then
					updateIntensity(1-ForgivenessRadius,false)
				end
			elseif CurrentAngle < ForgivenessRadius and CurrentAngle >= HorizonRadius then --Within horizon radius, but sun is off-screen
				if Forgiveness >= 30 then
					updateIntensity((RoundNumber((-1 * (CurrentAngleInversed+(1-ForgivenessRadius)) - 1) * -1,2)),false)
				elseif Forgiveness <= 30 and Forgiveness >= 22 then
					updateIntensity(RoundedDirectIntensity-(ForgivenessRadius/20),false)
				elseif Forgiveness < 22 then
					updateIntensity(RoundedDirectIntensity-(ForgivenessRadius/20),false)
				end
			end
		else --Outside the horizon radius (sun should be totally off-screen)
			if CurrentAngle < HorizonRadius then
				updateIntensity(RoundedDirectIntensity,false)
			end
		end
	else --Night time
		if FarSunrays.Intensity ~= SunrayConfig:GetSetting("IntensityOffScreen") then
			updateIntensity(SunrayConfig:GetSetting("IntensityOffScreen"),false)
		end
	end
end

RunService.Heartbeat:Connect(tweakSunray)

------------------------------------------------------------------

-- Update forgiveness if sun size changes
Lighting:FindFirstChildOfClass("Sky"):GetPropertyChangedSignal("SunAngularSize"):Connect(function()
	SunrayConfig:SetSetting("Forgiveness", Sky.SunAngularSize)
end)

------------------------------------------------------------------

------------------------------------------------------------------

------------------------------------------------------------------

------------------------------------------------------------------

--Native UI Handler

if ConfigModule:GetAttribute("AllowNativeUI") == true then
	repeat task.wait() until plr.PlayerGui:FindFirstChild("SICSPanel")
	local KeybindsModule = script:WaitForChild("Keybinds",10)
	local Keybinds = require(KeybindsModule)
	local OpenPhaseSize = UDim2.new(1,0,1,0)
	local ClosePhaseSize = UDim2.new(0,0,1,0)
	local plrGui = plr:WaitForChild("PlayerGui")
	local TransitionTime = 0.5
	local TopBar = require(script:WaitForChild("TopBar",10))
	local MarketplaceService = game:GetService("MarketplaceService")
	
	local SICSPanelToggler
	local SICSPanelUI = plrGui.SICSPanel
	local BackgroundFrame = SICSPanelUI:WaitForChild("Background",10)
	local LowerFrame = BackgroundFrame:WaitForChild("LowerFrame",10)
	local HousingFrame = LowerFrame:WaitForChild("Housing",10)
	local Credit = HousingFrame:WaitForChild("Credit",10)

	local ButtonFrame = HousingFrame:WaitForChild("ButtonFrame",10)
	local CloseMenuButton = ButtonFrame:WaitForChild("CloseMenu",10)
	local GetSICSButton = ButtonFrame:WaitForChild("GetSystem",10)

	local function setKeybindTip(keyList)
		local tip = "SICS".." ["
		for i=1,#keyList do
			tip = tip..keyList[i].Name
			if i == #keyList then tip = tip.."]" else tip = tip.." + " end
		end
		SliderToggler:setTip(tip)
	end
	
	if script:GetAttribute("SICS_Server_Version") and tonumber(script:GetAttribute("SICS_Server_Version")) >= 2.3 then
		local SICSGlobalData = plr:WaitForChild("SICS",10)
		
		for i,dataName in pairs(SICSGlobalData:GetChildren()) do
			SunrayConfig:SetSetting(dataName.Name, dataName.Value)
			dataName:GetPropertyChangedSignal("Value"):Once(function()
				SunrayConfig:SetSetting(dataName.Name, dataName.Value)
			end)
		end
		SICSGlobalData.ChildAdded:Connect(function(dataName)
			SunrayConfig:SetSetting(dataName.Name, dataName.Value)
			dataName:GetPropertyChangedSignal("Value"):Once(function()
				SunrayConfig:SetSetting(dataName.Name, dataName.Value)
			end)
		end)
	
	
		Keybinds:InitializeBinds() -- Setup Keybinds
		-------
	end
	if SliderToggler == nil then
		SliderToggler = TopBar.new()
			:autoDeselect(false)
			:setName("SliderToggler")
			:setImage(1068088395)
		if string.find(InputFunctions.getInputType(),"Keyboard") or InputFunctions.getInputType == "Gamepad" then
			local inputType = InputFunctions.getInputType()
			inputType = (string.gsub(inputType,"InputType_",""))
			setKeybindTip(Keybinds.NativeMenuKeybind[inputType])
		end
	end
	
	-- Phase Functions

	local function OpenPhase()
		BackgroundFrame:TweenSize(OpenPhaseSize,Enum.EasingDirection.InOut,Enum.EasingStyle.Quart,TransitionTime,true)
	end

	local function ClosePhase()
		BackgroundFrame:TweenSize(ClosePhaseSize,Enum.EasingDirection.InOut,Enum.EasingStyle.Quart,TransitionTime,true)
	end
	
	local enabledCoreGui = {}
	
	-- Event Connections
	local CoreGuiEnums = {
		Enum.CoreGuiType.Backpack,
		Enum.CoreGuiType.Health,
		Enum.CoreGuiType.PlayerList,
		Enum.CoreGuiType.Chat,
		Enum.CoreGuiType.EmotesMenu,
	}
	
	local function setCoreUIEnabled(isGuiEnabled)
		if isGuiEnabled and #enabledCoreGui > 0 then
			for i,v in pairs(enabledCoreGui) do
				StarterGui:SetCoreGuiEnabled(v,isGuiEnabled)
			end
		else
			for i,v in pairs(CoreGuiEnums) do
				StarterGui:SetCoreGuiEnabled(v,isGuiEnabled)
			end
		end
	end
	
	local function pressingRequiredKeys(requiredKeys)
		for i,key in pairs(requiredKeys) do
			if not table.find(InputFunctions.getKeysPressed(),key) then return false end
		end
		return true
	end
	
	ConfigModule.AttributeChanged:Connect(function(attribute)
		--print(attribute,"changed values to", ConfigModule:GetAttribute(attribute))
		script.DataStore.UpdateData:FireServer(attribute, ConfigModule:GetAttribute(attribute))
	end)
	
	UIS.InputBegan:Connect(function(input, isTyping)
		local inputType = InputFunctions.getInputType()
		inputType = (string.gsub(inputType,"InputType_",""))
		if pressingRequiredKeys(Keybinds.NativeMenuKeybind[inputType]) and (not UIS:GetFocusedTextBox() and not isTyping) then
			local selectedOrDeselectedString = SliderToggler:getToggleState()
			if selectedOrDeselectedString == "selected" and not SliderToggler.locked then
				SliderToggler:deselect()
				SliderToggler:debounce(TransitionTime)
			elseif selectedOrDeselectedString == "deselected" and not SliderToggler.locked then
				SliderToggler:select()
				SliderToggler:debounce(TransitionTime)
			end
		end
		--if (InputFunctions.getKeysPressed() == Keybinds.NativeMenuKeybind.Keyboard or InputFunctions.getKeysPressed() == Keybinds.NativeMenuKeybind.Gamepad) and (not UIS:GetFocusedTextBox() and not isTyping) then
		--end
	end)
	
	CloseMenuButton.Activated:Connect(function(inputObject)
		SliderToggler:deselect()
		SliderToggler:debounce(TransitionTime)
	end)
	
	GetSICSButton.Activated:Connect(function(inputObject)
		MarketplaceService:PromptPurchase(plr, 13400931193, false)
	end)
	
	SliderToggler.selected:Connect(function()
		SICSPanelUI.Enabled = true
		table.clear(enabledCoreGui)
		for i,coreUIEnum in pairs(CoreGuiEnums) do
			if StarterGui:GetCoreGuiEnabled(coreUIEnum) then table.insert(enabledCoreGui, coreUIEnum) end
		end
		setCoreUIEnabled(false)
		BackgroundFrame.Size = ClosePhaseSize
		OpenPhase()
	end)

	SliderToggler.deselected:Connect(function()
		ClosePhase()
		task.wait(TransitionTime)
		SICSPanelUI.Enabled = false
		setCoreUIEnabled(true)
	end)

	for i,foundTextLabel in pairs(SICSPanelUI:GetDescendants()) do
		if foundTextLabel and foundTextLabel:IsA("TextLabel") then
			local newSizeConstraint = Instance.new("UITextSizeConstraint",foundTextLabel)
			if isMobile then
				newSizeConstraint.MaxTextSize = 28
			else
				newSizeConstraint.MaxTextSize = 40
			end
			newSizeConstraint.MinTextSize = 14
		end
	end
end


--[[
	
		BELOW THIS TEXT IS TEST PLACE UI STUFF ---> (SAFE TO KEEP OR DELETE)
		
		This updates the UI in my testing place. This will only check if the game is my test place via GameId.
		Meaning, the below block of code is safe to stay or remove, it will not make any changes to your experiences or places.
	
	]]
------------------------------------------------------------------

-- Test Experience UI Handler
if (game.GameId == 4664865401 or game.GameId == 4512400337) then
	local TopBar = require(RepStorage:WaitForChild("TopBar",10))
	local CoreDropdown
	local RayInfoToggler
	local nightToggler
	local PresetDropdown
	local isButtonSelected
	local plrGui = plr:WaitForChild("PlayerGui")
	local TestUI = plrGui:WaitForChild("AngleFromSun",4)
	
	-------

	local isKeyboard
	local isMobile
	local isGamepad

	if UIS.KeyboardEnabled and UIS.GamepadEnabled then
		isKeyboard = true
		isMobile = false
		isGamepad = true
	elseif UIS.KeyboardEnabled and not UIS.GamepadEnabled then
		isKeyboard = true
		isMobile = false
		isGamepad = false
	elseif UIS.TouchEnabled and not UIS.GamepadEnabled then
		isKeyboard = false
		isMobile = true
		isGamepad = false
	elseif UIS.TouchEnabled and UIS.GamepadEnabled then
		isKeyboard = false
		isMobile = true
		isGamepad = true
	end

	task.spawn(function()
		if RayInfoToggler == nil then
			RayInfoToggler = TopBar.new()
			RayInfoToggler:autoDeselect(false)
			RayInfoToggler:setName("RayInfoToggler")
			RayInfoToggler:setLabel("Info")
			RayInfoToggler:setTip("Toggle (Q)")
			RayInfoToggler:select()
		end

		if nightToggler == nil then
			nightToggler = TopBar.new()
			nightToggler:autoDeselect(false)
			nightToggler:setName("nightToggler")
			nightToggler:setLabel("Night")
			nightToggler:setTip("Toggle (V)")
		end

		if PresetDropdown == nil then
			PresetDropdown = TopBar.new()
			PresetDropdown:autoDeselect(true)
			PresetDropdown:setName("PresetsDropdown")
			PresetDropdown:setLabel("Presets")

			PresetDropdown:set("dropdownSquareCorners", false)
			PresetDropdown:setDropdown({
				TopBar.new()
					:setLabel("Default")
					:setName("DefaultPreset")
					:bindEvent("selected", function(self)
						SunrayConfig:SetSetting("ActivePreset","Default")
					end),
				TopBar.new()
					:setLabel("Realism")
					:setName("RealismPreset")
					:bindEvent("selected", function(self)
						SunrayConfig:SetSetting("ActivePreset","Realism")
					end)
					:select(),
				TopBar.new()
					:setLabel("Cinematic")
					:setName("CinematicPreset")
					:bindEvent("selected", function(self)
						SunrayConfig:SetSetting("ActivePreset","Cinematic")
					end),
				TopBar.new()
					:setLabel("Custom")
					:setName("CustomPreset")
					:bindEvent("selected", function(self)
						SunrayConfig:SetSetting("ActivePreset","Custom")
					end),
				TopBar.new()
					:setLabel("Instant")
					:setName("InstantPreset")
					:bindEvent("selected", function(self)
						SunrayConfig:SetSetting("ActivePreset","Instant")
					end),
			})
		end
		
		task.wait(2)
		while true do
			local character = plr.Character or plr.CharacterAdded:Wait()
			isButtonSelected = RayInfoToggler.isSelected

			if TestUI ~= nil then
				local MainFrame = TestUI:WaitForChild("MainFrame")
				local AngleLabel = MainFrame:WaitForChild("Angle")
				local OuterForgivenessLabel = MainFrame:WaitForChild("ForgivenessRadius")
				local IntensityLabel = MainFrame:WaitForChild("Intensity")

				AngleLabel.Text = "Current Angle: "..tostring(RoundNumber(CurrentAngle,2))
				IntensityLabel.Text = "Intensity: "..tostring(RoundNumber(FarSunrays.Intensity,2))
				OuterForgivenessLabel.Text = "Forgiveness: "..tostring(RoundNumber(getForgivenessRadius(Forgiveness),2)).." ("..tostring(RoundNumber(Forgiveness,2))..")".."("..tostring(RoundNumber(ForgivenessRadius/6,2))..", "..tostring(RoundNumber(ForgivenessRadius/20,2))..")"
			end
			RunService.Heartbeat:Wait()
		end
	end)

	UIS.InputBegan:Connect(function(input, gameProcessedEvent)
		if input.KeyCode == Enum.KeyCode.Q and plr.Character:FindFirstChildOfClass("Humanoid").Health > 0 and not UIS:GetFocusedTextBox() then
			if RayInfoToggler.isSelected then
				RayInfoToggler:deselect()
			else
				RayInfoToggler:select()
			end

		elseif input.KeyCode == Enum.KeyCode.V and plr.Character:FindFirstChildOfClass("Humanoid").Health > 0 and not UIS:GetFocusedTextBox() then
			if RayInfoToggler.isSelected then
				RayInfoToggler:deselect()
			else
				RayInfoToggler:select()
			end
		end
	end)

	RayInfoToggler.selected:Connect(function()
		TestUI.MainFrame.Visible = true
	end)
	RayInfoToggler.deselected:Connect(function()
		TestUI.MainFrame.Visible = false
	end)

	nightToggler.selected:Connect(function()
		SunrayConfig:UpdateNightStatus(true)
	end)
	nightToggler.deselected:Connect(function()
		SunrayConfig:UpdateNightStatus(false)
	end)
end