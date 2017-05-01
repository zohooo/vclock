
require("wx")

VERSION = "0.1"

-----------------------------------------------------------
-- Generate a unique new wxWindowID
-----------------------------------------------------------

local COUNTER = wx.wxID_HIGHEST + 1

local function NewID()
    COUNTER = COUNTER + 1
    return COUNTER
end

ID = { }

-----------------------------------------------------------
-- Create main frame and clock controls
-----------------------------------------------------------

sep = package.config:sub(1,1) -- path separator

mainpath = wx.wxGetCwd()
cfgname = mainpath .. sep .. "vclock.ini"

frame = wx.wxFrame(wx.NULL, wx.wxID_ANY, "vClock" .. " " .. VERSION, wx.wxPoint(656,132),
                   wx.wxSize(350, 250), wx.wxSTAY_ON_TOP)

timetext = wx.wxStaticText(frame, wx.wxID_ANY, "00:00:00", wx.wxDefaultPosition,
                   wx. wxDefaultSize)

frame:Fit()
-- frame:SetTransparent(200)

frame:Connect(wx.wxEVT_CLOSE_WINDOW, function(event)
    SavePosition()
    SaveSettings()
    event:Skip()
end)

-----------------------------------------------------------
-- Save and restore configurations
-----------------------------------------------------------

function GetConfig()
    local config = wx.wxFileConfig("vClock", "", cfgname)
    if config then
        config:SetRecordDefaults()
    else
        print("Failed to load config file!")
    end
    return config
end

function SavePosition()
    local config = GetConfig()
    if not config then return end

    config:SetPath("/MainFrame")

    local s    = 0
    local w, h = frame:GetSizeWH()
    local x, y = frame:GetPositionXY()

    if frame:IsMaximized() then
        s = 1
    elseif frame:IsIconized() then
        s = 2
    end

    config:Write("s", s)

    if s == 0 then
        config:Write("x", x)
        config:Write("y", y)
        config:Write("w", w)
        config:Write("h", h)
    end

    config:delete() -- always delete the config
end

function RestorePosition()
    local config = GetConfig()
    if not config then return end

    config:SetPath("/MainFrame")

    local _, s = config:Read("s", -1)
    local _, x = config:Read("x", 0)
    local _, y = config:Read("y", 0)
    local _, w = config:Read("w", 0)
    local _, h = config:Read("h", 0)

    if (s ~= -1) and (s ~= 1) and (s ~= 2) then
        local clientX, clientY, clientWidth, clientHeight
        clientX, clientY, clientWidth, clientHeight = wx.wxClientDisplayRect()

        if x < clientX then x = clientX end
        if y < clientY then y = clientY end

        if w > clientWidth  then w = clientWidth end
        if h > clientHeight then h = clientHeight end

        frame:SetSize(x, y, w, h)
    elseif s == 1 then
        frame:Maximize(true)
    end

    config:delete() -- always delete the config
end

RestorePosition()

function SaveSettings()
    local config = GetConfig()
    if not config then return end

    config:SetPath("/Settings")
    config:Write("fontsize", fontsize)
    config:Write("background", background)

    config:delete() -- always delete the config
end

function RestoreSettings()
    local config = GetConfig()
    if not config then return end

    config:SetPath("/Settings")
    _, fontsize = config:Read("fontsize", "normal")
    _, background = config:Read("background", "white")

    config:delete() -- always delete the config
end

RestoreSettings()

-----------------------------------------------------------
-- Use a timer to update current time
-----------------------------------------------------------

ID.TIMER_CLOCK = NewID()
local clockTimer = wx.wxTimer(frame, ID.TIMER_CLOCK)

function UpdateClock()
    local now = wx.wxDateTime:Now()
    timetext:SetLabel(now:Format("%H:%M:%S"))
    frame:Fit()
end

frame:Connect(ID.TIMER_CLOCK, wx.wxEVT_TIMER, UpdateClock)

clockTimer:Start(1000);

-----------------------------------------------------------
-- Setup font size and background color
-----------------------------------------------------------

local font = wx.wxFont(11, wx.wxFONTFAMILY_MODERN, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD)

function UpdateFontSize(point)
   font:SetPointSize(point)
   timetext:SetFont(font)
   UpdateClock()
end

function SetFontSize(size)
    if size == "large" then
        UpdateFontSize(14)
    elseif size == "normal" then
        UpdateFontSize(11)
    else -- small
        UpdateFontSize(8)
    end
    fontsize = size
end

