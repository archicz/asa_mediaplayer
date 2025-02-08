local VideoPicker = {}

local YT_WATCH_PATTERN = "?v=([^&]+)"

function VideoPicker.CheckURL(url)
    local videoID = url:match(YT_WATCH_PATTERN)
    if videoID then
        return true, videoID
    else
        return false, nil
    end
end

local realScreenWidth = ScrW()
local realScreenHeight = ScrH()

function VideoPicker.Open(callback)
    local w = realScreenWidth * 0.75
    local h = realScreenHeight * 0.75
    
    local ignoreUpdates = false
    local selectedVideoID = ""
    local timerName = "CheckURL" .. CurTime()
    local confirmBtnWidth = surface.ScaleWidthDPI(150)
    local controlsHeight = surface.ScaleHeightDPI(25)

    local frame = vgui.Create("DFrame")
    frame:SetTitle("Choose a YouTube Video")
    frame:SetSize(w, h)
    frame:Center()
    frame:MakePopup()

    local controlsPanel = vgui.Create("DPanel", frame)
    controlsPanel:Dock(TOP)
    controlsPanel:SetHeight(controlsHeight)
    controlsPanel:DockMargin(0, 0, 0, surface.ScaleDPI(4))

    local urlEntry = vgui.Create("DTextEntry", controlsPanel)
    urlEntry:Dock(LEFT)
    urlEntry:SetWidth(w - confirmBtnWidth)

    local confirmBtn = vgui.Create("DButton", controlsPanel)
    confirmBtn:Dock(FILL)
    confirmBtn:SetText("Confirm")
    confirmBtn:SetEnabled(false)

    local html = vgui.Create("DHTML", frame)
    html:Dock(FILL)
    html:OpenURL("https://www.youtube.com")
    html.ConsoleMessage = function(...) end

    local function ChangeURL(url)
        local isValid, videoID = VideoPicker.CheckURL(url)

        if isValid then
            selectedVideoID = videoID
        end

        confirmBtn:SetEnabled(isValid)
        urlEntry:SetText(url)
    end

    function html:OnDocumentReady(_)
        html:AddFunction("gmod", "getUrl", function(url)
            if not ignoreUpdates then
                ChangeURL(url)
            end
        end)
    end

    function urlEntry:OnEnter()
        local typedURL = self:GetValue()

        ChangeURL(typedURL)
        html:OpenURL(typedURL)
    end

    function urlEntry:OnGetFocus()
        ignoreUpdates = true
    end

    function urlEntry:OnLoseFocus()
        ignoreUpdates = false
    end

    timer.Create(timerName, 0.5, 0, function()
        if not IsValid(html) then
            timer.Remove(timerName)
            return
        end

        local js = [[
            if (typeof gmod === 'object' && typeof gmod.getUrl === 'function') {
                gmod.getUrl(window.location.href);
            }
        ]]
        
        html:RunJavascript(js)
    end)

    function frame:OnClose()
        timer.Remove(timerName)
    end

    function confirmBtn:DoClick()
        if callback then
            callback(selectedVideoID)
        end

        frame:Close()
    end
end

return VideoPicker