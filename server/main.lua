local QBCore = exports['qb-core']:GetCoreObject()
local Petitions = {}

-- Initialize/load petitions from database on resource start
CreateThread(function()
    -- Ensure the database table exists
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `petitions` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `title` VARCHAR(100) NOT NULL,
            `content` TEXT NOT NULL,
            `author_id` VARCHAR(50) NOT NULL,
            `author_name` VARCHAR(100) NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `status` ENUM('pending', 'approved', 'rejected') DEFAULT 'pending',
            `admin_comment` TEXT,
            `expires_at` TIMESTAMP NULL,
            `signatures` JSON NOT NULL
        )
    ]], {})
    
    -- Load existing petitions from database
    MySQL.Async.fetchAll('SELECT * FROM petitions', {}, function(results)
        if results and #results > 0 then
            for _, petition in ipairs(results) do
                -- Parse signatures from JSON
                petition.signatures = json.decode(petition.signatures) or {}
                Petitions[petition.id] = petition
            end
            print('Loaded ' .. #results .. ' petitions from database')
        else
            print('No petitions found in database')
        end
    end)
end)

-- Create a new petition
RegisterNetEvent('qb-petition:server:createPetition')
AddEventHandler('qb-petition:server:createPetition', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check cooldown
    local citizenId = Player.PlayerData.citizenid
    local hasCooldown = checkPetitionCooldown(citizenId)
    
    if hasCooldown then
        TriggerClientEvent('qb-petition:client:showNotification', src, Config.Notifications.cooldownActive)
        return
    end
    
    -- Create expiry date
    local expiryDate = os.time() + (Config.PetitionSettings.expiryDays * 24 * 60 * 60)
    local expiryFormatted = os.date("%Y-%m-%d %H:%M:%S", expiryDate)
    
    -- Insert petition into database
    MySQL.Async.insert('INSERT INTO petitions (title, content, author_id, author_name, expires_at, signatures) VALUES (?, ?, ?, ?, ?, ?)',
    {
        data.title,
        data.content,
        citizenId,
        Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        expiryFormatted,
        json.encode({}) -- Empty signatures array
    }, function(id)
        if id > 0 then
            -- Add to memory cache
            Petitions[id] = {
                id = id,
                title = data.title,
                content = data.content,
                author_id = citizenId,
                author_name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                created_at = os.date("%Y-%m-%d %H:%M:%S"),
                status = 'pending',
                expires_at = expiryFormatted,
                signatures = {}
            }
            
            TriggerClientEvent('qb-petition:client:showNotification', src, Config.Notifications.petitionCreated)
            
            -- Notify admins if enabled
            if Config.AdminSettings.notifyNewPetition then
                notifyAdmins('New petition created: ' .. data.title)
            end
        else
            TriggerClientEvent('qb-petition:client:showNotification', src, "Error creating petition.")
        end
    end)
end)

-- Sign a petition
RegisterNetEvent('qb-petition:server:signPetition')
AddEventHandler('qb-petition:server:signPetition', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local petitionId = data.petitionId
    local citizenId = Player.PlayerData.citizenid
    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    -- Check if petition exists
    if not Petitions[petitionId] then
        TriggerClientEvent('qb-petition:client:showNotification', src, "This petition doesn't exist.")
        return
    end
    
    -- Check if already signed
    for _, signature in ipairs(Petitions[petitionId].signatures) do
        if signature.citizenId == citizenId then
            TriggerClientEvent('qb-petition:client:showNotification', src, Config.Notifications.alreadySigned)
            return
        end
    end
    
    -- Add signature
    table.insert(Petitions[petitionId].signatures, {
        citizenId = citizenId,
        name = playerName,
        date = os.date("%Y-%m-%d %H:%M:%S")
    })
    
    -- Update database
    MySQL.Async.execute('UPDATE petitions SET signatures = ? WHERE id = ?',
    {
        json.encode(Petitions[petitionId].signatures),
        petitionId
    })
    
    TriggerClientEvent('qb-petition:client:showNotification', src, Config.Notifications.petitionSigned)
    
    -- Check if reached required signatures
    if #Petitions[petitionId].signatures >= Config.PetitionSettings.requiredSignatures and Petitions[petitionId].status == 'pending' then
        notifyAdmins(Config.Notifications.adminReviewNeeded)
    end
end)

