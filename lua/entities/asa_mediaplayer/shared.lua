ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Media Player"
ENT.Author = "archi"
ENT.Category = "ASA"

ENT.Spawnable = true
ENT.AdminSpawnable = false
ENT.DoNotDuplicate = true
ENT.Editable = true

ENT.RayLength = 1000
ENT.ScreenWidth = 1024
ENT.ScreenHeight = 512
ENT.HTMLWidth = 1280
ENT.HTMLHeight = 720
ENT.NetworkString = "ASA.Mediaplayer"

ASA_MEDIAPLAYER_NET_REQUEST_SEEK = 1
ASA_MEDIAPLAYER_NET_REQUEST_ADD = 2
ASA_MEDIAPLAYER_NET_REQUEST_SKIP = 3
ASA_MEDIAPLAYER_NET_REQUEST_JOIN = 4
ASA_MEDIAPLAYER_NET_REQUEST_LEAVE = 5

ASA_MEDIAPLAYER_NET_SEND_PLAYLIST = 1
ASA_MEDIAPLAYER_NET_SEND_SEEK = 2
ASA_MEDIAPLAYER_NET_SEND_PLAY = 3
ASA_MEDIAPLAYER_NET_SEND_STOP = 4

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Multiplier", {
        KeyName = "multiplier",
        Edit = 
        {
            title = "Distance multiplier",
            type = "Float",
            order = 1, 
            min = 0.25, 
            max = 10
        }
    })

    self:SetMultiplier(0.25)
end