require(".\\Subsystems\\UEHelper")
require(".\\Config\\CONFIG")
local api = uevr.api
local vr = uevr.params.vr

local skylightIntensityDay = 1.0
local skylightIntensityNight = 0.
local sceneBrightnessSkylightScalar = 1.0
local settingUpdatesPPV = false

local currentSkylightIntensity = 1

local isInterior = false
local isDarkInterior = false

local PPVSettingsCache = {}
local PPVCache = {}
--local ppvIniData = LoadIni(iniPath .. "PPVSettings.ini")

local hasUpdatedSkylightSetting = false
local dynamicSkylight = true

local mappingToSkylightIntensity = {}
--l-ocal levelLabels = LoadIni(iniPath .. "level_labels.ini")['levels']

local interiorSunriseOffset = 0.05
local interiorSunsetOffset = 0.05
local interiorDayOffset = 0.10
local interiorNightOffset = -0.02

local sunrise = 5
local sunset = 5
local isSunrise = false
local isSunset = false
local isDay = true
local isNight = false

local sunSideAngle = 0
local sunAngleOffset = 0
local sunAngleIncreasing = false
local sunSideAngleIncreasing = false

local currentLevel = ''

local lastScattering = -1
local skyAtmosphere = nil
local sun = nil
local Reset=false
local sunrisePercentLast=1
local sunsetPercentLast=1
--local currentLightingMode = 'standard'

local lowerDiffuseLumen = false

local function doSkylightUpdate()
	print("doing skylight update")
			print("Day")
			print(isDay)
			print("night")
			print(isNight)
			print("Sunrise")
			print(isSunrise)
			print("interior")
			print(isInterior)
			sun = find_first_of('Class /Script/Altar.VAltarSunActor',false)

			if not sun  then
				print("could not find instance of BP_Sun_C")
			else
				print('valid sun')
				local newSunSideAngle = math.abs(sun['Sun Side Angle'])
				local newSunAngleOffset = math.abs(sun['SunAngleOffset'])

				isDay = false
				isNight = false
				isSunset = false
				isSunrise = false

				if newSunAngleOffset == 0 and newSunSideAngle == 0 then
					skyAtmosphere = find_first_of('Class /Script/Engine.SkyAtmosphereComponent')
					if skyAtmosphere  then
						
						local mieScattering = skyAtmosphere['MieScatteringScale']

						print('using sky atmosphere for the time ' .. mieScattering)

						if mieScattering > 0.03 then
							isDay = true
						elseif mieScattering > 0.01 then
							isDay = false
							isNight = false

							if mieScattering > lastScattering and lastScattering ~= -1 then
								isSunrise = true
								sunAngleOffset = (mieScattering - 0.01) * 25
								sunSideAngle = 0
							elseif mieScattering < lastScattering and lastScattering ~= -1 then
								isSunset = true
								sunAngleOffset = (mieScattering - 0.01) * 25
								sunSideAngle = 0
							else
								isSunset = false
								isSunrise = false
							end
						else
							isNight = true
						end

						lastScattering = mieScattering
					end
				else
					lastScattering = -1
					sunSideAngleIncreasing = newSunSideAngle > sunSideAngle
					sunAngleIncreasing = newSunAngleOffset > sunAngleOffset

					sunSideAngle = newSunSideAngle
					sunAngleOffset = newSunAngleOffset

					-- print("Sun info: " .. sunSideAngle .. ' ' .. sunAngleOffset)

					isSunset = sunSideAngle < sunrise and sunSideAngle > 0
					isSunrise = sunAngleOffset < sunrise and sunAngleOffset > 0

					isDay = sunSideAngle > 0
					isNight = sunAngleOffset > 0

					if isSunset and sunSideAngleIncreasing then
						isSunrise = true
						isSunset = false
					elseif isSunrise and sunAngleIncreasing then
						isSunrise = false
						isSunset = true
						sunAngleOffset = 0
					end
				end
			end
			local tempNight = skylightIntensityNight

			if isInterior then
				--tempNight = currentSkylightIntensity
			end
			
			
			--	if isNight or isInterior then
			--		uevr.api:execute_command("r.LightMaxDrawDistanceScale 20")
			--		uevr.api:execute_command("Altar.GraphicsOptions.Brightness -4")
			--		uevr.api:execute_command("r.SkylightIntensityMultiplier 0.00")
			--		elseif isDay and not isInterior then
			--		uevr.api:execute_command("r.LightMaxDrawDistanceScale 1")
			--		uevr.api:execute_command("Altar.GraphicsOptions.Brightness 0")
			--		uevr.api:execute_command("r.SkylightIntensityMultiplier 0.90")
			--		end

			local skylightIntensity = currentSkylightIntensity
			local Brightness = 4
			local MaxBrightness =0
			local MinBrightness =-4
		
			local diffNightDay = currentSkylightIntensity - tempNight
			
			 print("Current: " .. currentSkylightIntensity)
			 print("Night: " .. tempNight)
			
			if isSunrise then
				print("sunrise")
				local sunrisePercent = (sunAngleOffset + sunSideAngle) / sunrise
				if sunrisePercentLast-sunrisePercent< 0 and 0-sunrisePercent <-0.01 then
				skylightIntensity = tempNight + diffNightDay * sunrisePercent
				Brightness = -4 + 4*sunrisePercent
				else 
				skylightIntensity=tempNight
				Brightness=-4
				end
				sunrisePercentLast=sunrisePercent
				print(sunrisePercent)
								
			elseif isSunset and not isInterior then
				print("sunset " .. sunSideAngle .. ' ' .. sunAngleOffset)
				local sunsetPercent = (sunset - (sunSideAngle + sunAngleOffset)) / sunset
				if sunsetPercentLast-sunsetPercent< 0 and 0-sunsetPercent <-0.01 then
				skylightIntensity = skylightIntensity - diffNightDay * sunsetPercent
				Brightness= 0 - 4*sunsetPercent
				else 
				skylightIntensity=0
				Brightness=-4
				end
				print(sunsetPercent)
				sunsetPercentLast=sunsetPercent
			elseif isDay then
				print("day")
				Brightness=0
			--	if isInterior and not isDarkInterior then
					skylightIntensity = skylightIntensity --+ interiorDayOffset
				--end
			elseif isNight or isInterior then
				print("night")
				Brightness=-4
				skylightIntensity = tempNight
			--isNight or isInterior then
					uevr.api:execute_command("r.LightMaxDrawDistanceScale 20")
					--uevr.api:execute_command("Altar.GraphicsOptions.Brightness -4")
					--uevr.api:execute_command("r.SkylightIntensityMultiplier 0.00")
			--	if isInterior and not isDarkInterior then
			--		skylightIntensity = skylightIntensity + interiorNightOffset
			--	end
			else
				print("neither")
				skylightIntensity = tempNight
				Brightness=-4
			end
			
			 --;print(string.format("new skylight is %s", skylightIntensity))
			
			
			uevr.api:execute_command('r.SkylightIntensityMultiplier' .." ".. skylightIntensity)
			uevr.api:execute_command('Altar.GraphicsOptions.Brightness' .." ".. Brightness)
			
			
	
