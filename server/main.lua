-- server/main.lua
local QBCore = exports['qb-core']:GetCoreObject()

-- Helper function to check if player is admin
function IsPlayerAdmin(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    -- Get player's permission level directly from QBCore
    local playerGroup = QBCore.Functions.GetPermission(source)
    
    -- First check for exact matches in the admin groups
    for _, adminGroup in pairs(Config.AdminGroups) do
        if playerGroup == adminGroup then
            return true
        end
    end
    
    -- Check for admin status via QBCore's isAdmin function (if available)
    if QBCore.Functions.HasPermission(source, 'admin') then
        return true
    end
    
    -- Additional check for god permission
    if QBCore.Functions.HasPermission(source, 'god') then
        return true
    end
    
    return false
end

-- Initialize Database
Citizen.CreateThread(function()
    Wait(500)
    -- Create tables if they don't exist
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS petitions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            title VARCHAR(100) NOT NULL,
            content TEXT NOT NULL,
            category VARCHAR(50) NOT NULL,
            author_citizenid VARCHAR(50) NOT NULL,
            author_name VARCHAR(100) NOT NULL,
            is_anonymous BOOLEAN DEFAULT FALSE,
            status ENUM('pending', 'approved', 'rejected', 'completed', 'expired') DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            expires_at TIMESTAMP,
            signature_count INT DEFAULT 0
        )
    ]])
    
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS petition_signatures (
            id INT AUTO_INCREMENT PRIMARY KEY,
            petition_id INT NOT NULL,
            signer_citizenid VARCHAR(50) NOT NULL,
            signer_name VARCHAR(100) NOT NULL,
            signed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(petition_id, signer_citizenid),
            FOREIGN KEY (petition_id) REFERENCES petitions(id) ON DELETE CASCADE
        )
    ]])
    
    -- Schedule a job to check for expired petitions
    CheckExpiredPetitions()
end)

-- Helper function to check if player is admin
QBCore.Functions.CreateCallback('ss-petitions:server:CheckIsAdmin', function(source, cb)
    local isAdmin = IsPlayerAdmin(source)
    print("Player " .. source .. " admin check: " .. tostring(isAdmin))
    cb(isAdmin)
end)

-- Check for expired petitions every hour
function CheckExpiredPetitions()
    local success, result = pcall(function()
        MySQL.update('UPDATE petitions SET status = "expired" WHERE status IN ("pending", "approved") AND expires_at < NOW()')
    end)
    
    if not success then
        print("Error checking expired petitions: " .. tostring(result))
    end
    
    -- Schedule next check
    SetTimeout(3600000, CheckExpiredPetitions) -- 1 hour
end

-- Get all petitions (filtered by player permissions)
QBCore.Functions.CreateCallback('ss-petitions:server:GetPetitions', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end
    
    local citizenid = Player.PlayerData.citizenid
    local isAdmin = IsPlayerAdmin(source)
    
    if isAdmin then
        -- Admins see all petitions
        MySQL.query('SELECT * FROM petitions ORDER BY created_at DESC', function(results)
            cb(results or {})
        end)
    else
        -- Regular players see only approved petitions and their own
        MySQL.query('SELECT * FROM petitions WHERE status = "approved" OR author_citizenid = ? ORDER BY created_at DESC', {citizenid}, function(results)
            cb(results or {})
        end)
    end
end)

-- Get petitions created by current player
QBCore.Functions.CreateCallback('ss-petitions:server:GetPlayerPetitions', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end
    
    local citizenid = Player.PlayerData.citizenid
    
    MySQL.query('SELECT * FROM petitions WHERE author_citizenid = ? ORDER BY created_at DESC', {citizenid}, function(results)
        cb(results or {})
    end)
end)

