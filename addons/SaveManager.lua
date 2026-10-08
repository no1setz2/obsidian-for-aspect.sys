local cloneref = cloneref or clonereference or function(instance)
    return instance
end

local clonefunction = clonefunction or copyfunction or function(func)
    return func
end

local HttpService = cloneref(game:GetService("HttpService"))
local Players = cloneref(game:GetService("Players"))
local Teams = cloneref(game:GetService("Teams"))
local isfolder, isfile, listfiles = isfolder, isfile, listfiles
local makefolder, writefile, readfile, delfile = makefolder, writefile, readfile, delfile

if typeof(clonefunction) == "function" then
    local isfolder_copy = typeof(isfolder) == "function" and clonefunction(isfolder) or nil
    local isfile_copy = typeof(isfile) == "function" and clonefunction(isfile) or nil
    local listfiles_copy = typeof(listfiles) == "function" and clonefunction(listfiles) or nil

    if isfolder_copy then
        isfolder = function(path)
            local ok, value = pcall(isfolder_copy, path)
            return ok and value == true
        end
    end
    if isfile_copy then
        isfile = function(path)
            local ok, value = pcall(isfile_copy, path)
            return ok and value == true
        end
    end
    if listfiles_copy then
        listfiles = function(path)
            local ok, value = pcall(listfiles_copy, path)
            return ok and typeof(value) == "table" and value or {}
        end
    end
end

local SaveManager = {
    Library = nil,
    Folder = "ObsidianLibSettings",
    SubFolder = "",
    Ignore = {},
    LoadingOrder = {},
    UseLoadingOrder = false,
    AutoloadConfig = nil,
}

local function trim(text)
    return tostring(text or ""):match("^%s*(.-)%s*$")
end

local function empty(text)
    return trim(text) == ""
end

local function validPath(path)
    if typeof(path) ~= "string" or empty(path) or path:find('[<>:"|%?%*%z]') then
        return false
    end
    for segment in string.gmatch(path, "[^/]+") do
        if segment == "." or segment == ".." then return false end
    end
    return true
end

local function validName(name, reserved)
    if typeof(name) ~= "string" then return false end
    name = trim(name)
    if name == "" or name == "." or name == ".." then return false end
    if name:find('[<>:"/|%?%*%z]') then return false end
    if reserved and string.lower(name) == string.lower(reserved) then return false end
    return true
end

local function splitPath(path)
    local result = {}
    local current = ""
    for part in string.gmatch(path, "[^/]+") do
        current = current == "" and part or current .. "/" .. part
        table.insert(result, current)
    end
    return result
end

local function notify(message)
    if SaveManager.Library and SaveManager.Library.Notify then
        SaveManager.Library:Notify(message)
    end
end

local function encodeUDim2(value)
    if typeof(value) == "UDim2" then
        return {
            X = { Scale = value.X.Scale, Offset = value.X.Offset },
            Y = { Scale = value.Y.Scale, Offset = value.Y.Offset },
        }
    end
end

local function decodeUDim2(data)
    if typeof(data) == "UDim2" then
        return data
    end
    if typeof(data) ~= "table" or typeof(data.X) ~= "table" or typeof(data.Y) ~= "table" then
        return nil
    end
    local ok, result = pcall(UDim2.new, data.X.Scale or 0, data.X.Offset or 0, data.Y.Scale or 0, data.Y.Offset or 0)
    return ok and result or nil
end

