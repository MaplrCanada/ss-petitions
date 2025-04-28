-- config.lua
Config = {}

-- General Settings
Config.Debug = false -- Set to true for debug mode
Config.NotificationSystem = 'qb' -- Options: 'qb', 'okok', 'custom'

-- Command Settings
Config.UseCommand = true -- If true, enables /petition command
Config.CommandName = 'petition' -- Command to open petition UI

-- Location Settings (used if Config.UseCommand = false)
Config.Locations = {
    {
        coords = vector3(-548.35, -200.12, 38.22), -- City Hall example
        radius = 2.0, -- Interaction radius
        marker = {
            enabled = true,
            type = 2, -- Marker type
            size = vec(0.5, 0.5, 0.5),
            color = {r = 0, g = 122, b = 204, a = 100},
        },
        blip = {
            enabled = true,
            sprite = 408, -- Blip sprite
            color = 3, -- Blip color
            scale = 0.7, -- Blip size
            label = "Petition Board" -- Blip label
        }
    },
    -- Add more locations as needed
}

-- UI Settings
Config.UI = {
    theme = {
        primary = "#3498db", -- Primary color
        secondary = "#2ecc71", -- Secondary color
        accent = "#9b59b6", -- Accent color
        background = "#2c3e50", -- Background color
        text = "#ecf0f1" -- Text color
    },
    logo = "nui/assets/img/logo.png", -- Path to logo
}

-- Petition Settings
Config.PetitionSettings = {
    maxPetitionLength = 500, -- Maximum characters in petition text
    expiryDays = 14, -- Days until a petition expires if not handled
    requiredSignatures = 25, -- Signatures needed for admin review
    cooldownMinutes = 60, -- Minutes before player can create another petition
}

-- Admin Settings
Config.AdminSettings = {
    requiredPermission = 'admin', -- Permission needed to access admin panel
    notifyNewPetition = true, -- Notify admins when new petitions are created
    autoDeclineExpired = true, -- Auto-decline expired petitions
}

-- Notification texts
Config.Notifications = {
    petitionCreated = "Your petition has been submitted.",
    petitionSigned = "You have signed the petition.",
    alreadySigned = "You have already signed this petition.",
    petitionApproved = "Your petition has been approved by an admin.",
    petitionRejected = "Your petition has been rejected by an admin.",
    cooldownActive = "You must wait before creating another petition.",
    adminReviewNeeded = "A petition has reached the required signatures for review.",
}