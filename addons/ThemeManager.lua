local cloneref = cloneref or clonereference or function(instance)
    return instance
end

local clonefunction = clonefunction or copyfunction or function(func)
    return func
end

local HttpService = cloneref(game:GetService("HttpService"))
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

local ThemeManager = {
    Library = nil,
    Folder = "ObsidianLibSettings",
    AppliedToTab = false,
    DefaultThemeName = nil,
    BuiltInThemes = {
        Default = { 1, { FontColor = "ffffff", MainColor = "191919", AccentColor = "8d8d8d", BackgroundColor = "0f0f0f", OutlineColor = "242424", BackgroundImage = "" } },
        NOIR = { 2, { FontColor = "f3f3f3", MainColor = "1b1b1b", AccentColor = "bdbdbd", BackgroundColor = "0d0d0d", OutlineColor = "242424", BackgroundImage = "" } },
        Graphite = { 3, { FontColor = "eeeeee", MainColor = "242424", AccentColor = "9a9a9a", BackgroundColor = "141414", OutlineColor = "2d2d2d", BackgroundImage = "" } },
        Silver = { 4, { FontColor = "f4f4f4", MainColor = "2a2a2a", AccentColor = "d0d0d0", BackgroundColor = "171717", OutlineColor = "353535", BackgroundImage = "" } },
        BBot = { 5, { FontColor = "ffffff", MainColor = "1e1e1e", AccentColor = "7e48a3", BackgroundColor = "232323", OutlineColor = "141414", BackgroundImage = "" } },
        Fatality = { 6, { FontColor = "ffffff", MainColor = "1e1842", AccentColor = "c50754", BackgroundColor = "191335", OutlineColor = "3c355d", BackgroundImage = "" } },
        Jester = { 7, { FontColor = "ffffff", MainColor = "242424", AccentColor = "db4467", BackgroundColor = "1c1c1c", OutlineColor = "373737", BackgroundImage = "" } },
        Mint = { 8, { FontColor = "ffffff", MainColor = "242424", AccentColor = "3db488", BackgroundColor = "1c1c1c", OutlineColor = "373737", BackgroundImage = "" } },
        ["Tokyo Night"] = { 9, { FontColor = "ffffff", MainColor = "191925", AccentColor = "6759b3", BackgroundColor = "16161f", OutlineColor = "323232", BackgroundImage = "" } },
        Ubuntu = { 10, { FontColor = "ffffff", MainColor = "3e3e3e", AccentColor = "e2581e", BackgroundColor = "323232", OutlineColor = "191919", BackgroundImage = "" } },
        Quartz = { 11, { FontColor = "ffffff", MainColor = "232330", AccentColor = "426e87", BackgroundColor = "1d1b26", OutlineColor = "27232f", BackgroundImage = "" } },
        Nord = { 12, { FontColor = "eceff4", MainColor = "3b4252", AccentColor = "88c0d0", BackgroundColor = "2e3440", OutlineColor = "4c566a", BackgroundImage = "" } },
        Dracula = { 13, { FontColor = "f8f8f2", MainColor = "44475a", AccentColor = "ff79c6", BackgroundColor = "282a36", OutlineColor = "6272a4", BackgroundImage = "" } },
        Monokai = { 14, { FontColor = "f8f8f2", MainColor = "272822", AccentColor = "f92672", BackgroundColor = "1e1f1c", OutlineColor = "49483e", BackgroundImage = "" } },
        Gruvbox = { 15, { FontColor = "ebdbb2", MainColor = "3c3836", AccentColor = "fb4934", BackgroundColor = "282828", OutlineColor = "504945", BackgroundImage = "" } },
        Solarized = { 16, { FontColor = "839496", MainColor = "073642", AccentColor = "cb4b16", BackgroundColor = "002b36", OutlineColor = "586e75", BackgroundImage = "" } },
        Catppuccin = { 17, { FontColor = "d9e0ee", MainColor = "302d41", AccentColor = "f5c2e7", BackgroundColor = "1e1e2e", OutlineColor = "575268", BackgroundImage = "" } },
        ["One Dark"] = { 18, { FontColor = "abb2bf", MainColor = "282c34", AccentColor = "c678dd", BackgroundColor = "21252b", OutlineColor = "5c6370", BackgroundImage = "" } },
    }
}

local SchemeIndexes = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor" }

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
    if ThemeManager.Library and ThemeManager.Library.Notify then
        ThemeManager.Library:Notify(message)
    end
end