local function saveElement(index, element)
    local kind = element and element.Type
    if kind == "Toggle" then
        return { type = kind, idx = index, value = element.Value }
    elseif kind == "Slider" then
        return { type = kind, idx = index, value = element.Value }
    elseif kind == "Dropdown" then
        local function encodeValue(value)
            if typeof(value) == "Instance" then
                if value:IsA("Player") then
                    return { __type = "Player", name = value.Name, userId = value.UserId }
                elseif value:IsA("Team") then
                    return { __type = "Team", name = value.Name }
                end
                return { __type = "Instance", name = value.Name, className = value.ClassName }
            elseif typeof(value) == "table" then
                local result = {}
                for key, item in pairs(value) do
                    result[tostring(key)] = encodeValue(item)
                end
                return result
            end
            return value
        end

        local savedValue
        if element.Multi == true then
            local selected = {}
            for value, active in pairs(element.Value or {}) do
                if active then
                    table.insert(selected, encodeValue(value))
                end
            end
            savedValue = { __type = "MultiSelection", items = selected }
        else
            savedValue = encodeValue(element.Value)
        end

        return {
            type = kind,
            idx = index,
            value = savedValue,
            multi = element.Multi == true,
            specialType = element.SpecialType,
        }
    elseif kind == "ColorPicker" then
        return { type = kind, idx = index, value = element.Value:ToHex(), transparency = element.Transparency }
    elseif kind == "KeyPicker" then
        return {
            type = kind,
            idx = index,
            mode = element.Mode,
            key = element.Value,
            modifiers = (function()
                local result = {}
                for _, modifier in pairs(element.Modifiers or {}) do
                    table.insert(result, tostring(modifier))
                end
                return result
            end)(),
            toggled = element.Toggled,
        }
    elseif kind == "Input" then
        return { type = kind, idx = index, text = element.Value }
    end
end

local function loadElement(index, data)
    local library = SaveManager.Library
    if not library or not data or SaveManager.Ignore[index] then
        return
    end

    local element
    if data.type == "Toggle" then
        element = library.Toggles and library.Toggles[index]
        if element then
            assert(element.SetValue, "Toggle option is missing SetValue.")
            element:SetValue(data.value == true)
        end
    elseif data.type == "Slider" or data.type == "Dropdown" or data.type == "ColorPicker" or data.type == "KeyPicker" or data.type == "Input" then
        element = library.Options and library.Options[index]
        if not element then
            return
        end

        if data.type == "Slider" then
            if element.Value == data.value and element.RunChanged then
                element:RunChanged()
            else
                assert(element.SetValue, "Slider option is missing SetValue.")
                element:SetValue(data.value)
            end
        elseif data.type == "Dropdown" then
            if data.value ~= nil then
                local function decodeValue(value)
                    if typeof(value) ~= "table" then
                        return value
                    end
                    if value.__type == "Player" then
                        local player = value.userId and Players:GetPlayerByUserId(value.userId)
                        if not player and value.name then
                            player = Players:FindFirstChild(value.name)
                        end
                        return player
                    elseif value.__type == "Team" then
                        if value.name then
                            for _, team in Teams:GetTeams() do
                                if team.Name == value.name then return team end
                            end
                        end
                        return nil
                    elseif value.__type == "Instance" then
                        return nil
                    elseif value.__type == "MultiSelection" then
                        local result = {}
                        for _, item in ipairs(value.items or {}) do
                            local decoded = decodeValue(item)
                            if decoded ~= nil then result[decoded] = true end
                        end
                        return result
                    end
                    local result = {}
                    for key, item in pairs(value) do
                        result[key] = decodeValue(item)
                    end
                    return result
                end

                local decoded = decodeValue(data.value)
                if element.Multi and typeof(decoded) == "table" then
                    element:SetValue(decoded)
                elseif decoded ~= nil then
                    element:SetValue(decoded)
                end
            end
        elseif data.type == "ColorPicker" then
            assert(element.SetValueRGB, "ColorPicker option is missing SetValueRGB.")
            local color = Color3.fromHex(tostring(data.value or "ffffff"))
            element:SetValueRGB(color, tonumber(data.transparency) or 0)
        elseif data.type == "KeyPicker" then
            assert(element.SetValue, "KeyPicker option is missing SetValue.")
            element:SetValue({ data.key or "None", data.mode or element.Mode, data.modifiers or {} })
            if data.mode == "Toggle" and data.toggled ~= nil then
                element.Toggled = data.toggled == true
                assert(element.Update, "KeyPicker option is missing Update.")
                element:Update()
            end
        elseif data.type == "Input" then
            if typeof(data.text) == "string" then
                assert(element.SetValue, "Input option is missing SetValue.")
                element:SetValue(data.text)
            end
        end
    end
end

local function eachValue(value, callback)
    if typeof(value) ~= "table" then
        return
    end
    for key, item in pairs(value) do
        callback(key, item)
    end
end

local function saveGroupbox(data, tabName, index, box)
    if not box then return end
    table.insert(data.objects, {
        type = "Groupbox",
        idx = tostring(index),
        tabIdx = tostring(tabName),
        collapsed = box.Collapsed == true,
    })

    -- Tabboxes created through AddTab:AddTabbox are stored on the parent Tab,
    -- even when ParentBox points at a Groupbox. Save them from the Tab itself.
