-- Variables.
local k9_name = "K9 Dog"
local spawned_ped = nil
local following = false
local attacking = false
local attacked_player = 0
local searching = false

local animations = {
    ['Normal'] = {
        sit = {
            dict = "creatures@rottweiler@amb@world_dog_sitting@base",
            anim = "base"
        },
        laydown = {
            dict = "creatures@rottweiler@amb@sleep_in_kennel@",
            anim = "sleep_in_kennel"
        },
        itch = {
            dict = "creatures@rottweiler@amb@world_dog_sitting@idle_a",
            anim = "idle_a"
        },
        searchhit = {
            dict = "creatures@rottweiler@indication@",
            anim = "indicate_high"
        }
    }
}


-- Tables
local language = {}

-- Open Menu --
function EnableMenu()
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "open_k9_menu"
    })
end


-- NUI callbacks.

RegisterNUICallback("closemenu", function(data, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("updatename", function(data, cb)
    k9_name = data.name
    cb("ok")
end)

RegisterNUICallback("spawnk9", function(data, cb)
    TriggerEvent("K9:ToggleK9", data.model)
    cb("ok")
end)

RegisterNUICallback("vehicletoggle", function(data, cb)
    if spawned_ped ~= nil then
        TriggerServerEvent("K9:RequestVehicleToggle")
    end
    cb("ok")
end)

RegisterNUICallback("vehiclesearch", function(data, cb)
    if spawned_ped ~= nil then
        TriggerServerEvent("K9:RequestItems")
    end
    cb("ok")
end)

RegisterNUICallback("sit", function(data, cb)
    if spawned_ped ~= nil then
        PlayAnimation(animations['Normal'].itch.dict, animations['Normal'].itch.anim)
    end
    cb("ok")
end)

RegisterNUICallback("laydown", function(data, cb)
    if spawned_ped ~= nil then
        PlayAnimation(animations['Normal'].laydown.dict, animations['Normal'].laydown.anim)
    end
    cb("ok")
end)


-- Main event handlers.

-- Updates language settings.
RegisterNetEvent("K9:UpdateLanguage")
AddEventHandler("K9:UpdateLanguage", function(commands)
    language = commands
end)

-- Opens K9 menu.
RegisterNetEvent("K9:OpenMenu")
AddEventHandler("K9:OpenMenu", function()
    EnableMenu()
end)

    
-- Spawns and deletes K9.
RegisterNetEvent("K9:ToggleK9")
AddEventHandler("K9:ToggleK9", function(model)
    if spawned_ped == nil then
        local ped = GetHashKey(model)
        RequestModel(ped)
        while not HasModelLoaded(ped) do
            Citizen.Wait(1)
            RequestModel(ped)
        end
        local plyCoords = GetOffsetFromEntityInWorldCoords(GetLocalPed(), 0.0, 2.0, 0.0)
        local dog = CreatePed(28, ped, plyCoords.x, plyCoords.y, plyCoords.z, GetEntityHeading(GetLocalPed()), 0, 1)
        spawned_ped = dog
        SetBlockingOfNonTemporaryEvents(spawned_ped, true)
        SetPedFleeAttributes(spawned_ped, 0, 0)
        SetPedRelationshipGroupHash(spawned_ped, GetHashKey("k9"))
        local blip = AddBlipForEntity(spawned_ped)
        SetBlipAsFriendly(blip, true)
        SetBlipSprite(blip, 442)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(tostring("K9: ".. k9_name))
        EndTextCommandSetBlipName(blip)
        NetworkRegisterEntityAsNetworked(spawned_ped)
        GiveWeaponToPed(spawned_ped, GetHashKey("WEAPON_ANIMAL"), 200, true, true);
        PlayAnimation(animations['Normal'].sit.dict, animations['Normal'].sit.anim)
        while not NetworkGetEntityIsNetworked(spawned_ped) do
            NetworkRegisterEntityAsNetworked(spawned_ped)
            Citizen.Wait(1)
        end
    else
        local has_control = false
        RequestNetworkControl(function(cb)
            has_control = cb
        end)
        if has_control then
            SetEntityAsMissionEntity(spawned_ped, true, true)
            DeleteEntity(spawned_ped)
            spawned_ped = nil
            if attacking then
                SetPedRelationshipGroupDefaultHash(target_ped, GetHashKey("CIVMALE"))
                target_ped = nil
                attacking = false
            end
            following = false
            searching = false
        end
    end
end)

-- Toggles K9 to follow / heel.
RegisterNetEvent("K9:ToggleFollow")
AddEventHandler("K9:ToggleFollow", function()
    if spawned_ped ~= nil then
        if not following then
            local has_control = false
            RequestNetworkControl(function(cb)
                has_control = cb
            end)
            if has_control then
                TaskFollowToOffsetOfEntity(spawned_ped, GetLocalPed(), 0.5, 0.0, 0.0, 5.0, -1, 0.0, 1)
                SetPedKeepTask(spawned_ped, true)
                following = true
                attacking = false
                QBCore.Functions.Notify(k9_name .. " " .. language.follow, "primary", 5000)
            end
        else
            local has_control = false
            RequestNetworkControl(function(cb)
                has_control = cb
            end)
            if has_control then
                SetPedKeepTask(spawned_ped, false)
                ClearPedTasks(spawned_ped)
                Citizen.Wait(100)
                following = false
                attacking = false
                PlayAnimation(animations['Normal'].sit.dict, animations['Normal'].sit.anim)
                QBCore.Functions.Notify(k9_name .. " " .. language.stop, "error", 5000)
            end
        end
    end
end)

-- Toggles K9 in and out of vehicles.
RegisterNetEvent("K9:ToggleVehicle")
AddEventHandler("K9:ToggleVehicle", function(isRestricted, vehList)
    if not searching then
        if IsPedInAnyVehicle(spawned_ped, false) then
            SetEntityInvincible(spawned_ped, true)
            SetPedCanRagdoll(spawned_ped, false)
            TaskLeaveVehicle(spawned_ped, GetVehiclePedIsIn(spawned_ped, false), 256)
            QBCore.Functions.Notify(k9_name .. " " .. language.exit, "error", 5000)
            Wait(2000)
            SetPedCanRagdoll(spawned_ped, true)
            SetEntityInvincible(spawned_ped, false)
        else
            if not IsPedInAnyVehicle(GetLocalPed(), false) then
                local plyCoords = GetEntityCoords(GetLocalPed(), false)
                local vehicle = GetVehicleAheadOfPlayer()
                local door = GetClosestVehicleDoor(vehicle)
                if door ~= false then
                    if isRestricted then
                        if CheckVehicleRestriction(vehicle, vehList) then
                            TaskEnterVehicle(spawned_ped, vehicle, -1, door, 2.0, 1, 0)
                            QBCore.Functions.Notify(k9_name .. " " .. language.enter, "success", 5000)
                        end
                    else
                        TaskEnterVehicle(spawned_ped, vehicle, -1, door, 2.0, 1, 0)
                        QBCore.Functions.Notify(k9_name .. " " .. language.enter, "success", 5000)
                    end
                end
            else
                local vehicle = GetVehiclePedIsIn(GetLocalPed(), false)
                local door = 1
                if isRestricted then
                    if CheckVehicleRestriction(vehicle, vehList) then
                        TaskEnterVehicle(spawned_ped, vehicle, -1, door, 2.0, 1, 0)
                        QBCore.Functions.Notify(k9_name .. " " .. language.enter, "success", 5000)
                    end
                else
                    TaskEnterVehicle(spawned_ped, vehicle, -1, door, 2.0, 1, 0)
                    QBCore.Functions.Notify(k9_name .. " " .. language.enter, "success", 5000)
                end
            end
        end
    end
end)

-- Triggers K9 to attack.
RegisterNetEvent("K9:ToggleAttack")
AddEventHandler("K9:ToggleAttack", function(target)
    if not attacking and not searching then
        if IsPedAPlayer(target) then
            local has_control = false
            RequestNetworkControl(function(cb)
                has_control = cb
            end)
            if has_control then
                local player = GetPlayerFromServerId(GetPlayerId(target))
                SetPedRelationshipGroupHash(GetPlayerPed(player), k9TargetHash)
                SetCanAttackFriendly(spawned_ped, true, true)
                TaskPutPedDirectlyIntoMelee(spawned_ped, GetPlayerPed(player), 0.0, -1.0, 0.0, 0)
                attacked_player = player
            end
        else
            local has_control = false
            RequestNetworkControl(function(cb)
                has_control = cb
            end)
            if has_control then
                SetCanAttackFriendly(spawned_ped, true, true)
                TaskPutPedDirectlyIntoMelee(spawned_ped, target, 0.0, -1.0, 0.0, 0)
                attacked_player = 0
            end
        end
        attacking = true
        following = false
        QBCore.Functions.Notify(k9_name .. " " .. language.attack, "error", 5000)
    end
end)

-- Triggers K9 to search vehicle.
RegisterNetEvent("K9:SearchVehicle")
AddEventHandler("K9:SearchVehicle", function(openDoors)
    local vehicle = GetVehicleAheadOfPlayer()
    Citizen.Trace(tostring(vehicle))
    if vehicle ~= 0 and not searching then
        local carplate = GetVehicleNumberPlateText(vehicle)
        if carplate ~= nil then
            searching = true

            QBCore.Functions.Notify(k9_name .. " has began searching...", "primary", 5000) -- [text] = message, [type] = primary | error | success, [length] = time till fadeout.
            
            if openDoors then
                SetVehicleDoorOpen(vehicle, 0, 0, 0)
                SetVehicleDoorOpen(vehicle, 1, 0, 0)
                SetVehicleDoorOpen(vehicle, 2, 0, 0)
                SetVehicleDoorOpen(vehicle, 3, 0, 0)
                SetVehicleDoorOpen(vehicle, 4, 0, 0)
                SetVehicleDoorOpen(vehicle, 5, 0, 0)
                SetVehicleDoorOpen(vehicle, 6, 0, 0)
                SetVehicleDoorOpen(vehicle, 7, 0, 0)
            end

            -- Back right.
            local offsetOne = GetOffsetFromEntityInWorldCoords(vehicle, 2.0, -2.0, 0.0)
            TaskGoToCoordAnyMeans(spawned_ped, offsetOne.x, offsetOne.y, offsetOne.z, 5.0, 0, 0, 1, 10.0)

            Citizen.Wait(7000)

            -- Front right.
            local offsetTwo = GetOffsetFromEntityInWorldCoords(vehicle, 2.0, 2.0, 0.0)
            TaskGoToCoordAnyMeans(spawned_ped, offsetTwo.x, offsetTwo.y, offsetTwo.z, 5.0, 0, 0, 1, 10.0)

            Citizen.Wait(7000)

            -- Front left.
            local offsetThree = GetOffsetFromEntityInWorldCoords(vehicle, -2.0, 2.0, 0.0)
            TaskGoToCoordAnyMeans(spawned_ped, offsetThree.x, offsetThree.y, offsetThree.z, 5.0, 0, 0, 1, 10.0)

            Citizen.Wait(7000)

            -- Front right.
            local offsetFour = GetOffsetFromEntityInWorldCoords(vehicle, -2.0, -2.0, 0.0)
            TaskGoToCoordAnyMeans(spawned_ped, offsetFour.x, offsetFour.y, offsetFour.z, 5.0, 0, 0, 1, 10.0)

            Citizen.Wait(7000)

            if openDoors then
                SetVehicleDoorsShut(vehicle, 0)
            end

            TriggerServerEvent("K9:SearchItems", carplate, k9_name)
            searching = false
        else
            QBCore.Functions.Notify("There is no vehicle nearby", "error", 5000) -- [text] = message, [type] = primary | error | success, [length] = time till fadeout.
        end
    else
        QBCore.Functions.Notify("There is no vehicle nearby", "error", 5000) -- [text] = message, [type] = primary | error | success, [length] = time till fadeout.
    end
end)

--Threads.

-- Initialisation thread.
Citizen.CreateThread(function()
    RegisterKeyBinds()

    -- Setup settings.
    Citizen.Wait(1000)
    local resource = GetCurrentResourceName()
    SendNUIMessage({
        type = "update_resource_name",
        name = resource
    })
    TriggerServerEvent("K9:SendLanguage")
end)

-- Controls menu.
-- Citizen.CreateThread(function()
--     while true do
--         Citizen.Wait(3)

--         -- Trigger opens menu.
--         if IsControlJustPressed(1, 110) then
--             TriggerServerEvent("K9:RequestOpenMenu")
--         end

--         -- Trigger attack.
--         if IsControlJustPressed(1, 111) and IsPlayerFreeAiming(PlayerId()) then
--             local bool, target = GetEntityPlayerIsFreeAimingAt(PlayerId())

--             if bool then
--                 if IsEntityAPed(target) then
--                     TriggerEvent("K9:ToggleAttack", target)
--                 end
--             end
--         end

--         -- Trigger follow.
--         if IsControlJustPressed(1, 108) and not IsPlayerFreeAiming(PlayerId()) then
--             TriggerEvent("K9:ToggleFollow")
--         end

--         if IsControlJustPressed(1, 109) then
--             if spawned_ped ~= nil then
--                 TriggerServerEvent("K9:RequestVehicleToggle")
--             end
--         end
--     end
-- end)

-- Cleanup.
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        -- Deletes K9 when you die.
        if spawned_ped ~= nil and IsEntityDead(GetLocalPed()) then
            TriggerEvent("K9:ToggleK9")
        end

        -- Handles K9 death.
        if spawned_ped ~= nil and IsPedDeadOrDying(spawned_ped, true) then
            spawned_ped = nil
            QBCore.Functions.Notify(k9_name .. " has been killed in action", "error", 5000)
        end
    end
end)

-- Extra functions.

-- Handle customisable keybinds.
function RegisterKeyBinds()
    -- K9 Menu.
    RegisterCommand("open_menu", function()
        TriggerServerEvent("K9:RequestOpenMenu")
    end)
    RegisterKeyMapping("open_menu", "Open K9 menu", "keyboard", Config.KeyDefaults.open_menu)

    -- Attacking.
    RegisterCommand("toggle_attack", function()
        if IsPlayerFreeAiming(PlayerId()) then
            local bool, target = GetEntityPlayerIsFreeAimingAt(PlayerId())

            if bool then
                if IsEntityAPed(target) then
                    TriggerEvent("K9:ToggleAttack", target)
                end
            end
        end
    end)
    RegisterKeyMapping("toggle_attack", "Toggle K9 attack", "keyboard", Config.KeyDefaults.toggle_attack)

    -- Follow/heel.
    RegisterCommand("toggle_follow", function()
        if not IsPlayerFreeAiming(PlayerId()) then
            TriggerEvent("K9:ToggleFollow")
        end
    end)
    RegisterKeyMapping("toggle_follow", "Toggle K9 following", "keyboard", Config.KeyDefaults.toggle_follow)

    -- Get in/out of Vehicle.
    RegisterCommand("toggle_vehicle", function()
        if spawned_ped ~= nil then
            TriggerServerEvent("K9:RequestVehicleToggle")
        end
    end)
    RegisterKeyMapping("toggle_vehicle", "Toggle K9 vehicle entry/exit", "keyboard", Config.KeyDefaults.toggle_vehicle)    
end

-- Gets local ped.
function GetLocalPed()
    return GetPlayerPed(PlayerId())
end

-- Gets control of ped.
function RequestNetworkControl(callback)
    local netId = NetworkGetNetworkIdFromEntity(spawned_ped)
    local timer = 0
    NetworkRequestControlOfNetworkId(netId)
    while not NetworkHasControlOfNetworkId(netId) do
        Citizen.Wait(1)
        NetworkRequestControlOfNetworkId(netId)
        timer = timer + 1
        if timer == 5000 then
            Citizen.Trace("Control failed")
            callback(false)
            break
        end
    end
    callback(true)
end

-- Gets players.
function GetPlayers()
    local players = {}
    for i = 0, 256 do
        if NetworkIsPlayerActive(i) then
            table.insert(players, i)
        end
    end
    return players
end

-- Set K9 animation (sit / laydown).
function PlayAnimation(dict, anim)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Citizen.Wait(0)
    end

    TaskPlayAnim(spawned_ped, dict, anim, 8.0, -8.0, -1, 2, 0.0, 0, 0, 0)
end

-- Gets player ID.
function GetPlayerId(target_ped)
    local players = GetPlayers()
    for a = 1, #players do
        local ped = GetPlayerPed(players[a])
        local server_id = GetPlayerServerId(players[a])
        if target_ped == ped then
            return server_id
        end
    end
    return 0
end

-- Checks vehicle restriction.
function CheckVehicleRestriction(vehicle, VehicleList)
	for i = 1, #VehicleList do
		if GetHashKey(VehicleList[i]) == GetEntityModel(vehicle) then
			return true
		end
	end
	return false
end

-- Gets vehicle ahead of player.
function GetVehicleAheadOfPlayer()
    local lPed = GetLocalPed()
    local lPedCoords = GetEntityCoords(lPed, alive)
    local lPedOffset = GetOffsetFromEntityInWorldCoords(lPed, 0.0, 3.0, 0.0)
    local rayHandle = StartShapeTestCapsule(lPedCoords.x, lPedCoords.y, lPedCoords.z, lPedOffset.x, lPedOffset.y, lPedOffset.z, 1.2, 10, lPed, 7)
    local returnValue, hit, endcoords, surface, vehicle = GetShapeTestResult(rayHandle)

    if hit then
        return vehicle
    else
        return false
    end
end

-- Gets closest door To player.
function GetClosestVehicleDoor(vehicle)
    local plyCoords = GetEntityCoords(GetLocalPed(), false)
	local backleft = GetWorldPositionOfEntityBone(vehicle, GetEntityBoneIndexByName(vehicle, "door_dside_r"))
	local backright = GetWorldPositionOfEntityBone(vehicle, GetEntityBoneIndexByName(vehicle, "door_pside_r"))
	local bldistance = GetDistanceBetweenCoords(backleft['x'], backleft['y'], backleft['z'], plyCoords.x, plyCoords.y, plyCoords.z, 1)
    local brdistance = GetDistanceBetweenCoords(backright['x'], backright['y'], backright['z'], plyCoords.x, plyCoords.y, plyCoords.z, 1)

    local found_door = false

    if (bldistance < brdistance) then
        found_door = 1
    elseif(brdistance < bldistance) then
        found_door = 2
    end

    return found_door
end