local function colorToHex(value, fallback)
    if typeof(value) == "Color3" then
        return value:ToHex()
    end
    if typeof(value) == "string" and value ~= "" then
        local result = Color3.fromHex(value)
        return result:ToHex()
    end
    return fallback
end

local function applyFont(library, name)
    if typeof(name) ~= "string" then
        return
    end
    local font = Enum.Font[name]
    assert(font, "Invalid font face: " .. tostring(name))
    assert(library.SetFont or library.Scheme, "Library cannot apply a font.")
    if library.SetFont then
        library:SetFont(font)
    else
        library.Scheme.Font = Font.fromEnum(font)
        if library.UpdateColorsUsingRegistry then
            library:UpdateColorsUsingRegistry()
        end
    end
end

local function applyBackground(library, image)
    if typeof(image) ~= "string" and typeof(image) ~= "number" then
        return
    end
    assert(library.SetBackgroundImage or library.Scheme, "Library cannot apply a background image.")
    if library.SetBackgroundImage then
        library:SetBackgroundImage(image)
    else
        library.Scheme.BackgroundImage = image
        if library.UpdateColorsUsingRegistry then
            library:UpdateColorsUsingRegistry()
        end
    end
end

function ThemeManager:SetLibrary(library)
    assert(library, "ThemeManager:SetLibrary(Library) is required.")
    self.Library = library
end

function ThemeManager:GetPaths()
    if empty(self.Folder) then
        return {}
    end
    return splitPath(self.Folder .. "/themes")
end

function ThemeManager:BuildFolderTree(skipWhenCreated)
    if not isfolder or not makefolder then
        return false
    end

    local paths = self:GetPaths()
    if #paths == 0 then
        return false
    end

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
            if not ok then
                return false
            end
        end
    end
    return true
end

function ThemeManager:CheckFolderTree()
    return self:BuildFolderTree(true)
end

function ThemeManager:SetFolder(folder)
    assert(validPath(folder), "Invalid path provided")
    self.Folder = folder
    self:BuildFolderTree()
end

function ThemeManager:_themesPath()
    if empty(self.Folder) then
        return false
    end
    return self.Folder .. "/themes"
end

function ThemeManager:_themePath(name)
    name = trim(name)
    if not validName(name, "default") then return false end
    local path = self:_themesPath()
    if not path then
        return false
    end
    return path .. "/" .. name .. ".json"
end

function ThemeManager:_defaultPath()
    local path = self:_themesPath()
    return path and path .. "/default.txt" or false
end

function ThemeManager:GetCustomTheme(name)
    if empty(name) or not isfile or not readfile then
        return nil
    end
    local path = self:_themePath(name)
    if not path or not isfile(path) then
        return nil
    end
    local okRead, raw = pcall(readfile, path)
    if not okRead then
        return nil
    end
    local okDecode, data = pcall(HttpService.JSONDecode, HttpService, raw)
    return okDecode and typeof(data) == "table" and data or nil
end

function ThemeManager:ReloadCustomThemes()
    if not listfiles or not self:_themesPath() then
        return {}
    end
    self:CheckFolderTree()
    local ok, files = pcall(listfiles, self:_themesPath())
    if not ok or typeof(files) ~= "table" then
        return {}
    end
    local names = {}
    for _, file in ipairs(files) do
        local normalized = tostring(file):gsub("\\", "/")
        local stem = normalized:match("([^/]+)%.json$")
        if stem and stem:lower() ~= "default" then
            table.insert(names, stem)
        end
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

function ThemeManager:SaveCustomTheme(name)
    name = trim(name)
    if not validName(name, "default") then
        return false, "Invalid theme name provided"
    end
    if not writefile then
        return false, "writefile is unavailable"
    end

    assert(self:BuildFolderTree(false), "Unable to create theme folder tree.")
    local library = self.Library
    if not library or not library.Options then
        return false, "Library is not initialized"
    end

    local data = {
        FontFace = library.Options.FontFace and library.Options.FontFace.Value or "Code",
        BackgroundImage = library.Options.BackgroundImage and library.Options.BackgroundImage.Value or "",
    }

    for _, index in ipairs(SchemeIndexes) do
        local option = library.Options[index]
        if option and typeof(option.Value) == "Color3" then
            data[index] = option.Value:ToHex()
        elseif library.Scheme and typeof(library.Scheme[index]) == "Color3" then
            data[index] = library.Scheme[index]:ToHex()
        end
    end

    local okEncode, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if not okEncode then
        return false, "Failed to encode theme"
    end

    local okWrite, err = pcall(writefile, self:_themePath(name), encoded)
    if not okWrite then
        return false, "Failed to write theme file: " .. tostring(err)
    end
    return true
