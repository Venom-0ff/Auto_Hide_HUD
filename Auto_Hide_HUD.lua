--- Auto-Hide HUD App
--- Author: Venom
--- Version: 1.1
--- Changelog:
--- v1.1: Implemented auto-hiding of apps when there're no mouse movement or D-Pad inouts for x continuos seconds, fixed 'remove' button restoring apps on the wrong desktops.
--- v1.02: Fixed auto-hide all apps option not working with apps that are also set up in custom rules in certain conditions.
--- v1.01: Fixed incorrect behaviour when switching from dash camera to other cameras.

local SIM = ac.getSim()
local UI = ac.getUI()
local DESKTOPS = { "1", "2", "3", "4", "All" }
local HIDE_CONDITIONS = { "Off", "In interior views", "In exterior views" }

local MANIFEST = ac.INIConfig.load("manifest.ini")
local CONFIG_PATH = ac.getFolder(ac.FolderID.ACApps) .. "/lua/Auto_Hide_HUD/rules.ini"
local config = ac.INIConfig.load(CONFIG_PATH)


local listOfRules = {}     --- Contains the custom rules created by the user
local visibleAppIDs = {}   --- Contains the IDs of every currently visible app window
local visibleAppNames = {} --- Contains human-friedly names of every currently visible app window

local rulesInit = false    --- Flag to know if rules were loaded from config
local hideAllInt = false
local hideAllExt = false
local hideAllApps = config:get("GENERAL", "hideAllApps", 1)
local isHideOnTimeOut = config:get("GENERAL", "isHideOnTimeOut", false) --- Time-out enabled flag
local isHideOnTimeOutCheckbox = refbool(isHideOnTimeOut)                --- For auto-hide on time-out checkbox
local hideTimer = 0                                                     --- Time-out time counter
local hideTimeOut = config:get("GENERAL", "hideTimeOut", 1)             --- Time-out value set by user
local isHUDHidden = false

local previousCamera = nil         --- Used for tracking camera changes
local previousDesktop = nil        --- Used for tracking desktop changes
local previousDrivableCamera = nil --- Used for tracking camera changes

--- Updates the lists of apps that are currently visible on the HUD
local function updateVisibleApps()
    visibleAppIDs = {}
    visibleAppNames = {}
    for _, app in ipairs(ac.getAppWindows()) do
        if app.visible then
            table.insert(visibleAppIDs, app.name)
            if app.title ~= nil and app.title ~= "" then
                table.insert(visibleAppNames, app.title)
            else
                table.insert(visibleAppNames, app.name)
            end
        end
    end
end

--- Populates listOfRules with values from the saved config
local function initRules()
    hideAllApps = config:get("GENERAL", "hideAllApps", 1)
    isHideOnTimeOut = config:get("GENERAL", "isHideOnTimeOut", false)
    isHideOnTimeOutCheckbox = refbool(isHideOnTimeOut)
    hideTimeOut = config:get("GENERAL", "hideTimeOut", 0)

    for i = 1, config:get("GENERAL", "count", 0) do
        table.insert(listOfRules, {
            appID = config:get("RULE_" .. i, "appID", ""),
            appName = config:get("RULE_" .. i, "appName", ""),
            condition = config:get("RULE_" .. i, "condition", 1),
            desktop = config:get("RULE_" .. i, "desktop", 5),
            saved = config:get("RULE_" .. i, "saved", false),
        })

        updateVisibleApps()
    end
    rulesInit = true
end

--- Checks current view
--- @return boolean @Returns true if current camera is an interior view
local function isInteriorView()
    return SIM.cameraMode == ac.CameraMode.Cockpit or
        SIM.cameraMode == ac.CameraMode.Drivable and SIM.driveableCameraMode == ac.DrivableCamera.Dash
end

--- Hides and shows apps as per created rules
local function applyRules()
    isHideOnTimeOut = isHideOnTimeOutCheckbox.value
    -- Apply "hide all" rule
    if hideAllApps ~= 1 then
        if isInteriorView() then
            ac.setAppsHidden(hideAllInt)
        else
            ac.setAppsHidden(hideAllExt)
        end
    else
        ac.setAppsHidden(false)
        -- Iterate through custom rules and apply them if necessary
        for _, rule in ipairs(listOfRules) do
            if rule.condition ~= 1 then
                if rule.desktop == UI.currentDesktop + 1 or rule.desktop == 5 then -- if correct desktop
                    if rule.condition == 2 then                                    -- hide in interior
                        ac.accessAppWindow(rule.appID):setVisible(not isInteriorView())
                    elseif rule.condition == 3 then                                -- hide in exterior
                        ac.accessAppWindow(rule.appID):setVisible(isInteriorView())
                    end
                elseif rule.appID ~= nil and rule.appID ~= "" then -- restore app window on other desktops
                    ac.accessAppWindow(rule.appID):setVisible(ac.accessAppWindow(rule.appID):visible())
                end
            end
        end
    end
