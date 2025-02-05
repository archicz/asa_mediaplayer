AddCSLuaFile("cl_init.lua")
AddCSLuaFile("cl_ui.lua")
AddCSLuaFile("cl_htmlplayer.lua")
AddCSLuaFile("cl_videopicker.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

util.AddNetworkString(ENT.NetworkString)

local apiURL = CreateConVar("sv_asa_mediaplayer_api", "http://partyzan-technology.xyz/yt-dlp/?videoId=%s", FCVAR_ARCHIVE, "YT-DLP API URL to use")
local maxChars = 48
local mediaPlayersQueue = {}

function ENT:CreatePool()
    self.Pool = {}
    self.Pool.Players = EntityList()
    self.Pool.Playlist = {}
    self.Pool.Playing = false
    self.Pool.Duration = 0
    self.Pool.EndTime = 0
end

function ENT:SendPlaylist(target)
    if not target then
        target = self.Pool.Players
    end

    local playlist = self.Pool.Playlist
    local numEntries = #playlist
    
    net.Start(self.NetworkString)
    net.WriteUInt(ASA_MEDIAPLAYER_NET_SEND_PLAYLIST, 4)
    net.WriteEntity(self)

    net.WriteUInt(numEntries, 8)

    for i = 1, numEntries do
        local entry = playlist[i]

        net.WriteString(entry.title)
        net.WriteUInt(entry.duration, 32)
        net.WriteString(entry.requester)
    end

    net.Send(target)
end

function ENT:SendPlay(target)
    if not self.Pool.Playing then return end

    if not target then
        target = self.Pool.Players
    end

    local playlist = self.Pool.Playlist
    local topEntry = playlist[1]
    
    net.Start(self.NetworkString)
    net.WriteUInt(ASA_MEDIAPLAYER_NET_SEND_PLAY, 4)
    net.WriteEntity(self)
    net.WriteUInt(self.Pool.Duration, 32)
    net.WriteUInt(self.Pool.EndTime, 32)
    net.WriteString(topEntry.videoURL)
    net.WriteString(topEntry.audioURL)
    net.Send(target)
end

function ENT:SendStop(target)
    if not target then
        target = self.Pool.Players
    end

    net.Start(self.NetworkString)
    net.WriteUInt(ASA_MEDIAPLAYER_NET_SEND_STOP, 4)
    net.WriteEntity(self)
    net.Send(target)
end

function ENT:SendSeek(target, offset)
    if not self.Pool.Playing then return end

    if not target then
        target = self.Pool.Players
    end

    net.Start(self.NetworkString)
    net.WriteUInt(ASA_MEDIAPLAYER_NET_SEND_SEEK, 4)
    net.WriteEntity(self)
    net.WriteUInt(offset, 32)
    net.Send(self.Pool.Players)
end

function ENT:Play()
    local playlist = self.Pool.Playlist
    local topEntry = playlist[1]

    self.Pool.Playing = true
    self.Pool.Duration = topEntry.duration
    self.Pool.EndTime = CurTime() + self.Pool.Duration

    self:SendPlay()
end

function ENT:Stop()
    self.Pool.Playing = false
    self.Pool.Duration = 0
    self.Pool.EndTime = 0

    self:SendStop()
end

function ENT:Seek(offset)
    if not self.Pool.Playing then return end

    self.Pool.EndTime = CurTime() + (self.Pool.Duration - offset)
    self:SendSeek(nil, offset)
end

function ENT:PushPlaylist(entry)
    table.insert(self.Pool.Playlist, entry)
    self:SendPlaylist()

    if not self.Pool.Playing then
        self:Play()
    end
end

function ENT:PopPlaylist()
    local playlist = self.Pool.Playlist
    local numEntries = #playlist

    if #self.Pool.Playlist > 0 then
        table.remove(self.Pool.Playlist, 1)
        self:SendPlaylist()

        if #self.Pool.Playlist > 0 then
            self:Play()
        else
            self:Stop()
        end
    end
end

function ENT:Add(ply, videoID)
    local plyNick = ply:Nick()

    local onProcessed = function(data)
        if data.error > 0 then
            if IsValid(ply) then
                chat.AddText(ply, Color(255, 255, 255), "Video doesn't have a WebM format.")
            end
            
            return
        end

        local entry = {}
        entry.title = utf8.sub(data.title, 1, maxChars)
        entry.requester = utf8.sub(plyNick, 1, maxChars)
        entry.duration = tonumber(data.duration)
        entry.videoURL = data.video
        entry.audioURL = data.audio

        self:PushPlaylist(entry)
        
        if IsValid(ply) then
            chat.AddText(ply, Color(255, 255, 255), "Video added to the playlist")
        end
    end

	local httpStruct = 
	{
		success = function(code, body)
			local data = util.JSONToTable(body)
            onProcessed(data)
		end,
		method = "GET",
		url = string.format(apiURL:GetString(), videoID),
		type = "application/json",
	}

	HTTP(httpStruct)
end

function ENT:JoinPool(ply)
    self.Pool.Players:AddEntity(ply)

    if self.Pool.Playing then
        self:SendPlaylist(ply)
        self:SendPlay(ply)
    end
end

function ENT:LeavePool(ply)
    self.Pool.Players:RemoveEntity(ply)
end

function ENT:Initialize()
    self:SetModel("models/props_c17/consolebox01a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:Wake()
    end

    local entIndex = self:EntIndex()
    mediaPlayersQueue[entIndex] = self

    self:CreatePool()
end

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end

function ENT:OnRemove()
    local entIndex = self:EntIndex()
    mediaPlayersQueue[entIndex] = nil
end

function ENT:Think()
    if self.Pool.Playing and CurTime() > self.Pool.EndTime then
        self:PopPlaylist()
    end
end

local function HandleMediaPlayerNetwork(len, ply)
    local code = net.ReadUInt(4)
    local mediaPlayer = net.ReadEntity()
    local entIndex = mediaPlayer:EntIndex()

    if not IsValid(mediaPlayer) then return end
    if not mediaPlayersQueue[entIndex] then return end
    
    local isOwner = (mediaPlayer:GetRealOwner() == ply)

    local handlers = 
    {
        [ASA_MEDIAPLAYER_NET_REQUEST_SEEK] = function()
            local offset = net.ReadUInt(32)

            if isOwner then
                mediaPlayer:Seek(offset)
            end
        end,

        [ASA_MEDIAPLAYER_NET_REQUEST_ADD] = function()
            local videoID = net.ReadString()
            mediaPlayer:Add(ply, videoID)
        end,

        [ASA_MEDIAPLAYER_NET_REQUEST_SKIP] = function()
            if isOwner then
                mediaPlayer:PopPlaylist()
            end
        end,

        [ASA_MEDIAPLAYER_NET_REQUEST_JOIN] = function()
            mediaPlayer:JoinPool(ply)
        end,

        [ASA_MEDIAPLAYER_NET_REQUEST_LEAVE] = function()
            mediaPlayer:LeavePool(ply)
        end
    }

    local handler = handlers[code]
    if handler then
        handler()
    end
end

local function RemoveDisconnectedPlayer(ply)
    for index, mediaPlayer in pairs(mediaPlayersQueue) do
        if IsValid(mediaPlayer) then
            mediaPlayer:LeavePool(ply)
        end
    end
end

net.Receive(ENT.NetworkString, HandleMediaPlayerNetwork)
hook.Add("PlayerDisconnected", "ASA.Mediaplayer.CleanDisconnectedPlayers", RemoveDisconnectedPlayer)