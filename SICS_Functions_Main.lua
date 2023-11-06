local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RepStorage = game:GetService("ReplicatedStorage")

local Sky
local SunrayPresets = require(script.Parent:WaitForChild("Presets",10))

local MainSky
local MainSkyBackup

MainConfig = {}

-- Stored Settings, Data, & System Information

MainConfig.isNightActive = false
MainConfig.NightSkyData = {
	SunTextureId = "rbxassetid://9525441443";
	SkyboxFaceLinks = "http://www.roblox.com/asset/?version=1&id=1014344"; --Every face on a default Roblox night sky is the same link, no need to list every one
	SunAngularSize = 11;
}

-- Main Sky Setup
if Lighting:FindFirstChildOfClass("Sky") then
	MainSky = Lighting:FindFirstChildOfClass("Sky")
else
	MainSky = Instance.new("Sky",Lighting)
end
MainSkyBackup = MainSky:Clone()

-- Handle Bloom

local BloomEffect = Lighting:FindFirstChildOfClass("BloomEffect")
local originalBloomSize
local originalBloomThreshold

if not BloomEffect then
	local bloom = Instance.new("BloomEffect",Lighting)
	bloom.Size = 22
	bloom.Threshold = 2.2
	originalBloomSize = bloom.Size
	originalBloomThreshold = bloom.Threshold
else
	originalBloomSize = BloomEffect.Size
	originalBloomThreshold = BloomEffect.Threshold
end

MainConfig.PresetList = { --If you add your own preset(s), add their name(s) to this list
	--Add your customs starting here. Underneath the line below are necessary for main system functionality.
	--"";

	--[[
		Side note:
		
		Most functions that work with the presets rely on string.lower(). So please keep newly added
			presets in this list all lowercase letters.
	]]

	-------------
	"realism";
	"cinematic";
	"default";
	"custom";
	"instant"
};


----------------------------------------------------------------------------------------

MainConfig.ObstructedTweenInfo = TweenInfo.new(
	5.21,
	Enum.EasingStyle.Quart,
	Enum.EasingDirection.Out
);

local sunShiftPhase1Info = TweenInfo.new(2.5,Enum.EasingStyle.Cubic,Enum.EasingDirection.In)
local sunShiftPhase2Info = TweenInfo.new(2.5,Enum.EasingStyle.Cubic,Enum.EasingDirection.Out)

function MainConfig:GetSky()
	return MainSky
end

local function tweenBloom(bloomInstance : Instance, newBloomSize : number, newBloomThreshold : number)
	local oldSize = bloomInstance.Size
	local oldThreshold = bloomInstance.Threshold
	local bloomTinfo = TweenInfo.new(1,Enum.EasingStyle.Sine,Enum.EasingDirection.Out)
	local TweenBloom = TweenService:Create(bloomInstance,bloomTinfo,{Size = newBloomSize, Threshold = newBloomThreshold})
	TweenBloom:Play()
end

function MainConfig:UpdateNightStatus(isNight)
	if MainConfig.isNightActive and isNight == false then --Turn Day if it's night
		local shiftPhase1
		if Lighting.ClockTime >= 12 then
			shiftPhase1 = TweenService:Create(Lighting,sunShiftPhase1Info,{ClockTime = 24})
		else
			shiftPhase1 = TweenService:Create(Lighting,sunShiftPhase1Info,{ClockTime = 0})
		end
		local shiftPhase2 = TweenService:Create(Lighting,sunShiftPhase2Info,{ClockTime = 8})
		shiftPhase1:Play()
		shiftPhase1.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed then
				if Lighting:FindFirstChildOfClass("BloomEffect") then
					local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
					tweenBloom(bloom,originalBloomSize,originalBloomThreshold)
				end
				MainConfig.isNightActive = false
				MainSky:Destroy()
				MainSky = MainSkyBackup:Clone()
				MainSky.Parent = Lighting
				shiftPhase2:Play()
			end
		end)
	elseif not MainConfig.isNightActive and isNight == true then --Turn night if it's day
		local shiftPhase1
		if Lighting.ClockTime >= 12 then
			shiftPhase1 = TweenService:Create(Lighting,sunShiftPhase1Info,{ClockTime = 24})
		else
			shiftPhase1 = TweenService:Create(Lighting,sunShiftPhase1Info,{ClockTime = 0})
		end
		local shiftPhase2 = TweenService:Create(Lighting,sunShiftPhase2Info,{ClockTime = 12})
		shiftPhase1:Play()
		MainSky.MoonAngularSize = 0
		shiftPhase1.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed then
				if Lighting:FindFirstChildOfClass("BloomEffect") then
					local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
					tweenBloom(bloom,10,3.6)
				end
				MainConfig.isNightActive = true
				MainSky.SkyboxBk = MainConfig.NightSkyData.SkyboxFaceLinks
				MainSky.SkyboxDn = MainConfig.NightSkyData.SkyboxFaceLinks
				MainSky.SkyboxFt = MainConfig.NightSkyData.SkyboxFaceLinks
				MainSky.SkyboxLf = MainConfig.NightSkyData.SkyboxFaceLinks
				MainSky.SkyboxRt = MainConfig.NightSkyData.SkyboxFaceLinks
				MainSky.SkyboxUp = MainConfig.NightSkyData.SkyboxFaceLinks
				MainSky.SunTextureId = MainConfig.NightSkyData.SunTextureId
				MainSky.MoonAngularSize = MainSkyBackup.MoonAngularSize
				MainSky.SunAngularSize = MainConfig.NightSkyData.SunAngularSize
				shiftPhase2:Play()
			end
		end)
	end
end

--// Forgiveness Radius \\--
script:SetAttribute("Forgiveness", MainConfig:GetSky().SunAngularSize)

function MainConfig:GetSetting(settingName : string)
	if settingName == nil then return warn("Valid setting required") end
	for attribute,value in pairs(script:GetAttributes()) do
		if string.lower(attribute) == string.lower(settingName) then
			return value
		end
	end
	return warn("Setting", settingName, "not found")
end

function MainConfig:SetSetting(settingName : string, newValue : any)
	if typeof(settingName) ~= "string" then return warn("Invalid :SetSetting(argument #1) - string expected, got", typeof(settingName)) end
	for attributeName,value in pairs(script:GetAttributes()) do
		if string.lower(attributeName) == string.lower(settingName) then
			if string.lower(settingName) == "activepreset" and table.find(MainConfig.PresetList,string.lower(newValue)) then
				script:SetAttribute(settingName, newValue)
				return
			elseif string.lower(settingName) == "activepreset" and not table.find(MainConfig.PresetList,string.lower(newValue)) then
				return warn("Preset:", "'"..newValue.."'", "not found!")
			end
			
			script:SetAttribute(settingName, newValue)
			return
		end
	end
	return warn("Setting", "'"..settingName.."'", "not found!")
end


return MainConfig