include("shared.lua")

local htmlPlayer = include("cl_htmlplayer.lua")
local videoPicker = include("cl_videopicker.lua")

local maxDrawDistance = CreateClientConVar("asa_mediaplayer_max_distance", "1500", true, false, "Maximum distance to draw any mediaplayer screen")
local syncDelay = CreateClientConVar("asa_mediaplayer_sync_delay", "0.5", true, false, "Mediaplayer sync check delay", 0.1, 1)
local syncThreshold = CreateClientConVar("asa_mediaplayer_sync_threshold", "0.09", true, false, "Mediaplayer sync check delay", 0.09, 1.0)
local emissiveEnabled = CreateClientConVar("asa_mediaplayer_emissive_light", "1", true, false, "Mediaplayer emissive light", 0, 1)
local emissiveSize = CreateClientConVar("asa_mediaplayer_emissive_size", "256", true, false, "Mediaplayer emissive light RT size", 128, 512)
local playerVolume = CreateClientConVar("asa_mediaplayer_volume", "35", true, false, "Mediaplayer volume", 0, 100)

local uiWidgets = include("cl_ui.lua")
local uiRT = GetRenderTarget("ASA_MediaPlayer_UI", ENT.ScreenWidth * 2, ENT.ScreenHeight * 2)
local uiRTMat = CreateMaterial("ASA_MediaPlayer_UI", "UnlitGeneric", 
    {
        ["$basetexture"] = uiRT:GetName(),
        ["$translucent"] = "1"
    }
)

local mediaPlayersQueue = {}

function ENT:CreatePlayer()
    self.Player = {}
    self.Player.Enabled = false
    self.Player.LastLatch = false
    self.Player.IsOwner = (self:GetRealOwner() == LocalPlayer())
    self.Player.Playing = false
    self.Player.Playlist = {}
    self.Player.Volume = playerVolume:GetFloat()
    self.Player.Duration = 0
    self.Player.EndTime = 0
end

function ENT:RemovePlayer()
end

function ENT:RequestSeek(offset)
    net.Start(self.NetworkString)
    net.WriteUInt(ASA_MEDIAPLAYER_NET_REQUEST_SEEK, 4)
    net.WriteEntity(self)
    net.WriteUInt(offset, 32)
    net.SendToServer()
end

function ENT:RequestSkip()
    net.Start(self.NetworkString)
    net.WriteUInt(ASA_MEDIAPLAYER_NET_REQUEST_SKIP, 4)
    net.WriteEntity(self)
    net.SendToServer()
end

function ENT:RequestAdd(videoID)
    net.Start(self.NetworkString)
    net.WriteUInt(ASA_MEDIAPLAYER_NET_REQUEST_ADD, 4)
    net.WriteEntity(self)
    net.WriteString(videoID)
    net.SendToServer()
end

function ENT:UpdatePlaylist(playlist)
    self.Player.Playlist = playlist
end

function ENT:Seek(offset)
    if not self.Player.Playing then return end

    self.Player.EndTime = CurTime() + (self.Player.Duration - offset)
    self.HTML:QueueJavascript("seekTo(" .. math.Round(offset, 2) .. ")")
end

function ENT:Sync()
    local duration = self.Player.Duration
    local endTime = self.Player.EndTime

    local curTime = CurTime()
    local remainingTime = math.Clamp(endTime - curTime, 0, duration)
    local offsetTime = math.Clamp(math.abs(remainingTime - duration), 0, duration)

    self:Seek(offsetTime)
    self:SetVolume()
end

function ENT:SetVolume(vol)
    if not vol then
        vol = self.Player.Volume
    end

    self.Player.Volume = vol
    playerVolume:SetFloat(vol)

    if not self.Player.Playing then return end
    self.HTML:QueueJavascript("setVolume(" .. vol .. ")")
end

function ENT:Play(duration, endTime, videoUrl, audioUrl)
    if self.HTML then
        self.HTML:QueueJavascript("playMedia('" .. videoUrl .. "', '" .. audioUrl .. "')")
    end
    
    self.Player.Playing = true
    self.Player.Volume = playerVolume:GetFloat()
    self.Player.Duration = duration
    self.Player.EndTime = endTime