-- Admin actions (approve/reject)
RegisterNetEvent('qb-petition:server:adminAction')
AddEventHandler('qb-petition:server:adminAction', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check admin permission
    if not hasAdminPermission(Player) then
        TriggerClientEvent('qb-petition:client:showNotification', src, "You don't have permission for this action.")
        return
    end
    
    local petitionId = data.petitionId
    local action = data.action -- 'approve' or 'reject'
    local comment = data.comment or ""
    
    -- Check if petition exists
    if not Petitions[petitionId] then
        TriggerClientEvent('qb-petition:client:showNotification', src, "This petition doesn't exist.")
        return
    end
    
    -- Update petition status
    Petitions[petitionId].status = action
    Petitions[petitionId].admin_comment = comment
    
    -- Update database
    MySQL.Async.execute('UPDATE petitions SET status = ?, admin_comment = ? WHERE id = ?',
    {
        action,
        comment,
        petitionId
    })
    
    -- Notify the author if they're online
    local author = QBCore.Functions.GetPlayerByCitizenId(Petitions[petitionId].author_id)
    if author then
        if action == 'approve' then
            TriggerClientEvent('qb-petition:client:showNotification', author.PlayerData.source, Config.Notifications.petitionApproved)
        else
            TriggerClientEvent('qb-petition:client:showNotification', author.PlayerData.source, Config.Notifications.petitionRejected)
        end
    end
    
    TriggerClientEvent('qb-petition:client:showNotification', src, "Petition has been " .. action .. "d.")
end)

-- Get petition data for UI
QBCore.Functions.CreateCallback('qb-petition:server:getPetitionData', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player then 
        cb({petitions = {}, isAdmin = false})
        return
    end
    
    local isAdmin = hasAdminPermission(Player)
    local citizenId = Player.PlayerData.citizenid
    
    -- Check for expired petitions
    if Config.AdminSettings.autoDeclineExpired then
        processExpiredPetitions()
    end
    
    -- Convert to array and filter as needed
    local petitionsArray = {}
    for _, petition in pairs(Petitions) do
        -- Admin sees all, regular players only see pending or approved
        if isAdmin or petition.status ~= 'rejected' or petition.author_id == citizenId then
            table.insert(petitionsArray, petition)
        end
    end
    
    -- Sort by creation date (newest first)
    table.sort(petitionsArray, function(a, b)
        return a.created_at > b.created_at
    end)
    
    cb({petitions = petitionsArray, isAdmin = isAdmin})
end)

-- Helper functions
function hasAdminPermission(Player)
    if not Player then return false end
    
    local permission = Config.AdminSettings.requiredPermission
    
    -- Check for admin or god level in QBCore
    if Player.PlayerData.admin == 'admin' or Player.PlayerData.admin == 'god' then
        return true
    end
    
    -- Check job (for police chief, mayor etc.)
    if permission == 'police' and Player.PlayerData.job.name == 'police' and Player.PlayerData.job.grade.level >= 4 then
        return true
    end
    
    if permission == 'mayor' and Player.PlayerData.job.name == 'mayor' then
        return true
    end
    
    return false
end

function checkPetitionCooldown(citizenId)
    local cooldownTime = Config.PetitionSettings.cooldownMinutes * 60
    
    -- Check if player has any recent petitions
    for _, petition in pairs(Petitions) do
        if petition.author_id == citizenId then
            local createdTime = os.time(os.date("!*t", petition.created_at))
            local currentTime = os.time()
            
            if (currentTime - createdTime) < cooldownTime then
                return true -- Still in cooldown
            end
        end
    end
    
    return false -- No cooldown
end

function processExpiredPetitions()
    local currentTime = os.time()
    
    for id, petition in pairs(Petitions) do
        if petition.status == 'pending' then
            local expiryTime = os.time(os.date("!*t", petition.expires_at))
            
            if currentTime > expiryTime then
                -- Update status to rejected with auto-message
                petition.status = 'rejected'
                petition.admin_comment = 'Automatically rejected due to expiration.'
                
                -- Update database
                MySQL.Async.execute('UPDATE petitions SET status = ?, admin_comment = ? WHERE id = ?',
                {
                    'rejected',
                    'Automatically rejected due to expiration.',
                    id
                })
            end
        end
    end
end

function notifyAdmins(message)
    local players = QBCore.Functions.GetPlayers()
    
    for _, playerId in ipairs(players) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player and hasAdminPermission(Player) then
            TriggerClientEvent('qb-petition:client:showNotification', playerId, message)
        end
    end
end