end


uevr.sdk.callbacks.on_pre_engine_tick(
function(engine, delta)

if DarkerDarks then
	doSkylightUpdate()
  local viewport = engine.GameViewport
        if viewport then
            local world = viewport.World
    
            if world then
                local level = world.PersistentLevel
				
				
				
				if last_level ~= level  then
				local WorldName = world:get_full_name()
    
				if not WorldName:find("World/") then
					print("Interior")
					isInterior=true
				else
					print("Exterior.")
					isInterior=false
				end
				
				
				end
				last_level=level
			end
		end
	
	


local pawn= api:get_local_pawn(0)

if pawn.WeaponsPairingComponent.TorchActor~=nil then
	local Intensity=2.5
	pawn.WeaponsPairingComponent.TorchActor["1_PointLight"]:SetIntensity(Intensity)
	pawn.WeaponsPairingComponent.TorchActor["1_PointLight"]:SetAttenuationRadius(1500)
	pawn.WeaponsPairingComponent.TorchActor["1_PointLight"]:SetLightFalloffExponent(6.1)
	pawn.WeaponsPairingComponent.TorchActor.BaseLightIntensity=Intensity
end
elseif	Reset==false then
	Reset=true
					uevr.api:execute_command("r.LightMaxDrawDistanceScale 1")
					uevr.api:execute_command("Altar.GraphicsOptions.Brightness 0")
					uevr.api:execute_command("r.SkylightIntensityMultiplier 0.90")
end
end)