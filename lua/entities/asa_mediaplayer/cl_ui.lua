surface.CreateFont("asa_mediaplayer_name", 
    {
        font = "Roboto",
        size = 24,
        weight = 500
    }
)

surface.CreateFont("asa_mediaplayer_misc", 
    {
        font = "Roboto",
        size = 18,
        weight = 500
    }
)

surface.CreateFont("asa_mediaplayer_duration", 
    {
        font = "Roboto",
        size = 28,
        weight = 500
    }
)

surface.CreateFont("asa_mediaplayer_volume", 
    {
        font = "Roboto",
        size = 24,
        weight = 500
    }
)

surface.CreateFont("asa_mediaplayer_info", 
    {
        font = "Roboto",
        size = 48,
        weight = 500
    }
)

surface.CreateFont("asa_mediaplayer_icons", 
    {
        font = "asamediaplayer",
        size = 38,
        weight = 500
    }
)

/*

 0xe800 play
 0xe801 pause
 0xe802 add
 0xe803 skip
 0xe804 volume

*/

local function FormatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = (seconds % 60)

    if h > 0 then
        return string.format("%02d:%02d:%02d", h, m, s)
    else
        return string.format("%02d:%02d", m, s)
    end
end

local Widgets = {}

function Widgets.DisabledBox()
    local w, h = imgui.GetLayout()
    local x, y = imgui.GetCursor()

    local txt = "Press Shift + E to enable"

    imgui.Draw(function()
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(x, y, w, h)

        surface.SetFont("asa_mediaplayer_info")
        local textW, textH = surface.GetTextSize(txt)

        surface.SetTextColor(255, 255, 255, 255)
        surface.SetTextPos(x + w / 2 - textW / 2, y + h / 2 - textH / 2)
        surface.DrawText(txt)
    end)

    imgui.ContentAdd(w, h)
end

function Widgets.NoMediaBox()
    local w, h = imgui.GetLayout()
    local x, y = imgui.GetCursor()

    local txt = "No media playing, swipe to the left to open the menu"

    imgui.Draw(function()
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(x, y, w, h)
        
        surface.SetFont("asa_mediaplayer_info")
        local textW, textH = surface.GetTextSize(txt)

        surface.SetTextColor(255, 255, 255, 255)
        surface.SetTextPos(x + w / 2 - textW / 2, y + h / 2 - textH / 2)
        surface.DrawText(txt)
    end)

    imgui.ContentAdd(w, h)
end

function Widgets.TimeSlider(h, duration, endTime, onChange)
    local w, _ = imgui.GetLayout()
    local x, y = imgui.GetCursor()

    local curTime = CurTime()
    local remainingTime = math.Clamp(endTime - curTime, 0, duration)
    local sliderTime = math.Clamp(math.abs(remainingTime - duration), 0, duration)
    local timeFraction = (sliderTime / duration)

    local isHovering = imgui.MouseInRect(x, y, w, h)
    local hasClicked = imgui.HasClicked()

    if isHovering and hasClicked then
        local mouseX = imgui.GetMouseX()
        local localMouseX = (mouseX - x)
        local sliderPerc = math.Clamp(localMouseX / w, 0, 1)
        local newTime = math.floor(sliderPerc * duration)

        onChange(newTime)
    end

    imgui.Draw(function()
        surface.SetDrawColor(39, 39, 39)
        surface.DrawRect(x, y, w, h)

        local progress = timeFraction * w
        surface.SetDrawColor(185, 185, 185)
        surface.DrawRect(x, y, progress, h)

        local handleX = (x + progress - 10)
        surface.SetDrawColor(233, 233, 233)
        surface.DrawRect(handleX, y, 10, h)
    end)

    imgui.ContentAdd(w, h)
end