end

local function findTabbox(tab, index, parentIndex)
    if not tab then return nil end
    local target = tostring(index)

    local function scan(container)
        if not container then return nil end
        for key, tabbox in pairs(container) do
            if tostring(key) == target and tabbox and tabbox.Type == "Tabbox" then
                return tabbox
            end
            if tostring(tabbox and tabbox.Name) == target then
                return tabbox
            end
        end
        return nil
    end

    if parentIndex and tab.Groupboxes then
        local group = tab.Groupboxes[parentIndex]
        if group and group.Tabboxes then
            local found = scan(group.Tabboxes)
            if found then return found end
        end
    end
    return scan(tab.Tabboxes)
end

function SaveManager:SetLibrary(library)
    assert(library, "SaveManager:SetLibrary(Library) is required.")
    self.Library = library
end

function SaveManager:SetLoadingOrder(enabled, order)
    self.UseLoadingOrder = enabled == true
    if typeof(order) == "table" then
        self.LoadingOrder = order
    end
end

function SaveManager:SetIgnoreIndexes(indexes)
    assert(typeof(indexes) == "table", "Expected table, got " .. typeof(indexes))
    for _, index in ipairs(indexes) do
        self.Ignore[index] = true
    end
end

function SaveManager:RemoveIgnoreIndexes(indexes)
    if typeof(indexes) ~= "table" then return end
    for _, index in ipairs(indexes) do
        self.Ignore[index] = nil
    end
end

function SaveManager:IgnoreThemeSettings()
    self:SetIgnoreIndexes({
        "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", "FontFace", "BackgroundImage",
        "ThemeManager_ThemeList", "ThemeManager_CustomThemeList", "ThemeManager_CustomThemeName",
    })
end

function SaveManager:GetPaths()
    local base = self.Folder
    if empty(base) then return {} end
    local target = empty(self.SubFolder) and (base .. "/settings") or (base .. "/settings/" .. self.SubFolder)
    return splitPath(target)
end

function SaveManager:BuildFolderTree(skipWhenCreated)
    if not isfolder or not makefolder then return false end
    local paths = self:GetPaths()
    if #paths == 0 then return false end
    if skipWhenCreated then
        local allExist = true
        for _, path in ipairs(paths) do
            if not isfolder(path) then
                allExist = false
                break
            end
        end
        if allExist then return true end
    end
    for _, path in ipairs(paths) do
        if not isfolder(path) then
            local ok = pcall(makefolder, path)
            if not ok then return false end
        end
    end
    return true
end

function SaveManager:CheckFolderTree()
    return self:BuildFolderTree(true)
end

function SaveManager:CheckSubFolder(createFolder)
    if empty(self.SubFolder) then return false end
    local path = self.Folder .. "/settings/" .. self.SubFolder
    if not isfolder then return false end
    if isfolder(path) then return true end
    if not createFolder or not makefolder then return false end
    return pcall(makefolder, path)
end

function SaveManager:SetFolder(folder)
    assert(validPath(folder), "Invalid path provided")
    self.Folder = folder
    self:BuildFolderTree()
end

function SaveManager:SetSubFolder(subFolder)
    if empty(subFolder) then
        self.SubFolder = ""
        self:BuildFolderTree()
        return
    end
    assert(validPath(subFolder), "Invalid path provided")
    self.SubFolder = subFolder
    self:BuildFolderTree()
end

function SaveManager:GetCurrentSettingsPath()
    return empty(self.SubFolder) and (self.Folder .. "/settings") or (self.Folder .. "/settings/" .. self.SubFolder)
end

function SaveManager:GetConfigPath(name)
    name = trim(name)
    if not validName(name, "autoload") then return false end
    return self:GetCurrentSettingsPath() .. "/" .. name .. ".json"
end

function SaveManager:DoesConfigExist(name)
    local path = self:GetConfigPath(name)
    return path ~= false and isfile and isfile(path) or false
end