function SetBackground(bg)
    local color
    if bg == "white" then
        color = wx.wxColour(255,255,255)
    elseif bg == "gray" then
        color = wx.wxColour(171,171,171)
    else -- blue
        color = wx.wxColour(54,54,178)
    end
    frame:SetBackgroundColour(color)
    background = bg
end

if not fontsize then fontsize = "normal" end
if not background then background = "white" end

SetFontSize(fontsize)
SetBackground(background)

-----------------------------------------------------------
-- Use left mouse to move the window
-----------------------------------------------------------

local dragging = false
local deltax, deltay

timetext:Connect(wx.wxEVT_LEFT_DOWN, function(event)
    -- print("mouse down")
    dragging = true
    local framepos = frame:GetPosition()
    local mousepos = wx.wxGetMousePosition()
    deltax = mousepos.x - framepos.x
    deltay = mousepos.y - framepos.y
    event:Skip()
end)

timetext:Connect(wx.wxEVT_LEFT_UP, function(event)
    -- print("mouse up")
    dragging = false
    event:Skip()
end)

timetext:Connect(wx.wxEVT_LEAVE_WINDOW, function(event)
    -- print("mouse leave")
    dragging = false
    event:Skip()
end)

timetext:Connect(wx.wxEVT_MOTION, function(event)
    if dragging then
        local pos = wx.wxGetMousePosition()
        local newx = pos.x - deltax
        local newy = pos.y - deltay
        -- print(newx,newy)
        frame:Move(newx, newy)
    end
    event:Skip()
end)

-----------------------------------------------------------
-- The popup menu
-----------------------------------------------------------

menu = wx.wxMenu()

ID.FONTSIZE = NewID()
ID.LARGE  = NewID()
ID.NORMAL = NewID()
ID.SMALL  = NewID()

menu:Append(ID.FONTSIZE, "Font Size", wx.wxMenu{
    { ID.LARGE,  "&Large",  "Large",  wx.wxITEM_RADIO },
    { ID.NORMAL, "&Normal", "Normal", wx.wxITEM_RADIO },
    { ID.SMALL,  "&Small",  "Small",  wx.wxITEM_RADIO },
})

menu:Check(ID[string.upper(fontsize)], true)

menu:AppendSeparator()

ID.BACKGROUND = NewID()
ID.WHITE = NewID()
ID.GRAY  = NewID()
ID.BLUE  = NewID()

menu:Append(ID.BACKGROUND, "Background", wx.wxMenu{
    { ID.WHITE, "&White", "White", wx.wxITEM_RADIO },
    { ID.GRAY,  "&Gray",  "Gray",  wx.wxITEM_RADIO },
    { ID.BLUE,  "&Blue",  "Blue",  wx.wxITEM_RADIO },
})

menu:Check(ID[string.upper(background)], true)

menu:AppendSeparator()

ID.ABOUT = NewID()

menu:Append(ID.ABOUT, "&About", "About")

menu:AppendSeparator()

ID.CLOSE = NewID()

menu:Append(ID.CLOSE, "&Close", "Close")

frame:Connect(ID.LARGE, wx.wxEVT_COMMAND_MENU_SELECTED, function(event)
    SetFontSize("large")
end)

frame:Connect(ID.NORMAL, wx.wxEVT_COMMAND_MENU_SELECTED, function(event)
    SetFontSize("normal")
end)

frame:Connect(ID.SMALL, wx.wxEVT_COMMAND_MENU_SELECTED, function(event)
    SetFontSize("small")
end)

frame:Connect(ID.WHITE, wx.wxEVT_COMMAND_MENU_SELECTED, function(event)
    SetBackground("white")
end)

frame:Connect(ID.GRAY, wx.wxEVT_COMMAND_MENU_SELECTED, function(event)
    SetBackground("gray")
end)

frame:Connect(ID.BLUE, wx.wxEVT_COMMAND_MENU_SELECTED, function(event)
    SetBackground("blue")
end)

frame:Connect(ID.ABOUT, wx.wxEVT_COMMAND_MENU_SELECTED, function(event)
    wx.wxMessageBox("vClock" .. " " .. VERSION, "ABOUT")
end)

frame:Connect(ID.CLOSE, wx.wxEVT_COMMAND_MENU_SELECTED, function(event)
    frame:Close()
end)

frame:Connect(wx.wxEVT_CONTEXT_MENU, function(event)
    frame:PopupMenu(menu)
end)

-----------------------------------------------------------
-- Show main frame and start event loop
-----------------------------------------------------------

frame:Show(true)

wx.wxGetApp():MainLoop()