function Widgets.PlaylistEntry(highlight, name, duration, requester)
    local h = 64
    local w, _ = imgui.GetLayout()
    local x, y = imgui.GetCursor()

    local durationTxt = FormatTime(duration)

    imgui.Draw(function()
        if highlight then
            surface.SetDrawColor(45, 45, 45)
        else
            surface.SetDrawColor(34, 34, 34)
        end

        surface.DrawRect(x, y, w, h)

        draw.SimpleText(name, "asa_mediaplayer_name", x + 10, y + 10, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(durationTxt, "asa_mediaplayer_misc", x + 10, y + 34, Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Added by " .. requester, "asa_mediaplayer_misc", x + w - 10, y + 34, Color(200, 200, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end)

    imgui.ContentAdd(w, h)
end

function Widgets.ActionButton(iconChar)
    local _, h = imgui.GetLayout()
    local w = h
    local x, y = imgui.GetCursor()
    
    local isHovering = imgui.MouseInRect(x, y, w, h)
    local hasClicked = imgui.HasClicked()

    imgui.Draw(function()
        surface.SetFont("asa_mediaplayer_icons")
        local textW, textH = surface.GetTextSize(iconChar)

        if isHovering then
            surface.SetTextColor(255, 255, 255, 255)
        else
            surface.SetTextColor(180, 180, 180, 255)
        end

        surface.SetTextPos(x + w / 2 - textW / 2, y + h / 2 - textH / 2)
        surface.DrawText(iconChar)
    end)

    imgui.ContentAdd(w, h)

    return isHovering and hasClicked
end

function Widgets.ActionIcon(iconChar)
    local _, h = imgui.GetLayout()
    local w = h
    local x, y = imgui.GetCursor()

    imgui.Draw(function()
        surface.SetFont("asa_mediaplayer_icons")
        local textW, textH = surface.GetTextSize(iconChar)

        surface.SetTextColor(255, 255, 255, 255)
        surface.SetTextPos(x + w / 2 - textW / 2, y + h / 2 - textH / 2)
        surface.DrawText(iconChar)
    end)

    imgui.ContentAdd(w, h)
end

function Widgets.DurationInfo(duration, endTime)
    local w, h = imgui.GetLayout()
    local x, y = imgui.GetCursor()

    local curTime = CurTime()
    local remainingTime = math.Clamp(endTime - curTime, 0, duration)
    local nowTime = math.Clamp(math.abs(remainingTime - duration), 0, duration)
    
    local durationFormatted = FormatTime(duration)
    local nowFormatted = FormatTime(nowTime)
    local finalTxt = string.format("%s / %s", nowFormatted, durationFormatted)

    local txtPadding = 4

    imgui.Draw(function()
        surface.SetFont("asa_mediaplayer_duration")
        local textW, textH = surface.GetTextSize(finalTxt)
        
        surface.SetTextColor(255, 255, 255, 255)
        surface.SetTextPos(x + w - textW - txtPadding, y + h / 2 - textH / 2)
        surface.DrawText(finalTxt)
    end)

    imgui.ContentAdd(w, h)
end

function Widgets.EmptyInfo()
    local w, h = imgui.GetLayout()
    local x, y = imgui.GetCursor()

    local finalTxt = "No media playing"
    local txtPadding = 4

    imgui.Draw(function()
        surface.SetFont("asa_mediaplayer_duration")
        local textW, textH = surface.GetTextSize(finalTxt)
        
        surface.SetTextColor(255, 255, 255, 255)
        surface.SetTextPos(x + w - textW - txtPadding, y + h / 2 - textH / 2)
        surface.DrawText(finalTxt)
    end)

    imgui.ContentAdd(w, h)
end

function Widgets.VolumeSlider(value, onChange)
    local w, h = imgui.GetLayout()
    local x, y = imgui.GetCursor()

    local centerHeightOffset = 8
    h = h - centerHeightOffset * 2
    y = y + centerHeightOffset

    local minValue = 0
    local maxValue = 100
    local valueText = string.format("%i%%", value)

    local isHovering = imgui.MouseInRect(x, y, w, h)
    local isPressing = isHovering and imgui.IsPressing()

    if isPressing then
        local mouseX = imgui.GetMouseX()
        local relativeX = (mouseX - x)
        local perc = math.Round(relativeX / w, 2)
        local finalValue = minValue + (maxValue - minValue) * perc

        onChange(finalValue)
    end

    local valuePerc = (value - minValue) / (maxValue - minValue)

    imgui.Draw(function()
        surface.SetDrawColor(80, 80, 80)
        surface.DrawRect(x, y, w, h)

        surface.SetDrawColor(134, 134, 134)
        surface.DrawRect(x, y, valuePerc * w, h)

        surface.SetFont("asa_mediaplayer_volume")
        local valueTextW, valueTextH = surface.GetTextSize(valueText)

        surface.SetTextColor(255, 255, 255, 255)
        surface.SetTextPos(x + w / 2 - valueTextW / 2, y + h / 2 - valueTextH / 2)
        surface.DrawText(valueText)
    end)

    imgui.ContentAdd(w, h)

    return value
end

return Widgets