function SaveManager:RefreshConfigList()
    if not listfiles then return {} end
    self:CheckFolderTree()
    local path = self:GetCurrentSettingsPath()
    local ok, files = pcall(listfiles, path)
    if not ok or typeof(files) ~= "table" then return {} end
    local result = {}
    for _, file in ipairs(files) do
        local normalized = tostring(file):gsub("\\", "/")
        local name = normalized:match("([^/]+)%.json$")
        if name and name ~= "autoload" then
            table.insert(result, name)
        end
    end
    table.sort(result, function(a, b) return a:lower() < b:lower() end)
    return result
end

function SaveManager:Save(configName)
    configName = trim(configName)
    if not validName(configName, "autoload") then
        return false, "Invalid config name provided"
    end
    if not writefile then return false, "writefile is unavailable" end
    if not self.Library then return false, "Library is not initialized" end

    assert(self:BuildFolderTree(false), "Unable to create config folder tree.")
    local data = {
        version = 2,
        objects = {},
        keybindMenu = nil,
    }

    for index, toggle in pairs(self.Library.Toggles or {}) do
        if not self.Ignore[index] then
            local object = saveElement(index, toggle)
            if object then table.insert(data.objects, object) end
        end
    end

    for index, option in pairs(self.Library.Options or {}) do
        if not self.Ignore[index] then
            local object = saveElement(index, option)
            if object then table.insert(data.objects, object) end
        end
    end

    for tabName, tab in pairs(self.Library.Tabs or {}) do
        if typeof(tab) ~= "table" or tab.IsKeyTab then continue end

        for index, groupbox in pairs(tab.Groupboxes or {}) do
            if not self.Ignore[index] then
                saveGroupbox(data, tabName, index, groupbox)
            end
        end

        -- Obsidian stores named and unnamed Tabboxes in Tab.Tabboxes.
        for tabboxIndex, tabbox in pairs(tab.Tabboxes or {}) do
            if tabbox and tabbox.Type == "Tabbox" and tabbox.ActiveTab then
                local parentName = ""
                if tabbox.ParentBox then
                    parentName = tostring(tabbox.ParentBox.Name or "")
                end
                table.insert(data.objects, {
                    type = "Tabbox",
                    idx = tostring(tabboxIndex),
                    tabIdx = tostring(tabName),
                    parent = parentName,
                    active = tostring(tabbox.ActiveTab.Name or ""),
                })
            end
        end
    end

    if self.Library.KeybindFrame then
        data.keybindMenu = {
            visible = self.Library.KeybindFrame.Visible == true,
            position = encodeUDim2(self.Library.KeybindFrame.Position),
        }
    end

    local okEncode, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if not okEncode then return false, "Failed to encode config" end

    local path = self:GetConfigPath(configName)
    local okWrite, err = pcall(writefile, path, encoded)
    if not okWrite then
        return false, "Failed to write config file: " .. tostring(err)
    end
    return true
end

function SaveManager:Load(configName)
    configName = trim(configName)
    if not validName(configName) then return false, "Invalid config name provided" end
    if not self.Library then return false, "Library is not initialized" end
    if not readfile or not isfile then return false, "File APIs are unavailable" end

    local path = self:GetConfigPath(configName)
    if not path or not isfile(path) then return false, "Config file does not exist" end
    local okRead, raw = pcall(readfile, path)
    if not okRead then return false, "Failed to read config file" end
    local okDecode, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not okDecode or typeof(data) ~= "table" or typeof(data.objects) ~= "table" then
        return false, "Failed to decode config data"
    end

    if self.UseLoadingOrder then
        table.sort(data.objects, function(a, b)
            local ai = table.find(self.LoadingOrder, a.type) or math.huge
            local bi = table.find(self.LoadingOrder, b.type) or math.huge
            return ai < bi
        end)
    end

    local library = self.Library
    if library and library.KeybindFrame and typeof(data.keybindMenu) == "table" then
        local visible = data.keybindMenu.visible == true
        local position = decodeUDim2(data.keybindMenu.position)
        library.KeybindFrame.Visible = visible
        if position then library.KeybindFrame.Position = position end
        local menuToggle = library.Options and library.Options.KeybindMenuOpen
        if menuToggle and menuToggle.SetValue then menuToggle:SetValue(visible) end
    end

    for _, object in ipairs(data.objects) do
        if object and object.type and not self.Ignore[object.idx] then
            if object.type == "Groupbox" then
                local tab = library and library.Tabs and library.Tabs[object.tabIdx]
                local group = tab and tab.Groupboxes and tab.Groupboxes[object.idx]
                if not group and tab and tab.Groupboxes then
                    for key, candidate in pairs(tab.Groupboxes) do
                        if tostring(key) == tostring(object.idx) then
                            group = candidate
                            break
                        end
                    end
                end
                if group and group.SetCollapsed then
                    group:SetCollapsed(object.collapsed == true)
                end
            elseif object.type == "Tabbox" then
                local tab = library and library.Tabs and library.Tabs[object.tabIdx]
                local tabbox = findTabbox(tab, object.idx, object.parent)
                if tabbox and object.active and object.active ~= "" then
                    local sub = tabbox.Tabs and tabbox.Tabs[object.active]
                    if sub and sub.Show then
                        sub:Show()
                    else
                        if tabbox.Tabs then
                            for key, candidate in pairs(tabbox.Tabs) do
                                if tostring(key) == tostring(object.active) and candidate.Show then
                                    candidate:Show()
                                    break
                                end
                            end
                        end
                    end
                end
            else
                loadElement(object.idx, object)
            end
        end
    end

    if library and library.UpdateDependencyBoxes then
        library:UpdateDependencyBoxes()
    end

    return true
