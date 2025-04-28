-- client/main.lua
local QBCore = exports['qb-core']:GetCoreObject()
local isMenuOpen = false

-- Open petition menu for players
function OpenPetitionMenu()
    if isMenuOpen then return end
    isMenuOpen = true
    
    -- Get player's existing petitions
    QBCore.Functions.TriggerCallback('qb-petition:server:getMyPetitions', function(myPetitions)
        -- Open NUI
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "openPetitionMenu",
            petitions = myPetitions,
            categories = Config.Categories,
            maxTitle = Config.MaxTitleLength,
            maxDesc = Config.MaxDescLength
        })
    end)
end

-- Open admin petition panel
function OpenAdminPanel()
    if isMenuOpen then return end
    isMenuOpen = true
    
    -- Get all petitions
    QBCore.Functions.TriggerCallback('qb-petition:server:getAllPetitions', function(allPetitions)
        -- Open NUI
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "openAdminPanel",
            petitions = allPetitions
        })
    end)
end

-- NUI Callbacks
RegisterNUICallback('closePetitionUI', function(_, cb)
    SetNuiFocus(false, false)
    isMenuOpen = false
    cb('ok')
end)

RegisterNUICallback('submitPetition', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-petition:server:createPetition', function(success, message)
        cb({success = success, message = message})
    end, data)
end)

RegisterNUICallback('updatePetition', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-petition:server:updatePetition', function(success, message)
        cb({success = success, message = message})
    end, data.petitionId, data.status, data.comment)
end)

RegisterNUICallback('refreshPetitions', function(data, cb)
    if data.isAdmin then
        QBCore.Functions.TriggerCallback('qb-petition:server:getAllPetitions', function(allPetitions)
            cb({petitions = allPetitions})
        end)
    else
        QBCore.Functions.TriggerCallback('qb-petition:server:getMyPetitions', function(myPetitions)
            cb({petitions = myPetitions})
        end)
    end
end)

-- Commands
RegisterNetEvent('qb-petition:client:openPetitionMenu', function()
    OpenPetitionMenu()
end)

RegisterNetEvent('qb-petition:client:openAdminPanel', function()
    OpenAdminPanel()
end)