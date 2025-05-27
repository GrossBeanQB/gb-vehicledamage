local QBCore=exports['qb-core']:GetCoreObject()

RegisterNetEvent("vehicledamage:server:detachWheel",function(netId,w)
    TriggerClientEvent("vehicledamage:client:detachWheelSync",-1,netId,w)
end)

RegisterNetEvent("vehicledamage:server:detachDoor",function(netId,door,x,y,z)
    TriggerClientEvent("vehicledamage:client:detachDoorSync",-1,netId,door,x,y,z)
end)