end

function SaveManager:Delete(configName)
    configName = trim(configName)
    if not validName(configName) then return false, "Invalid config name provided" end
    if not delfile or not isfile then return false, "File APIs are unavailable" end
    local path = self:GetConfigPath(configName)
    if not path or not isfile(path) then return false, "Config file does not exist" end
    local ok, err = pcall(delfile, path)
    if not ok then return false, "Failed to delete config file: " .. tostring(err) end
    if self.AutoloadConfig and string.lower(configName) == string.lower(self.AutoloadConfig) then self:DeleteAutoLoadConfig() end
    return true
end

function SaveManager:GetAutoloadConfig()
    self.AutoloadConfig = nil
    if not readfile or not isfile then return "none", false, "File APIs are unavailable" end
    self:CheckFolderTree()
    local path = self:GetCurrentSettingsPath() .. "/autoload.txt"
    if not isfile(path) then return "none", false, "Autoload config is not set" end
    local ok, name = pcall(readfile, path)
    if not ok or typeof(name) ~= "string" then return "none", false, "Failed to read autoload config" end
    name = trim(name)
    if name == "" or not self:DoesConfigExist(name) then return "none", false, "Config file not found" end
    self.AutoloadConfig = name
    return name, true
end

function SaveManager:SaveAutoloadConfig(configName)
    configName = trim(configName)
    if not validName(configName) then return false, "Invalid config name provided" end
    if not writefile then return false, "writefile is unavailable" end
    if not self:DoesConfigExist(configName) then return false, "Config does not exist" end
    self:CheckFolderTree()
    local path = self:GetCurrentSettingsPath() .. "/autoload.txt"
    local ok, err = pcall(writefile, path, configName)
    if not ok then return false, tostring(err) end
    self.AutoloadConfig = configName
    return true
end

function SaveManager:DeleteAutoLoadConfig()
    if not delfile or not isfile then return false, "File APIs are unavailable" end
    local path = self:GetCurrentSettingsPath() .. "/autoload.txt"
    if not isfile(path) then return false, "Autoload config is not set" end
    local ok, err = pcall(delfile, path)
    if not ok then return false, tostring(err) end
    self.AutoloadConfig = nil
    return true
end

function SaveManager:LoadAutoloadConfig()
    local name, ok, err = self:GetAutoloadConfig()
    if not ok then
        if err and err ~= "Autoload config is not set" then notify("Failed to load autoload config: " .. tostring(err)) end
        return false
    end
    local loaded, loadErr = self:Load(name)
    if not loaded then
        notify("Failed to load autoload config: " .. tostring(loadErr))
        return false
    end
    notify("Loaded autoload config " .. tostring(name))
    return true
end

