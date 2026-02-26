-- Add/remove weapon hashes here to be added for holster checks.
-- For animations
holsterWeapons = {
	'WEAPON_FN509',
	'WEAPON_GLOCK19',
	'WEAPON_M9A3',
	'WEAPON_MP',
	'WEAPON_X2',
	'WEAPON_P99',
	'WEAPON_P226R',
	'WEAPON_SAFETYPISTOL',
	'WEAPON_P320C',
	'WEAPON_MODEL659',
	'WEAPON_TX22',
	'WEAPON_STUNGUN',
}

-- For holster/unholster DRAWABLES
HolsterConfig = {
	Weapons = {
	  [GetHashKey('WEAPON_FN509')] = true,
	  [GetHashKey('WEAPON_GLOCK19')] = true,
	  [GetHashKey('WEAPON_M9A3')] = true,
	  [GetHashKey('WEAPON_MP')] = true,
	  [GetHashKey('WEAPON_P99')] = true,
	  [GetHashKey('WEAPON_P226R')] = true,
	  [GetHashKey('WEAPON_SAFETYPISTOL')] = true,
	  [GetHashKey('WEAPON_P320C')] = true,
	  [GetHashKey('WEAPON_MODEL659')] = true,
	  [GetHashKey('WEAPON_TX22')] = true,
	},
	Peds = {
		[GetHashKey('mp_m_freemode_01')] = {
		  [7] = {
			[193] = 194,
			[195] = 196,
			[183] = 182,
			[185] = 184,
		  },
		},
	},
}

local holstered = true
keepHandOnHolster = false
stopHolsterAnimation = false
pistolweapon = nil

function CheckWeapon(ped)
	for i = 1, #holsterWeapons do
		if GetHashKey(holsterWeapons[i]) == GetSelectedPedWeapon(ped) then
			return true
		end
	end
	return false
end

Citizen.CreateThread(function()
	while true do
		local ped = PlayerPedId()

		if not (GetPedParachuteState(ped) == 2) then
			playerModel = GetEntityModel(ped)

   			if CheckWeapon(ped) then
				if holstered then
					if not (stopHolsterAnimation or IsPedInAnyVehicle(ped, true)) then
						
						if playerModel == GetHashKey("mp_m_freemode_01")
							and GetPedDrawableVariation(ped, 7) > 177
							and GetWeapontypeGroup(GetSelectedPedWeapon(ped)) == 416676503 then

							loadAnimDict("rcmjosh4")
							-- -- TaskPlayAnim(ped,"rcmjosh4","josh_leadout_cop2",8.0,2.0,-1,48,10,0,0,0)
							Citizen.Wait(600)
							ClearPedTasks(ped)

						elseif playerModel == GetHashKey("mp_m_freemode_01")
							and GetPedDrawableVariation(ped, 8) > 206
							and GetWeapontypeGroup(GetSelectedPedWeapon(ped)) == 690389602 then

							RequestAnimDict("combat@reaction_aim@pistol")
							-- -- TaskPlayAnim(ped,"combat@reaction_aim@pistol","0",8.0,2.0,-1,48,10,0,0,0)
							Citizen.Wait(300)
							ClearPedTasks(ped)

						else
							RequestAnimDict("combat@reaction_aim@pistol")
							-- -- TaskPlayAnim(ped,"combat@reaction_aim@pistol","-0",8.0,2.0,-1,48,10,0,0,0)
							Citizen.Wait(300)
							ClearPedTasks(ped)
						end

						if playerModel == GetHashKey("mp_m_freemode_01") then
							if (GetPedDrawableVariation(ped, 7) == 193 or GetPedDrawableVariation(ped, 7) == 194)
								and GetSelectedPedWeapon(ped) ~= GetHashKey("WEAPON_FN509")
								and GetWeapontypeGroup(GetSelectedPedWeapon(ped)) == 416676503 then

								PlaySoundFrontend(-1,"Highlight_Error","DLC_HEIST_PLANNING_BOARD_SOUNDS",1)
								ShowInfo("~BLIP_info_icon~ You are using the incorrect holster for this gun.")

							elseif (GetPedDrawableVariation(ped, 7) == 180 or GetPedDrawableVariation(ped, 7) == 181)
								and GetSelectedPedWeapon(ped) ~= GetHashKey("WEAPON_GLOCK19")
								and GetWeapontypeGroup(GetSelectedPedWeapon(ped)) == 416676503 then

								PlaySoundFrontend(-1,"Highlight_Error","DLC_HEIST_PLANNING_BOARD_SOUNDS",1)
								ShowInfo("~BLIP_info_icon~ You are using the incorrect holster for this gun.")

							elseif (GetPedDrawableVariation(ped, 7) == 182 or GetPedDrawableVariation(ped, 7) == 183)
								and GetSelectedPedWeapon(ped) ~= GetHashKey("WEAPON_MP")
								and GetWeapontypeGroup(GetSelectedPedWeapon(ped)) == 416676503 then

								PlaySoundFrontend(-1,"Highlight_Error","DLC_HEIST_PLANNING_BOARD_SOUNDS",1)
								ShowInfo("~BLIP_info_icon~ You are using the incorrect holster for this gun.")

							elseif (GetPedDrawableVariation(ped, 7) == 184 or GetPedDrawableVariation(ped, 7) == 185)
								and GetSelectedPedWeapon(ped) ~= GetHashKey("WEAPON_GLOCK19")
								and GetWeapontypeGroup(GetSelectedPedWeapon(ped)) == 416676503 then

								PlaySoundFrontend(-1,"Highlight_Error","DLC_HEIST_PLANNING_BOARD_SOUNDS",1)
								ShowInfo("~BLIP_info_icon~ You are using the incorrect holster for this gun.")
							end
						end
					end

					holstered = false
					weapon = GetSelectedPedWeapon(ped)
				end

			else
				if not holstered then
					if not (stopHolsterAnimation or IsPedInAnyVehicle(ped, true)) then

						if playerModel == GetHashKey("mp_m_freemode_01")
							and GetPedDrawableVariation(ped, 7) > 177
							and GetWeapontypeGroup(weapon) == 416676503 then

							loadAnimDict("rcmjosh4")
							-- -- TaskPlayAnim(ped,"rcmjosh4","josh_leadout_cop2",8.0,2.0,-1,48,10,0,0,0)
							Citizen.Wait(600)
							ClearPedTasks(ped)

						elseif playerModel == GetHashKey("mp_m_freemode_01")
							and GetPedDrawableVariation(ped, 8) > 206
							and GetWeapontypeGroup(weapon) == 690389602 then

							RequestAnimDict("combat@reaction_aim@pistol")
							-- -- TaskPlayAnim(ped,"combat@reaction_aim@pistol","0",8.0,2.0,-1,48,10,0,0,0)
							Citizen.Wait(300)
							ClearPedTasks(ped)

						else
							RequestAnimDict("combat@reaction_aim@pistol")
							-- -- TaskPlayAnim(ped,"combat@reaction_aim@pistol","-0",8.0,2.0,-1,48,10,0,0,0)
							Citizen.Wait(300)
							ClearPedTasks(ped)
						end
					end

					holstered = true
				end
			end
		end

		if GetWeapontypeGroup(GetSelectedPedWeapon(ped)) == 416676503 then
			pistolweapon = GetSelectedPedWeapon(ped)
		end

		Citizen.Wait(200)
	end
end)