end

function ThemeManager:Delete(name)
    name = trim(name)
    if not validName(name) then
        return false, "No theme is selected"
    end
    if not isfile or not delfile then
        return false, "File APIs are unavailable"
    end
    local path = self:_themePath(name)
    if not path or not isfile(path) then
        return false, "Theme file does not exist"
    end
    local ok, err = pcall(delfile, path)
    if not ok then
        return false, "Failed to delete theme file: " .. tostring(err)
    end
    if self.DefaultThemeName and string.lower(name) == string.lower(self.DefaultThemeName) then
        self:DeleteDefaultTheme()
    end
    return true
end

function ThemeManager:GetDefaultTheme()
    self.DefaultThemeName = nil
    if not readfile or not isfile then
        return "none", false, "File APIs are unavailable"
    end
    self:CheckFolderTree()
    local path = self:_defaultPath()
    if not path then
        return "none", false, "Invalid path provided"
    end
    if not isfile(path) then
        return "none", false, "Default theme is not set"
    end
    local ok, name = pcall(readfile, path)
    if not ok or typeof(name) ~= "string" then
        return "none", false, "Failed to read default theme"
    end
    name = trim(name)
    if name == "" then
        return "none", false, "Default theme is empty"
    end
    if not self.BuiltInThemes[name] and not self:GetCustomTheme(name) then
        return "none", false, "Theme file not found"
    end
    self.DefaultThemeName = name
    return name, true
end

function ThemeManager:SetDefaultTheme(theme)
    assert(self.Library, "Call ThemeManager:SetLibrary(Library) first.")
    assert(not self.AppliedToTab, "SetDefaultTheme must be called before ApplyToTab.")

    local library = self.Library
    local defaults = self.BuiltInThemes.Default[2]
    local final = {}
    local scheme = {}

    for _, index in ipairs(SchemeIndexes) do
        local value = theme and theme[index]
        local hex = colorToHex(value, defaults[index])
        scheme[index] = Color3.fromHex(hex)
        final[index] = hex
    end

    local fontName = "Code"
    if theme and typeof(theme.FontFace) == "EnumItem" then
        fontName = theme.FontFace.Name
    elseif theme and typeof(theme.FontFace) == "string" and Enum.Font[theme.FontFace] then
        fontName = theme.FontFace
    end
    final.FontFace = fontName
    final.BackgroundImage = theme and (theme.BackgroundImage or "") or ""

    scheme.Font = Font.fromEnum(Enum.Font[fontName] or Enum.Font.Code)
    if library.Scheme then
        for _, key in ipairs({ "RedColor", "DestructiveColor", "DarkColor", "WhiteColor" }) do
            scheme[key] = library.Scheme[key]
        end
    end

    self.BuiltInThemes.Default = { 1, final }
    if library.Scheme then
        library.Scheme = scheme
        if library.UpdateColorsUsingRegistry then
            library:UpdateColorsUsingRegistry()
        end
    end
end

function ThemeManager:SaveDefault(name)
    name = trim(name)
    if not validName(name) then
        return false, "No theme is selected"
    end
    if not writefile then
        return false, "writefile is unavailable"
    end
    local exists = self.BuiltInThemes[name] ~= nil or self:GetCustomTheme(name) ~= nil
    if not exists then
        return false, "Theme does not exist"
    end
    self:CheckFolderTree()
    local ok, err = pcall(writefile, self:_defaultPath(), name)
    if not ok then
        return false, tostring(err)
    end
    self.DefaultThemeName = name
    return true
end

function ThemeManager:DeleteDefaultTheme()
    if not isfile or not delfile then
        return false, "File APIs are unavailable"
    end
    local path = self:_defaultPath()
    if not path or not isfile(path) then
        return false, "Default theme is not set"
    end
    local ok, err = pcall(delfile, path)
    if not ok then
        return false, tostring(err)
    end
    self.DefaultThemeName = nil
    return true
end

function ThemeManager:ThemeUpdate()
    local library = self.Library
    if not library then
        return
    end
    for _, index in ipairs(SchemeIndexes) do
        local option = library.Options and library.Options[index]
        if option and typeof(option.Value) == "Color3" then
            library.Scheme[index] = option.Value
        end
    end
    if library.UpdateColorsUsingRegistry then
        library:UpdateColorsUsingRegistry()
    end
end