local function showDialog(library, index, title, description, actionText, action)
    if library and library.Window and library.Window.AddDialog then
        return library.Window:AddDialog(index, {
            Title = title,
            Description = description,
            AutoDismiss = false,
            FooterButtons = {
                Cancel = {
                    Title = "Cancel",
                    Variant = "Ghost",
                    Order = 1,
                    Callback = function(dialog) dialog:Dismiss() end,
                },
                Action = {
                    Title = actionText,
                    Variant = "Destructive",
                    Order = 2,
                    Callback = function(dialog)
                        dialog:Dismiss()
                        action()
                    end,
                },
            },
        })
    end
    return action()
end

function SaveManager:BuildConfigSection(tab, iconName)
    assert(self.Library, "Call SaveManager:SetLibrary(Library) first.")

    local box
    if tab.AddRightGroupbox then
        box = tab:AddRightGroupbox("Configuration", iconName or "folder-cog")
    else
        box = tab:AddGroupbox({ Side = "Right", Name = "Configuration", IconName = iconName or "folder-cog" })
    end

    local nameInput = box:AddInput("SaveManager_ConfigName", {
        Text = "Config name",
        Placeholder = "e.g. Legit, Default, Test",
        ClearTextOnFocus = false,
    })

    local configList = box:AddDropdown("SaveManager_ConfigList", {
        Text = "Config list",
        Values = self:RefreshConfigList(),
        AllowNull = true,
        Multi = false,
        FormatDisplayValue = function(value)
            if value == self.AutoloadConfig then
                return tostring(value) .. " (autoload)"
            end
            return value
        end,
    })

    local autoloadLabel = box:AddLabel("Current autoload config: ...", true)

    local function refresh()
        configList:SetValues(self:RefreshConfigList())
        configList:SetValue(nil)
        local current = self:GetAutoloadConfig()
        autoloadLabel:SetText("Current autoload config: " .. tostring(current))
    end

    box:AddButton("Create config", function()
        local name = trim(nameInput.Value)
        if name == "" or string.lower(name) == "autoload" then
            notify("Enter a valid config name.")
            return
        end
        local function save()
            local ok, err = self:Save(name)
            notify(ok and ("Saved config " .. name) or ("Failed: " .. tostring(err)))
            if ok then refresh() end
        end
        if self:DoesConfigExist(name) then
            showDialog(self.Library, "SaveManager_CreateConfig", "Overwrite config", "A config with this name already exists.", "Overwrite", save)
        else
            save()
        end
    end)

    box:AddButton("Load config", function()
        local name = configList.Value
        if empty(name) then notify("Select a config first.") return end
        local ok, err = self:Load(name)
        notify(ok and ("Loaded config " .. tostring(name)) or ("Failed: " .. tostring(err)))
    end)

    box:AddButton("Overwrite selected", function()
        local name = configList.Value
        if empty(name) then notify("Select a config first.") return end
        showDialog(self.Library, "SaveManager_OverwriteConfig", "Overwrite config", "Replace the selected config with the current state?", "Overwrite", function()
            local ok, err = self:Save(name)
            notify(ok and ("Overwrote config " .. tostring(name)) or ("Failed: " .. tostring(err)))
            refresh()
        end)
    end)

    box:AddButton("Delete selected", function()
        local name = configList.Value
        if empty(name) then notify("Select a config first.") return end
        showDialog(self.Library, "SaveManager_DeleteConfig", "Delete config", "Delete " .. tostring(name) .. " permanently?", "Delete", function()
            local ok, err = self:Delete(name)
            notify(ok and ("Deleted config " .. tostring(name)) or ("Failed: " .. tostring(err)))
            refresh()
        end)
    end)

    box:AddButton("Refresh config list", refresh)
    box:AddDivider()

    box:AddButton("Set selected as autoload", function()
        local name = configList.Value
        if empty(name) then notify("Select a config first.") return end
        local ok, err = self:SaveAutoloadConfig(name)
        notify(ok and ("Autoload set to " .. tostring(name)) or ("Failed: " .. tostring(err)))
        refresh()
    end)

    box:AddButton("Reset autoload", function()
        local ok, err = self:DeleteAutoLoadConfig()
        notify(ok and "Autoload reset." or ("Failed: " .. tostring(err)))
        refresh()
    end)

    self:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName" })
    local current = self:GetAutoloadConfig()
    autoloadLabel:SetText("Current autoload config: " .. tostring(current))
    return box
end

SaveManager:BuildFolderTree()
getgenv().ObsidianSaveManager = SaveManager
return SaveManager