-- Get detailed information about a specific petition
QBCore.Functions.CreateCallback('ss-petitions:server:GetPetitionDetails', function(source, cb, petitionId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end
    
    local citizenid = Player.PlayerData.citizenid
    local isAdmin = IsPlayerAdmin(source)
    
    MySQL.query('SELECT * FROM petitions WHERE id = ?', {petitionId}, function(results)
        if not results or #results == 0 then
            return cb(nil)
        end
        
        local petition = results[1]
        
        -- Check if player has permission to view petition
        if petition.status ~= "approved" and petition.author_citizenid ~= citizenid and not isAdmin then
            return cb(nil)
        end
        
        -- Get signatures
        MySQL.query('SELECT * FROM petition_signatures WHERE petition_id = ?', {petitionId}, function(signatures)
            petition.signatures = signatures or {}
            petition.hasPlayerSigned = false
            
            for _, signature in pairs(petition.signatures) do
                if signature.signer_citizenid == citizenid then
                    petition.hasPlayerSigned = true
                    break
                end
            end
            
            cb(petition)
        end)
    end)
end)

-- Create new petition
QBCore.Functions.CreateCallback('ss-petitions:server:CreatePetition', function(source, cb, petitionData)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false, "Player not found") end
    
    local citizenid = Player.PlayerData.citizenid
    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    -- Check cooldown
    MySQL.query('SELECT created_at FROM petitions WHERE author_citizenid = ? ORDER BY created_at DESC LIMIT 1', {citizenid}, function(lastPetition)
        if lastPetition and #lastPetition > 0 then
            local lastCreatedTime = lastPetition[1].created_at
            local currentTime = os.time()
            local lastCreatedTimestamp = os.time({
                year = tonumber(string.sub(lastCreatedTime, 1, 4)),
                month = tonumber(string.sub(lastCreatedTime, 6, 7)),
                day = tonumber(string.sub(lastCreatedTime, 9, 10)),
                hour = tonumber(string.sub(lastCreatedTime, 12, 13)),
                min = tonumber(string.sub(lastCreatedTime, 15, 16)),
                sec = tonumber(string.sub(lastCreatedTime, 18, 19))
            })
            
            local timeDiff = currentTime - lastCreatedTimestamp
            if timeDiff < (Config.CooldownMinutes * 60) then
                local timeLeft = math.ceil((Config.CooldownMinutes * 60 - timeDiff) / 60)
                return cb(false, "You need to wait " .. timeLeft .. " more minutes before creating another petition")
            end
        end
        
        -- Check if player has reached max petitions
        MySQL.query('SELECT COUNT(*) as count FROM petitions WHERE author_citizenid = ? AND status IN ("pending", "approved")', {citizenid}, function(results)
            if results[1].count >= Config.MaxPlayerPetitions then
                return cb(false, "You have reached the maximum number of active petitions (" .. Config.MaxPlayerPetitions .. ")")
            end
            
            -- Check if system has reached max petitions
            MySQL.query('SELECT COUNT(*) as count FROM petitions WHERE status IN ("pending", "approved")', function(results)
                if results[1].count >= Config.MaxActivePetitions then
                    return cb(false, "The petition system has reached its capacity. Try again later")
                end
                
                -- Validate data
                if not petitionData.title or petitionData.title:len() < 5 or petitionData.title:len() > 100 then
                    return cb(false, "Title must be between 5 and 100 characters")
                end
                
                if not petitionData.content or petitionData.content:len() < 10 or petitionData.content:len() > Config.MaxPetitionLength then
                    return cb(false, "Content must be between 10 and " .. Config.MaxPetitionLength .. " characters")
                end
                
                if not petitionData.category or not table.contains(Config.Categories, petitionData.category) then
                    return cb(false, "Invalid category")
                end
                
                -- Calculate expiry date
                local expiryDate = os.date("%Y-%m-%d %H:%M:%S", os.time() + (Config.PetitionExpiryDays * 86400))
                
                -- Determine initial status
                local initialStatus = "pending"
                if not Config.RequireApproval then
                    initialStatus = "approved"
                end
                
                -- Set anonymous flag
                local isAnonymous = petitionData.isAnonymous and Config.AllowAnonymousPetitions
                
                -- Insert petition
                MySQL.insert('INSERT INTO petitions (title, content, category, author_citizenid, author_name, is_anonymous, status, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                    {petitionData.title, petitionData.content, petitionData.category, citizenid, playerName, isAnonymous, initialStatus, expiryDate},
                    function(id)
                        if id > 0 then
                            -- Notify admins if approval is required
                            if Config.RequireApproval then
                                NotifyAdmins("New petition #" .. id .. " requires approval")
                            end
                            
                            return cb(true, "Petition created successfully" .. (Config.RequireApproval and ". It requires admin approval before becoming public" or ""))
                        else
                            return cb(false, "Failed to create petition")
                        end
                    end)
            end)
        end)
    end)
end)