function ThemeManager:ApplyTheme(name)
    if empty(name) then
        return false, "No theme is selected"
    end
    local custom = self:GetCustomTheme(name)
    local entry = custom or self.BuiltInThemes[name]
    if not entry then
        return false, "Theme not found"
    end

    local data = custom or entry[2]
    local library = self.Library
    if not library then
        return false, "Library is not initialized"
    end

    for index, value in pairs(data) do
        if index == "VideoLink" then
            continue
        end
        if index == "FontFace" then
            applyFont(library, tostring(value))
            if library.Options and library.Options.FontFace then
                library.Options.FontFace:SetValue(tostring(value))
            end
        elseif index == "BackgroundImage" then
            applyBackground(library, value or "")
            if library.Options and library.Options.BackgroundImage then
                library.Options.BackgroundImage:SetValue(value or "")
            end
        elseif library.Scheme and table.find(SchemeIndexes, index) then
            assert(typeof(value) == "string", "Theme color values must be hexadecimal strings.")
            local color = Color3.fromHex(value)
            library.Scheme[index] = color
            if library.Options and library.Options[index] then
                library.Options[index]:SetValue(color)
            end
        end
    end

    self:ThemeUpdate()
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

function ThemeManager:CreateThemeManager(groupbox)
    assert(self.Library, "Call ThemeManager:SetLibrary(Library) first.")

    local library = self.Library
    local builtInNames = {}
    for name, entry in pairs(self.BuiltInThemes) do
        table.insert(builtInNames, { Name = name, Order = entry[1] })
    end
    table.sort(builtInNames, function(a, b) return a.Order < b.Order end)
    local names = {}
    for _, item in ipairs(builtInNames) do table.insert(names, item.Name) end

    local function colorOption(label, index)
        local holder = groupbox:AddLabel(label)
        holder:AddColorPicker(index, {
            Default = (library.Scheme and library.Scheme[index]) or Color3.new(1, 1, 1),
        })
        return library.Options[index]
    end

    local BackgroundColor = colorOption("Background color", "BackgroundColor")
    local MainColor = colorOption("Main color", "MainColor")
    local AccentColor = colorOption("Accent color", "AccentColor")
    local OutlineColor = colorOption("Outline color", "OutlineColor")
    local FontColor = colorOption("Font color", "FontColor")

    local FontFace = groupbox:AddDropdown("FontFace", {
        Text = "Font face",
        Values = { "BuilderSans", "Code", "Fantasy", "Gotham", "Jura", "Roboto", "RobotoMono", "SourceSans" },
        Default = "Code",
        AllowNull = false,
    })

    local BackgroundImage = groupbox:AddInput("BackgroundImage", {
        Text = "Background image",
        Default = "",
        Finished = true,
        ClearTextOnFocus = false,
        ClearTextOnBlur = false,
        Placeholder = "optional rbxasset / image id",
    })

    groupbox:AddDivider()

    local ThemeList = groupbox:AddDropdown("ThemeManager_ThemeList", {
        Text = "Built-in themes",
        Values = names,
        AllowNull = true,
        Multi = false,
        FormatDisplayValue = function(value)
            if value ~= "Default" and value == self.DefaultThemeName then
                return tostring(value) .. " (default)"
            end
            return value
        end,
        FormatListValue = function(value)
            if value ~= "Default" and value == self.DefaultThemeName then
                return tostring(value) .. " (default)"
            end
            return value
        end,
    })

    local refreshDefaultLabel

    groupbox:AddButton("Apply built-in theme", function()
        if empty(ThemeList.Value) then
            notify("Select a built-in theme first.")
            return
        end
        local ok, err = self:ApplyTheme(ThemeList.Value)
        notify(ok and ("Applied theme " .. tostring(ThemeList.Value)) or ("Failed to apply theme: " .. tostring(err)))
    end)

    groupbox:AddButton("Set built-in as default", function()
        if empty(ThemeList.Value) then
            notify("Select a built-in theme first.")
            return
        end
        local ok, err = self:SaveDefault(ThemeList.Value)
        notify(ok and ("Default theme set to " .. tostring(ThemeList.Value)) or ("Failed: " .. tostring(err)))
        if ok and refreshDefaultLabel then
            refreshDefaultLabel()
        end
    end)

    groupbox:AddDivider()

    local CustomThemeName = groupbox:AddInput("ThemeManager_CustomThemeName", {
        Text = "Custom theme name",
        Placeholder = "e.g. MyTheme",
    })

    local CustomThemeList = groupbox:AddDropdown("ThemeManager_CustomThemeList", {
        Text = "Custom themes",
        Values = self:ReloadCustomThemes(),
        AllowNull = true,
        Multi = false,
        FormatDisplayValue = function(value)
            if value == self.DefaultThemeName then
                return tostring(value) .. " (default)"
            end
            return value
        end,
        FormatListValue = function(value)
            if value == self.DefaultThemeName then
                return tostring(value) .. " (default)"
            end
            return value
        end,
    })

    local function refresh()
        CustomThemeList:SetValues(self:ReloadCustomThemes())
        CustomThemeList:SetValue(nil)
        ThemeList:SetValues(names)
    end

    groupbox:AddButton("Create / overwrite custom", function()
        local name = trim(CustomThemeName.Value)
        if name == "" or string.lower(name) == "default" then
            notify("Enter a valid custom theme name.")
            return
        end
        local exists = self:GetCustomTheme(name) ~= nil
        local function save()
            local ok, err = self:SaveCustomTheme(name)
            notify(ok and ("Saved theme " .. name) or ("Failed: " .. tostring(err)))
            if ok then refresh() end
        end
        if exists then
            showDialog(library, "ThemeManager_OverwriteTheme", "Overwrite theme", "A custom theme with this name already exists.", "Overwrite", save)
        else
            save()
        end
    end)

    groupbox:AddButton("Load custom", function()
        local name = CustomThemeList.Value
        if empty(name) then
            notify("Select a custom theme first.")
            return
        end
        local ok, err = self:ApplyTheme(name)
        notify(ok and ("Loaded theme " .. tostring(name)) or ("Failed: " .. tostring(err)))
    end)

    groupbox:AddButton("Delete custom", function()
        local name = CustomThemeList.Value
        if empty(name) then
            notify("Select a custom theme first.")
            return
        end
        showDialog(library, "ThemeManager_DeleteTheme", "Delete theme", "Delete " .. tostring(name) .. " permanently?", "Delete", function()
            local ok, err = self:Delete(name)
            notify(ok and ("Deleted theme " .. tostring(name)) or ("Failed: " .. tostring(err)))
            refresh()
        end)
    end)

    groupbox:AddButton("Refresh theme list", refresh)
    local DefaultLabel = groupbox:AddLabel("Current default theme: ...", true)
    refreshDefaultLabel = function()
        local name = self:GetDefaultTheme()
        DefaultLabel:SetText("Current default theme: " .. tostring(name))
    end

    groupbox:AddButton("Reset default theme", function()
        local ok, err = self:DeleteDefaultTheme()
        notify(ok and "Default theme reset." or ("Failed: " .. tostring(err)))
        if ok then
            refreshDefaultLabel()
        end
    end)

    BackgroundColor:OnChanged(function() self:ThemeUpdate() end)
    MainColor:OnChanged(function() self:ThemeUpdate() end)
    AccentColor:OnChanged(function() self:ThemeUpdate() end)
    OutlineColor:OnChanged(function() self:ThemeUpdate() end)
    FontColor:OnChanged(function() self:ThemeUpdate() end)
    FontFace:OnChanged(function(value) applyFont(library, value) end)
    BackgroundImage:OnChanged(function(value) applyBackground(library, value) end)

    ThemeList:OnChanged(function(value)
        if not empty(value) then
            self:ApplyTheme(value)
        end
    end)

    self:LoadDefault()
    self.AppliedToTab = true
    refreshDefaultLabel()
    return groupbox
end

function ThemeManager:LoadDefault()
    local name, ok, err = self:GetDefaultTheme()
    if not ok then
        if err and err ~= "Default theme is not set" then
            notify("Failed to load default theme: " .. tostring(err))
        end
        return false
    end
    local applied, applyErr = self:ApplyTheme(name)
    if not applied then
        notify("Failed to apply default theme: " .. tostring(applyErr))
        return false
    end
    return true
end

function ThemeManager:CreateGroupBox(tab, iconName)
    if tab.AddLeftGroupbox then
        return tab:AddLeftGroupbox("Themes", iconName or "paintbrush")
    end
    return tab:AddGroupbox({ Side = "Left", Name = "Themes", IconName = iconName or "paintbrush" })
end

function ThemeManager:ApplyToTab(tab, iconName)
    local box = self:CreateGroupBox(tab, iconName)
    return self:CreateThemeManager(box)
end

function ThemeManager:ApplyToGroupbox(groupbox)
    return self:CreateThemeManager(groupbox)
end

getgenv().ObsidianThemeManager = ThemeManager
return ThemeManager
