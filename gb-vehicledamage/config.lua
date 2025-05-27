Config = {}

Config.CollisionForceThreshold = 20.0
Config.MphMax                 = 105               -- Currently Set To 105MPH for "total vehicle damage"
Config.MaxBoneDistance        = 1.5
Config.DoorBreakChance        = 50
Config.WindowBreakChance      = 70

Config.Init = function()
    QBCore = exports['qb-core']:GetCoreObject()
end