end

function ENT:ForceStop()
    if self.HTML then
        self.HTML:QueueJavascript("playMedia('', '')")
    end

    self.Player.Playing = false
    self.Player.Duration = 0
    self.Player.EndTime = 0
end

function ENT:Enable()
    self.Player.Enabled = true
    self:CreateHTML()

    net.Start(self.NetworkString)
    net.WriteUInt(ASA_MEDIAPLAYER_NET_REQUEST_JOIN, 4)
    net.WriteEntity(self)
    net.SendToServer()
end

function ENT:Disable()
    self.Player.Enabled = false
    self:RemoveHTML()

    net.Start(self.NetworkString)
    net.WriteUInt(ASA_MEDIAPLAYER_NET_REQUEST_LEAVE, 4)
    net.WriteEntity(self)
    net.SendToServer()
end

function ENT:CreateUI()
    self.ImguiContext = {}
    
    self.UIState = {}
    self.UIState.Fader = -1000
    self.UIState.Scroll = 0
end

function ENT:RemoveUI()
end

function ENT:DrawMenu()
    local emptyPlaylist = (#self.Player.Playlist == 0)
    local isPlaying = self.Player.Playing
    local isOwner = self.Player.IsOwner

    local faderOffset = 100
    local playlistPadding = 4
    local playlistScrollWidth = 16
    local playlistWidth = 512 + playlistScrollWidth
    
    local playlistVolumeHeight = 50
    local playlistControlsSliderHeight = 25
    local playlistControlsHeight = 55
    if not emptyPlaylist then
        playlistControlsHeight = playlistControlsHeight + playlistControlsSliderHeight
    end

    local mx, my = imgui.GetMousePos()
    if mx < playlistWidth + faderOffset and mx != IMGUI_MOUSEPOS_INVALID then
        self.UIState.Fader = Lerp(RealFrameTime() * 10, self.UIState.Fader, 0)
    else
        self.UIState.Fader = Lerp(RealFrameTime() * 10, self.UIState.Fader, -playlistWidth)
    end

    if not isPlaying then
        imgui.BeginWindow("NoMedia", 0, 0, IMGUI_SIZE_CONTENT, IMGUI_SIZE_CONTENT)
            uiWidgets.NoMediaBox()
        imgui.EndWindow(true)
    end

    imgui.BeginWindow("Menu", math.Round(self.UIState.Fader, 2), 0, playlistWidth, IMGUI_SIZE_CONTENT)
        imgui.SetPadding(playlistPadding, playlistPadding, playlistPadding, playlistPadding)

        imgui.BeginGroup(IMGUI_SIZE_CONTENT, playlistControlsHeight)
            imgui.SetPadding(playlistPadding, playlistPadding, playlistPadding, playlistPadding)

            if not emptyPlaylist and isPlaying then
                uiWidgets.TimeSlider(playlistControlsSliderHeight, self.Player.Duration, self.Player.EndTime, function(offset)
                    if isOwner then
                        self:RequestSeek(offset)
                    end
                end)
            end

            imgui.SameLine()

            if not emptyPlaylist and isOwner and isPlaying then
                -- uiWidgets.ActionButton("") -- play

                if uiWidgets.ActionButton("") then
                    self:RequestSkip()
                end
            end

            if uiWidgets.ActionButton("") then
                videoPicker.Open(function(videoID) self:RequestAdd(videoID) end)
            end

            if not emptyPlaylist and isPlaying then
                uiWidgets.DurationInfo(self.Player.Duration, self.Player.EndTime)
            else
                uiWidgets.EmptyInfo()
            end
        imgui.EndGroup()
        
        local remainingW, remainingH = imgui.GetLayout()
        imgui.BeginGroup(IMGUI_SIZE_CONTENT, remainingH - playlistVolumeHeight)
            imgui.SetPadding(0, 0, 0, 0)
            imgui.SameLine()
            
            local insideW, insideH = imgui.GetLayout()
            local canvas = imgui.BeginGroup(insideW - playlistScrollWidth, insideH, self.UIState.Scroll)
                imgui.SetPadding(playlistPadding, playlistPadding, playlistPadding, playlistPadding)

                local playlist = self.Player.Playlist

                for i = 1, #playlist do
                    local entry = playlist[i]
                    local title = entry.title
                    local duration = entry.duration
                    local requester = entry.requester
                    
                    uiWidgets.PlaylistEntry((i == 1), title, duration, requester)
                end
            imgui.EndGroup()
            
            self.UIState.Scroll = imgui.VerticalScroll(playlistScrollWidth, true, canvas, true)
        imgui.EndGroup()
        
        imgui.BeginGroup(IMGUI_SIZE_CONTENT, IMGUI_SIZE_CONTENT)
            imgui.SetPadding(playlistPadding, playlistPadding, playlistPadding, playlistPadding)
            imgui.SameLine()
            uiWidgets.ActionIcon("")
            uiWidgets.VolumeSlider(self.Player.Volume, function(newVol)
                self:SetVolume(newVol)
            end)
        imgui.EndGroup()
    imgui.EndWindow()
end

function ENT:DrawIdle()
    imgui.BeginWindow("Idle", 0, 0, IMGUI_SIZE_CONTENT, IMGUI_SIZE_CONTENT)
        uiWidgets.DisabledBox()
    imgui.EndWindow(true)
end

function ENT:DrawUI()
    local isEnabled = self.Player.Enabled

	render.PushRenderTarget(uiRT)
	cam.Start2D()
	render.Clear(0, 0, 0, 0)
    render.OverrideAlphaWriteEnable(true, true)
    render.ClearDepth()

    if isEnabled then
        self:DrawMenu()
    else
        self:DrawIdle()
    end
    
    render.OverrideAlphaWriteEnable(false)
	cam.End2D()
	render.PopRenderTarget()

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(uiRTMat)
	surface.DrawTexturedRect(0, 0, self.ScreenWidth * 2, self.ScreenHeight * 2)
end

function ENT:CreateHTML()
    if self.HTML or self.HTMLMaterial then return end

    self.HTML = vgui.Create("DHTML")
	self.HTML:SetSize(self.HTMLWidth, self.HTMLHeight)
	self.HTML:SetHTML(htmlPlayer)
	self.HTML:SetAlpha(0)
	self.HTML:SetMouseInputEnabled(false)
    self.HTML:SetKeyboardInputEnabled(false)
    self.HTML.ConsoleMessage = function(...) end
    self.HTML.OnDocumentReady = function(...)
        self.HTML:AddFunction("gmod", "requestSync", function()
             self:Sync()
        end)

        self.HTML:AddFunction("gmod", "checkSync", function(videoTime, audioTime)
            local diff = math.abs(videoTime - audioTime)
            local threshold = syncThreshold:GetFloat()

            if diff > threshold then
                self:Sync()
            end
       end)
    end

    self.NextSync = 0
    self.HTMLMaterial = nil
end

function ENT:RemoveHTML()
    if self.HTML then
        self.HTML:Remove()
        self.HTML = nil
    end

    if self.HTMLMaterial then
        self.HTMLMaterial = nil
    end

    if self.EmissiveProjector then
        self.EmissiveProjector:Remove()
        self.EmissiveProjector = nil
    end
end

function ENT:DrawHTML()
    if not self.HTML then return end

	if not self.HTMLMaterial and self.HTML:GetHTMLMaterial() then
        local scaleX = self.HTMLWidth / (self.ScreenWidth * 2)
        local scaleY = self.HTMLHeight / (self.ScreenHeight * 2)

		local htmlMat = self.HTML:GetHTMLMaterial()
		local matData =
		{
			["$basetexture"] = htmlMat:GetName(),
			["$basetexturetransform"] = "center 0 0 scale ".. scaleX .. " " .. scaleY .. " rotate 0 translate 0 0"
		}

		local uid = string.Replace(htmlMat:GetName(), "__vgui_texture_", "")
		self.HTMLMaterial = CreateMaterial("ASA_MediaPlayer_" .. uid, "UnlitGeneric", matData)
	end

    if self.HTMLMaterial then
        surface.SetMaterial(self.HTMLMaterial)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(0, 0, self.ScreenWidth * 2, self.ScreenHeight * 2)
    else
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(0, 0, self.ScreenWidth * 2, self.ScreenHeight * 2)
    end
end

function ENT:UpdateHTML()
    if not self.HTML then return end

    local curTime = CurTime()

    if curTime > self.NextSync then
        self.HTML:QueueJavascript("checkSync()")
        self.NextSync = curTime + syncDelay:GetFloat()
    end
end

function ENT:UpdateEmissiveProjector()
    if not emissiveEnabled:GetBool() then return end
    
    local screenValid = self.ScreenValid
    local screenPos = self.ScreenPos
    local screenAng = self.ScreenAng
    local screenScale = self.ScreenScale

    local rtSize = emissiveSize:GetInt()

    if not self.EmissiveRT then
        local rtName = string.format("ASA_MediaPlayer_Emissive[%i]", self:EntIndex())
        self.EmissiveRT = GetRenderTargetEx(rtName, rtSize, rtSize, RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_NONE, 2, 0, IMAGE_FORMAT_RGB888)
    end

    if not self.EmissiveProjector then
        self.EmissiveProjector = ProjectedTexture()
        self.EmissiveProjector:SetTexture(self.EmissiveRT)
        self.EmissiveProjector:SetBrightness(1.75)
        self.EmissiveProjector:SetEnableShadows(false)
        self.EmissiveProjector:SetQuadraticAttenuation(1)
        self.EmissiveProjector:SetLinearAttenuation(0.2)
        self.EmissiveProjector:SetConstantAttenuation(0.10)
    end

    if screenValid then
        local backDir = screenAng:Up()
        local backAng = backDir:Angle()

        self.EmissiveProjector:SetNearZ(1)
        self.EmissiveProjector:SetFarZ(screenScale * 2000)
        self.EmissiveProjector:SetFOV(179)
        self.EmissiveProjector:SetPos(screenPos)
        self.EmissiveProjector:SetAngles(backAng)
    else
        self.EmissiveProjector:SetNearZ(0)
    end

    render.PushRenderTarget(self.EmissiveRT)

    cam.Start2D()
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(0, 0, rtSize, rtSize)

        if self.HTMLMaterial then
            local scaleX = (self.ScreenWidth * 2) / self.HTMLWidth
            local scaleY = (self.ScreenHeight * 2) / self.HTMLHeight
            local tileOffset = rtSize - (rtSize * scaleX)

            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(self.HTMLMaterial)
            surface.DrawTexturedRectUV(tileOffset, 0, rtSize * scaleX, rtSize * scaleY, 1, 0, 0, 1)
        end
    cam.End2D()
    
    surface.SetDrawColor(255, 255, 255, 0)
    render.BlurRenderTarget(self.EmissiveRT, rtSize / 4, rtSize / 4, 8)
    render.PopRenderTarget()

    self.EmissiveProjector:Update()
end

function ENT:DrawScreen()
    local maxDrawDist = math.pow(maxDrawDistance:GetInt(), 2)
    local screenDist = self:GetPos():DistToSqr(EyePos())
    if screenDist > maxDrawDist then return end

    local center = self:LocalToWorld(self:OBBCenter())
    local rayDist = self.RayLength

    local traceConfig =
    {
        start = center,
        endpos = center + self:GetForward() * rayDist,
        filter = EntityList(self, player.GetAll()),
        mask = MASK_SOLID
    }

    local trace = util.TraceLine(traceConfig)

    if trace.Hit then
        local hitPos = trace.HitPos
        local hitNormal = trace.HitNormal
        
        local screenPos = hitPos + hitNormal * 1
        local screenScale = trace.Fraction * self:GetMultiplier()
        local screenWidth = self.ScreenWidth
        local screenHeight = self.ScreenHeight

        local screenAng = hitNormal:Angle()
        screenAng:RotateAroundAxis(screenAng:Right(), -90)
        screenAng:RotateAroundAxis(screenAng:Up(), 90)

        local cx, cy = cursor3d2d.PlaneIntersect(screenPos, screenAng, screenScale)
        cx = cx + screenWidth
        cy = cy + screenHeight

        local screenMat = Matrix()
        screenMat:Translate(Vector(-screenWidth, -screenHeight, 0))

        local boxPos = screenPos
        local boxSize = Vector(screenWidth * screenScale, 4, screenHeight * screenScale)

        local boxAng = hitNormal:Angle()
        boxAng:RotateAroundAxis(boxAng:Up(), 90)

        -- render.SetColorMaterial()
        -- render.DrawBox(boxPos, boxAng, boxSize, -boxSize, color_white)

        local validCursor = cursor3d2d.CursorTrace(boxPos, boxAng, -boxSize, boxSize, rayDist)
        if not validCursor then
            cx = IMGUI_MOUSEPOS_INVALID
            cy = IMGUI_MOUSEPOS_INVALID
        end

        local interacting = cursor3d2d.GetInteracting()
        local interactingSpecial = cursor3d2d.GetInteractingSpecial()
        local isEnabled = self.Player.Enabled
        local toggleLatch = self.Player.LastLatch

        if validCursor and self.Player.LastLatch != interactingSpecial then
            if interactingSpecial then
                if isEnabled then
                    self:Disable()
                else
                    self:Enable()
                end
            end

            self.Player.LastLatch = interactingSpecial
        end

        cam.Start3D2D(screenPos, screenAng, screenScale)
            cam.PushModelMatrix(screenMat, true)
                self:DrawHTML()
                
                imgui.Context3D2D(self.ImguiContext, screenWidth * 2, screenHeight * 2)
                imgui.PushInputExternal(cx, cy, interacting)
                    self:DrawUI()
                imgui.ContextEnd()
            cam.PopModelMatrix()
        cam.End3D2D()

        self.ScreenValid = true
        self.ScreenPos = screenPos
        self.ScreenAng = screenAng
        self.ScreenScale = screenScale
    else
        self.ScreenValid = false
    end

    self:UpdateEmissiveProjector()
end

function ENT:Draw()
    self:DrawModel()
end

function ENT:Think()
    self:UpdateHTML()
end

function ENT:Initialize()
    self:CreateUI()
    self:CreatePlayer()

    local entIndex = self:EntIndex()
    mediaPlayersQueue[entIndex] = self
end

function ENT:OnRemove(fullUpdate)
    if fullUpdate then return end
    self:RemovePlayer()
    self:RemoveHTML()
    self.RemoveUI()

    local entIndex = self:EntIndex()
    mediaPlayersQueue[entIndex] = nil
end

local function HandleMediaPlayerNetwork(len)
    local code = net.ReadUInt(4)
    local mediaPlayer = net.ReadEntity()

    local handlers = 
    {
        [ASA_MEDIAPLAYER_NET_SEND_PLAYLIST] = function()
            local numEntries = net.ReadUInt(8)
            local playlist = {}

            for i = 1, numEntries do
                local title = net.ReadString()
                local duration = net.ReadUInt(32)
                local requester = net.ReadString()

                table.insert(playlist, {title = title, duration = duration, requester = requester})
            end
            
            mediaPlayer:UpdatePlaylist(playlist)
        end,

        [ASA_MEDIAPLAYER_NET_SEND_SEEK] = function()
            local offset = net.ReadUInt(32)
            mediaPlayer:Seek(offset)
        end,

        [ASA_MEDIAPLAYER_NET_SEND_PLAY] = function()
            local duration = net.ReadUInt(32)
            local endTime = net.ReadUInt(32)
            local videoUrl = net.ReadString()
            local audioUrl = net.ReadString()

            mediaPlayer:Play(duration, endTime, videoUrl, audioUrl)
        end,

        [ASA_MEDIAPLAYER_NET_SEND_STOP] = function()
            mediaPlayer:ForceStop()
        end
    }

    local handler = handlers[code]
    if handler then
        handler()
    end
end

local function DrawMediaPlayerScreens()
    for index, mediaPlayer in pairs(mediaPlayersQueue) do
        if IsValid(mediaPlayer) then
            mediaPlayer:DrawScreen()
        end
    end
end

hook.Add("PostDrawOpaqueRenderables", "ASA.MediaPlayer.DrawScreens", DrawMediaPlayerScreens)
net.Receive(ENT.NetworkString, HandleMediaPlayerNetwork)