local ADDON_NAME, Addon = ...

local originalNames = {}

local function StripServerName(name)
    if not name then return name end
    local spacePos = string.find(name, " ")
    if spacePos then
        return string.sub(name, 1, spacePos - 1)
    end
    return name
end

local function TruncateName(name, maxLength)
    if not name or maxLength <= 0 then return name end
    
    local len = strlenutf8 and strlenutf8(name) or #name
    if len <= maxLength then
        return name
    end
    
    if strlenutf8 then
        local truncated = ""
        local count = 0
        for char in string.gmatch(name, "([%z\1-\127\194-\244][\128-\191]*)") do
            if count >= maxLength - 1 then
                break
            end
            truncated = truncated .. char
            count = count + 1
        end
        return truncated .. "…"
    else
        return string.sub(name, 1, maxLength - 1) .. "…"
    end
end

local function RestoreDefaultName(frame)
    if not frame or not frame.name then return end
    
    local unit = frame.unit
    if not unit then return end
    if unit ~= "player" and not unit:match("^party%d$") and not unit:match("^raid%d+$") then
        return
    end
    
    frame.name:ClearAllPoints()
    frame.name:SetPoint("LEFT", frame, "LEFT", 3, 0)
    frame.name:SetJustifyH("LEFT")
    
    local fullName = GetUnitName(unit, false) or ""
    frame.name:SetText(fullName)
end

local function UpdateName(frame)
    if not frame or not frame.name then return end
    
    local unit = frame.unit
    if not unit then return end
    if unit ~= "player" and not unit:match("^party%d$") and not unit:match("^raid%d+$") then
        return
    end
    
    local db = BetterRaidFramesDB
    
    if not db.customizeNames then
        RestoreDefaultName(frame)
        return
    end
    
    local offsetX = db.nameX or 0
    local offsetY = db.nameY or 0
    local hideServer = db.nameHideServer
    local truncateEnabled = db.nameTruncate
    local maxLength = db.nameTruncateLength or 8
    
    frame.name:ClearAllPoints()
    frame.name:SetPoint("CENTER", frame, "CENTER", offsetX, offsetY)
    frame.name:SetJustifyH("CENTER")
    
    if frame.unit then
        local displayName = GetUnitName(frame.unit, false) or ""
        
        if not originalNames[frame] then
            originalNames[frame] = displayName
        end
        
        if hideServer then
            displayName = StripServerName(displayName)
        end
        
        if truncateEnabled then
            displayName = TruncateName(displayName, maxLength)
        end
        
        frame.name:SetText(displayName)
    end
end

function Addon:HookName()
    hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
        UpdateName(frame)
    end)
end

function Addon:UpdateName(frame)
    UpdateName(frame)
end

function Addon:RefreshNames()
    wipe(originalNames)
    Addon:ForEachFrame(UpdateName)
end
