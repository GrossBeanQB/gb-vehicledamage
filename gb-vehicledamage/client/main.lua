Config.Init()

local removedWheels = {}
local MS_TO_MPH = 2.23693629

local WHEEL_BONES = {
    { bone = "wheel_lf", idx = 0 },
    { bone = "wheel_rf", idx = 1 },
    { bone = "wheel_lr", idx = 2 },
    { bone = "wheel_rr", idx = 3 },
}

local DOOR_BONES = {
    [0] = "door_dside_f",
    [1] = "door_pside_f",
    [2] = "door_dside_r",
    [3] = "door_pside_r",
}

local BONNET_BONE = "bonnet"
local TRUNK_BONE  = "boot"

local DOOR_PROPS = {
    [0] = "prop_car_door_01",
    [1] = "prop_car_door_02",
    [2] = "prop_car_door_03",
    [3] = "prop_car_door_04",
}

function math.clamp(v,a,b) return math.max(a, math.min(v,b)) end

local function calcChance(force, speed, health)
    local base = (force - Config.CollisionForceThreshold) / 50 * (speed / Config.MphMax)
    local mult = 1 + ((1000 - health) / 2000)
    return math.clamp(base * mult * 100, 0, 50)
end

local function getBonePos(vehicle, name)
    local idx = GetEntityBoneIndexByName(vehicle, name)
    if idx == -1 then return end
    local pos = GetWorldPositionOfEntityBone(vehicle, idx)
    return pos, idx
end

local function detachWheel(vehicle, wheelIdx)
    if not DoesEntityExist(vehicle) then return end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if netId == 0 then return end
    removedWheels[netId] = removedWheels[netId] or {}
    if removedWheels[netId][wheelIdx] then return end
    removedWheels[netId][wheelIdx] = true
    if not NetworkGetEntityIsNetworked(vehicle) then
        NetworkRegisterEntityAsNetworked(vehicle)
    end
    TriggerServerEvent("vehicledamage:server:detachWheel", netId, wheelIdx)
    BreakOffVehicleWheel(vehicle, wheelIdx, true, false, true, false)
end

local function detachEntity(vehicle, boneName, propMap)
    if not DoesEntityExist(vehicle) then return end
    local pos, boneIdx = getBonePos(vehicle, boneName)
    if not pos or boneIdx < 0 then return end
    SetVehicleDoorBroken(vehicle, boneIdx, true)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if netId == 0 then return end
    local propName = propMap[boneIdx] or propMap[boneName]
    if propName then
        local model = GetHashKey(propName)
        RequestModel(model)
        local deadline = GetGameTimer() + 1000
        while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
        local obj = CreateObject(model, pos.x, pos.y, pos.z, true, true, true)
        local vel = GetEntityVelocity(vehicle)
        ApplyForceToEntity(obj, 1, true, vel.x * 1.5, vel.y * 1.5, vel.z * 1.5, 0,0,0, true, true, true, true, true)
        SetModelAsNoLongerNeeded(model)
    end
end

local function openAllDoors(vehicle)
    for i = 0, 5 do
        if DoesVehicleHaveDoor(vehicle, i) then
            SetVehicleDoorOpen(vehicle, i, false, false)
        end
    end
end

CreateThread(function()
    local lastCollision = 0
    local prevVel = vector3(0, 0, 0)
    local offsets = {
        vector3(0.0, 2.0, 0.0),
        vector3(0.0, -2.0, 0.0),
    }
    while true do
        Wait(1)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and DoesEntityExist(veh) then
            local vel = GetEntityVelocity(veh)
            if HasEntityCollidedWithAnything(veh) and GetGameTimer() - lastCollision > 200 then
                lastCollision = GetGameTimer()
                local mass  = GetVehicleHandlingFloat(veh, "CHandlingData", "fMass") or 1500.0
                local force = #(vel - prevVel) * mass
                local speed = GetEntitySpeed(veh) * MS_TO_MPH
                if speed >= Config.MphMax and force >= Config.CollisionForceThreshold then
                    openAllDoors(veh)
                    for _, off in ipairs(offsets) do
                        local impact = GetOffsetFromEntityInWorldCoords(veh, off.x, off.y, off.z)
                        for _, wb in ipairs(WHEEL_BONES) do
                            local bonePos, _ = getBonePos(veh, wb.bone)
                            if bonePos and #(impact - bonePos) <= Config.MaxBoneDistance then
                                local health = GetVehicleBodyHealth(veh)
                                if math.random(100) <= calcChance(force, speed, health) then
                                    detachWheel(veh, wb.idx)
                                end
                                if math.random(100) <= Config.DoorBreakChance then
                                    detachEntity(veh, DOOR_BONES[wb.idx], DOOR_PROPS)
                                end
                                if wb.idx <= 1 and math.random(100) <= Config.DoorBreakChance then
                                    detachEntity(veh, BONNET_BONE, { [BONNET_BONE] = "prop_car_hood" })
                                end
                                if wb.idx >= 2 and math.random(100) <= Config.DoorBreakChance then
                                    detachEntity(veh, TRUNK_BONE, { [TRUNK_BONE] = "prop_boot" })
                                end
                                break
                            end
                        end
                    end
                end
            end
            prevVel = vel
        else
            prevVel = vector3(0, 0, 0)
        end
    end
end)

RegisterNetEvent("vehicledamage:client:detachWheelSync", function(netId, idx)
    local v = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(v) then
        BreakOffVehicleWheel(v, idx, true, false, true, false)
    end
end)

RegisterNetEvent("vehicledamage:client:detachDoorSync", function(netId, boneIdx, x, y, z)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(veh) then return end
    local propName = DOOR_PROPS[boneIdx]
    if not propName then return end
    local model = GetHashKey(propName)
    RequestModel(model)
    local deadline = GetGameTimer() + 1000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
    local obj = CreateObject(model, x, y, z, true, true, true)
    local vel = GetEntityVelocity(veh)
    ApplyForceToEntity(obj, 1, true, vel.x * 1.5, vel.y * 1.5, vel.z * 1.5, 0,0,0, true, true, true, true, true)
    SetModelAsNoLongerNeeded(model)
end)