RegisterKeyMapping("holster", "Stage Holster", "keyboard", "")
RegisterCommand("holster", function()
	local ped = PlayerPedId()

	loadAnimDict("anim@holster_walk")
	loadAnimDict("anim@holster_hold_there")

	if keepHandOnHolster then
		ClearPedTasks(ped)
		SetCurrentPedWeapon(ped,GetHashKey("WEAPON_UNARMED"),true)
		keepHandOnHolster = false
		Citizen.Wait(500)
		stopHolsterAnimation = false

	elseif not IsPedInAnyVehicle(ped, true) and not IsControlPressed(0,21) then
		keepHandOnHolster = true
		stopHolsterAnimation = true

		-- TaskPlayAnim(ped,"anim@holster_walk","holster_walk",8.0,2.0,-1,50,2.0,0,0,0)

		while keepHandOnHolster do
			Citizen.Wait(0)

			if IsControlPressed(0,25) then
				for i = 1, #holsterWeapons do
					SetCurrentPedWeapon(ped, GetHashKey(holsterWeapons[i]), true)
				end

				SetCurrentPedWeapon(ped, pistolweapon, true)
				ClearPedTasks(ped)
				keepHandOnHolster = false
				Citizen.Wait(500)
				stopHolsterAnimation = false

			elseif IsControlPressed(0,21) then
				ClearPedTasks(ped)
				keepHandOnHolster = false
				stopHolsterAnimation = false
			end
		end
	end
end)

local lastWeapon = nil
local lastDrawable = nil
local lastComponent = nil

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1000)
		local ped = PlayerPedId()
		local hash = GetEntityModel(ped)

		if HolsterConfig.Peds[hash] then
			repeat
				local currentWeapon = GetSelectedPedWeapon(ped)

				if currentWeapon ~= lastWeapon then
					
					if HolsterConfig.Weapons[lastWeapon] and lastComponent then
						
						local drawable = GetPedDrawableVariation(ped, lastComponent)

						if lastDrawable ~= drawable
							and HolsterConfig.Peds[hash][lastComponent][lastDrawable] == drawable then

							local texture = GetPedTextureVariation(ped, lastComponent)
							SetPedComponentVariation(ped,lastComponent,lastDrawable,texture,0)
							TriggerServerEvent("InteractSound_SV:PlayWithinDistance",1.0,"Holster",0.5)
						
						else
							lastDrawable = nil
							lastComponent = nil
						end

					elseif HolsterConfig.Weapons[currentWeapon] then

						for component, holsters in pairs(HolsterConfig.Peds[hash]) do
							local drawable = GetPedDrawableVariation(ped, component)
							local texture = GetPedTextureVariation(ped, component)

							if holsters[drawable] then
								lastDrawable = drawable
								lastComponent = component
								SetPedComponentVariation(ped,component,holsters[drawable],texture,0)
								TriggerServerEvent("InteractSound_SV:PlayWithinDistance",1.0,"Unholster",0.5)
								break
							end
						end
					end
				end

				lastWeapon = currentWeapon
				Citizen.Wait(200)
			until not HolsterConfig.Peds[GetEntityModel(ped)]
		end
	end
end)