-- Sign a petition
QBCore.Functions.CreateCallback('ss-petitions:server:SignPetition', function(source, cb, petitionId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false, "Player not found") end
    
    local citizenid = Player.PlayerData.citizenid
    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    -- Check if petition exists and is approved
    MySQL.query('SELECT * FROM petitions WHERE id = ? AND status = "approved"', {petitionId}, function(results)
        if not results or #results == 0 then
            return cb(false, "Petition not found or not approved")
        end
        
        -- Check if player has already signed
        MySQL.query('SELECT id FROM petition_signatures WHERE petition_id = ? AND signer_citizenid = ?', {petitionId, citizenid}, function(signatures)
            if signatures and #signatures > 0 then
                return cb(false, "You have already signed this petition")
            end
            
            -- Add signature
            MySQL.insert('INSERT INTO petition_signatures (petition_id, signer_citizenid, signer_name) VALUES (?, ?, ?)', 
                {petitionId, citizenid, playerName}, 
                function(id)
                    if id > 0 then
                        -- Update signature count
                        MySQL.query('UPDATE petitions SET signature_count = signature_count + 1 WHERE id = ?', {petitionId})
                        
                        -- Check if reached required signatures
                        MySQL.query('SELECT signature_count FROM petitions WHERE id = ?', {petitionId}, function(petition)
                            if petition[1].signature_count >= Config.RequiredSignatures then
                                MySQL.update('UPDATE petitions SET status = "completed" WHERE id = ?', {petitionId})
                                TriggerClientEvent('ss-petitions:client:Notify', -1, "A petition has reached the required signatures!", "success")
                            end
                        end)
                        
                        return cb(true, "You signed the petition")
                    else
                        return cb(false, "Failed to sign petition")
                    end
                end)
        end)
    end)
end)

-- Delete a petition (owner or admin only)
QBCore.Functions.CreateCallback('ss-petitions:server:DeletePetition', function(source, cb, petitionId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false, "Player not found") end
    
    local citizenid = Player.PlayerData.citizenid
    local isAdmin = IsPlayerAdmin(source)
    
    -- Check if petition exists and player has rights to delete
    MySQL.query('SELECT author_citizenid FROM petitions WHERE id = ?', {petitionId}, function(results)
        if not results or #results == 0 then
            return cb(false, "Petition not found")
        end
        
        if results[1].author_citizenid ~= citizenid and not isAdmin then
            return cb(false, "You don't have permission to delete this petition")
        end
        
        -- Delete petition
        MySQL.query('DELETE FROM petitions WHERE id = ?', {petitionId}, function(affectedRows)
            if affectedRows > 0 then
                return cb(true, "Petition deleted successfully")
            else
                return cb(false, "Failed to delete petition")
            end
        end)
    end)
end)

-- Approve petition (admin only)
QBCore.Functions.CreateCallback('ss-petitions:server:ApprovePetition', function(source, cb, petitionId)
    if not IsPlayerAdmin(source) then
        return cb(false, "You don't have permission to approve petitions")
    end
    
    MySQL.query('UPDATE petitions SET status = "approved" WHERE id = ?', {petitionId}, function(affectedRows)
        if affectedRows > 0 then
            -- Notify petition creator
            MySQL.query('SELECT author_citizenid FROM petitions WHERE id = ?', {petitionId}, function(result)
                if result and #result > 0 then
                    local authorCitizenId = result[1].author_citizenid
                    local authorSource = QBCore.Functions.GetPlayerByCitizenId(authorCitizenId)
                    if authorSource then
                        TriggerClientEvent('ss-petitions:client:Notify', authorSource.PlayerData.source, "Your petition has been approved", "success")
                    end
                end
            end)
            
            return cb(true, "Petition approved successfully")
        else
            return cb(false, "Failed to approve petition")
        end
    end)
end)

-- Reject petition (admin only)
QBCore.Functions.CreateCallback('ss-petitions:server:RejectPetition', function(source, cb, petitionId)
    if not IsPlayerAdmin(source) then
        return cb(false, "You don't have permission to reject petitions")
    end
    
    MySQL.query('UPDATE petitions SET status = "rejected" WHERE id = ?', {petitionId}, function(affectedRows)
        if affectedRows > 0 then
            -- Notify petition creator
            MySQL.query('SELECT author_citizenid FROM petitions WHERE id = ?', {petitionId}, function(result)
                if result and #result > 0 then
                    local authorCitizenId = result[1].author_citizenid
                    local authorSource = QBCore.Functions.GetPlayerByCitizenId(authorCitizenId)
                    if authorSource then
                        TriggerClientEvent('ss-petitions:client:Notify', authorSource.PlayerData.source, "Your petition has been rejected", "error")
                    end
                end
            end)
            
            return cb(true, "Petition rejected successfully")
        else
            return cb(false, "Failed to reject petition")
        end
    end)
end)

-- Notify all admins
function NotifyAdmins(message)
    local Players = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(Players) do
        if IsPlayerAdmin(playerId) then
            TriggerClientEvent('ss-petitions:client:Notify', playerId, message, "info")
        end
    end
end

-- Helper function to check if value exists in table
function table.contains(table, value)
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end