end

--- Renders the Rules tab and its contents
local function rules()
    hideAllApps = ui.combo("Hide all apps:", hideAllApps, HIDE_CONDITIONS)
    if ui.itemHovered() then ui.setTooltip("Auto-hide all apps in interior or exterior view") end

    if hideAllApps == 1 then -- off
        hideAllInt = false
        hideAllExt = false
    elseif hideAllApps == 2 then -- hide in interior
        hideAllInt = true
        hideAllExt = false
    elseif hideAllApps == 3 then -- hide in exterior
        hideAllInt = false
        hideAllExt = true
    end

    ui.sameLine()
    ui.checkbox("Auto-Hide all apps on idle?", isHideOnTimeOutCheckbox)
    if ui.itemHovered() then
        ui.setTooltip(
        "Auto-hide all apps if there's no mouse movement and no inputs on D-Pad for x continuos seconds\nNOTE: This option doesn't take into account camera-based hiding")
    end
    if isHideOnTimeOutCheckbox.value then
        ui.sameLine()
        hideTimeOut = ui.slider("##timeOut", hideTimeOut, 1, 6, 'Time-Out, sec: %0.1f')
        if ui.itemHovered() then ui.setTooltip("Amount of seconds to wait before hiding all apps") end
    end

    ui.separator()
    ui.text("Custom Rules")
    ui.separator()
    for i, rule in ipairs(listOfRules) do
        ui.labelText("", "App:")
        ui.sameLine(60)
        if rule.saved then -- for saved rules
            ui.setNextTextBold()
            ui.labelText("", rule.appName)
        else -- for newly added, unsaved rules
            updateVisibleApps()
            listOfRules[i].index = ui.combo("##Rule" .. i, rule.index, visibleAppNames)
            if ui.itemHovered() then ui.setTooltip("Choose an app window to auto-hide") end
            listOfRules[i].appID = visibleAppIDs[listOfRules[i].index]
            listOfRules[i].appName = visibleAppNames[listOfRules[i].index]
        end
        ui.sameLine()

        ui.text("Hide:")
        ui.sameLine()
        listOfRules[i].condition = ui.combo("##Condition" .. i, rule.condition, HIDE_CONDITIONS)
        if ui.itemHovered() then ui.setTooltip("Choose when you want to hide this app") end
        ui.sameLine()

        ui.text("On desktop:")
        ui.sameLine()
        listOfRules[i].desktop = ui.combo("##Desktop" .. i, rule.desktop, DESKTOPS)
        if ui.itemHovered() then ui.setTooltip("Choose on which desktop you want to hide this app") end
        ui.sameLine()

        if ui.modernButton("##Remove" .. i, vec2(22, 22), ui.ButtonFlags.Cancel, ui.Icons.Delete) then
            if rule.appID ~= nil and rule.appID ~= "" and (rule.desktop == UI.currentDesktop + 1 or rule.desktop == 5)then
                ac.accessAppWindow(rule.appID):setVisible(true)
            end

            -- Shift remaining rules to fill the gap after deleting one of the rules
            for j = i, #listOfRules, 1 do
                config:set("RULE_" .. j, "appID", config:get("RULE_" .. j + 1, "appID", nil))
                config:set("RULE_" .. j, "appName", config:get("RULE_" .. j + 1, "appName", nil))
                config:set("RULE_" .. j, "condition", config:get("RULE_" .. j + 1, "condition", nil))
                config:set("RULE_" .. j, "desktop", config:get("RULE_" .. j + 1, "desktop", nil))
                config:set("RULE_" .. j, "saved", config:get("RULE_" .. j + 1, "saved", nil))
            end

            table.remove(listOfRules, i)
        end
        if ui.itemHovered() then ui.setTooltip("Remove this rule") end
    end

    if #listOfRules > 0 then ui.separator() end

    if ui.modernButton("New Rule", vec2(112, 30), ui.ButtonFlags.None, ui.Icons.Plus) then
        table.insert(listOfRules, { index = 1, appID = "", appName = "", condition = 1, desktop = 5, saved = false })
    end

    ui.sameLine()

    if ui.modernButton("Reset", vec2(100, 30), ui.ButtonFlags.None, ui.Icons.Reset) then
        config = ac.INIConfig.load(CONFIG_PATH)
        listOfRules = {}
        initRules()
        applyRules()
    end
    if ui.itemHovered() then ui.setTooltip("Reset rules to the last saved state") end

    ui.sameLine()

    if ui.modernButton("Save", vec2(85, 30), ui.ButtonFlags.Confirm, ui.Icons.Save) then
        applyRules()
        config:set("GENERAL", "hideAllApps", hideAllApps)
        config:set("GENERAL", "isHideOnTimeOut", isHideOnTimeOut)
        config:set("GENERAL", "hideTimeOut", hideTimeOut)

        config:set("GENERAL", "count", #listOfRules)
        for i, rule in ipairs(listOfRules) do
            config:set("RULE_" .. i, "appID", rule.appID)
            config:set("RULE_" .. i, "appName", rule.appName)
            config:set("RULE_" .. i, "condition", rule.condition)
            config:set("RULE_" .. i, "desktop", rule.desktop)
            config:set("RULE_" .. i, "saved", true)
        end

        config:save(CONFIG_PATH)
        ui.toast(ui.Icons.Confirm, "Saved!")

        listOfRules = {}
        initRules()
    end
end

--- Renders the about tab and its contents
local function about()
    ui.columns(2)
    ui.setColumnWidth(0, 114)
    ui.text("App:")
    ui.text("Description:")
    ui.text("Author:")
    ui.text("Version:")
    ui.text("Github repo:")

    ui.nextColumn()
    ui.text(MANIFEST:get("ABOUT", "NAME", ""))
    ui.text(MANIFEST:get("ABOUT", "DESCRIPTION", ""))
    ui.text(MANIFEST:get("ABOUT", "AUTHOR", ""))
    ui.text(MANIFEST:get("ABOUT", "VERSION", ""))
    ui.textHyperlink(MANIFEST:get("ABOUT", "URL", ""))
end

--- Hides HUD after hideTimeOut seconds if mouse is not moved or D-Pad is not pressed
--- @param dt number @Time passed since last `update()` call, in seconds.
local function timeOut(dt)
    if math.abs(ui.mouseDelta().x + ui.mouseDelta().y) > 2.2 or
        ac.isGamepadButtonPressed(0, ac.GamepadButton.DPadUp) or
        ac.isGamepadButtonPressed(0, ac.GamepadButton.DPadDown) or
        ac.isGamepadButtonPressed(0, ac.GamepadButton.DPadLeft) or
        ac.isGamepadButtonPressed(0, ac.GamepadButton.DPadRight) or
        ac.isJoystickButtonPressed(0, ac.KeyIndex.GamepadDpadUp) or
        ac.isJoystickButtonPressed(0, ac.KeyIndex.GamepadDpadDown) or
        ac.isJoystickButtonPressed(0, ac.KeyIndex.GamepadDpadLeft) or
        ac.isJoystickButtonPressed(0, ac.KeyIndex.GamepadDpadRight)
    then
        hideTimer = 0
        if isHUDHidden then
            ac.setAppsHidden(false)
            isHUDHidden = false
        end
    end

    if hideTimer < hideTimeOut then hideTimer = hideTimer + dt end

    if not isHUDHidden and hideTimeOut > 0 and hideTimer >= hideTimeOut then
        ac.setAppsHidden(true)
        isHUDHidden = true
    end
end

--- Renders the main window of the app
--- @param dt number @Time passed since last `update()` call, in seconds.
function script.windowMain(dt)
    ui.icon("icon.png", vec2(15, 15))
    ui.sameLine()
    ui.setNextTextBold()
    ui.text(MANIFEST:get("ABOUT", "NAME", ""))
    ui.tabBar("main", function()
        ui.tabItem("Rules", rules)
        ui.tabItem("About", about)
    end)
end

function script.update(dt)
    -- load rules on session start
    if not rulesInit then initRules() end

    -- Auto-hide after time-out
    if isHideOnTimeOut then
        timeOut(dt)
    end

    -- Detect camera changes
    if previousCamera ~= SIM.cameraMode or previousDrivableCamera ~= SIM.driveableCameraMode then
        applyRules()
    end
    previousCamera = SIM.cameraMode
    previousDrivableCamera = SIM.driveableCameraMode

    -- Detect desktop changes
    if previousDesktop ~= UI.currentDesktop then
        applyRules()
    end
    previousDesktop = UI.currentDesktop
end
