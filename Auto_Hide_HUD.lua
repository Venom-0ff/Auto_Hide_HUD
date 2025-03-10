--- Auto-Hide HUD App
--- Author: Venom
--- Version: 1.34
--- Changelog:
--- v1.34: Added compatibility wiith the new "Apps in pause menu" feature from CSP 0.2.7/0.2.8p1 to hopefully prevent any issues it may cause. Fixed an issue where dualsense (and potentially dualshock?) D-Pads were not recognised.
--- v1.33: Fixed the desktop selection not affecting apps that are set to auto-hide on timer.
--- v1.32: Fixed the bug from 1.31 where apps set to timer-based hiding starting to hide before pressing the Save button.
--- v1.31: Fixed start up bug caused by apps set to timer-based hiding.
--- v1.3: Implemented timer based hiding for individual apps, updated the "auto-hide all" option to integrate the timer based hiding there instead of a separate toggle.
--- v1.2: Implemented auto-hiding of virtual mirror. Added validation for manual inputs into time-out slider.
--- v1.1: Implemented auto-hiding of apps when there's no mouse movement or D-Pad inputs for x continuous seconds, implemented auto-hiding of apps in replay mode, added option to recognize F6 int/ext cameras, fixed 'remove' button restoring apps on the wrong desktops.
--- v1.02: Fixed auto-hide all apps option not working with apps that are also set up in custom rules in certain conditions.
--- v1.01: Fixed incorrect behaviour when switching from dash camera to other cameras.

local SIM = ac.getSim()
local UI = ac.getUI()
local DESKTOPS = { "1", "2", "3", "4", "All" }
local HIDE_CONDITIONS = { "Off", "In interior views", "In exterior views", "On Timer" }
local HIDE_MIRROR_CONDITIONS = { "Off", "In cockpit view only", "In interior views", "In exterior views", "Always" }
local MIN_TIMEOUT_VALUE = 1.0    --- For time-out slider min value
local MAX_TIMEOUT_VALUE = 10.0   --- For time-out slider max value
local MOUSE_DISTANCE_MOVED = 2.2 --- Distance the mouse should be moved for the "auto-hide on idle" rule to show the ui

local MANIFEST = ac.INIConfig.load("manifest.ini")
local CONFIG_PATH = ac.getFolder(ac.FolderID.ACApps) .. "/lua/Auto_Hide_HUD/rules.ini"
local config = ac.INIConfig.load(CONFIG_PATH)


local listOfRules = {}                                   --- Contains the custom rules created by the user
local visibleAppIDs = {}                                 --- Contains the IDs of every currently visible app window
local visibleAppNames = {}                               --- Contains human-friedly names of every currently visible app window
local appsOnTimer = {}                                   --- IDs of apps that have their hide condition set to "On Timer"

local rulesInit = false                                  --- Flag to know if rules were loaded from config
local hideAllInt = false                                 --- For Auto-hide all apps in interior
local hideAllExt = false                                 --- For Auto-hide all apps in exterior
local isHideOnTimeOut = false                            --- For Auto-hide all apps on timer
local hideAllApps = refnumber(1)                         --- For Auto-hide all apps dropdown
local hideTimer = 0                                      --- Time-out time counter
local hideTimeOut = 1                                    --- Time-out value set by user
local isHUDHidden = false
local isHideInReplays = false                            --- Hide in replays enabled flag
local isHideInReplaysCheckbox = refbool(isHideInReplays) --- For hide in replays checkbox
local f6AsOrig = false                                   --- Treat F6 int/ext cameras as AC
local f6AsOrigCheckbox = refbool(f6AsOrig)               --- For F6 int/ext checkbox
local hideMirror = refnumber(1)                          --- For auto-hide virtual mirror dropdown
local appsOnTimerHidden = false
local timeoutSliderVisible = false

local previousCamera = SIM.cameraMode                  --- For tracking camera changes
local previousDesktop = UI.currentDesktop              --- For tracking desktop changes
local previousDrivableCamera = SIM.driveableCameraMode --- For tracking `ac.CameraMode.Drivable` camera changes
local previousCarCamera = SIM.carCameraIndex           --- For tracking `ac.CameraMode.Car` changes

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
    hideAllApps = refnumber(config:get("GENERAL", "hideAllApps", 1))
    isHideInReplays = config:get("GENERAL", "isHideInReplays", false)
    isHideInReplaysCheckbox = refbool(isHideInReplays)
    hideTimeOut = config:get("GENERAL", "hideTimeOut", 0)
    f6AsOrig = config:get("GENERAL", "f6AsOrig", false)
    f6AsOrigCheckbox = refbool(f6AsOrig)
    hideMirror = refnumber(config:get("GENERAL", "hideMirror", 1))

    for i = 1, config:get("GENERAL", "count", 0) do
        table.insert(listOfRules, {
            appID = config:get("RULE_" .. i, "appID", ""),
            appName = config:get("RULE_" .. i, "appName", ""),
            condition = config:get("RULE_" .. i, "condition", 1),
            desktop = config:get("RULE_" .. i, "desktop", #DESKTOPS),
            saved = config:get("RULE_" .. i, "saved", false),
        })
    end

    updateVisibleApps()
    rulesInit = true
end

--- Saves rules to the config
local function saveRules()
    config:set("GENERAL", "hideAllApps", hideAllApps.value)
    config:set("GENERAL", "isHideInReplays", isHideInReplays)
    config:set("GENERAL", "hideTimeOut", hideTimeOut)
    config:set("GENERAL", "f6AsOrig", f6AsOrig)
    config:set("GENERAL", "hideMirror", hideMirror.value)

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
end

--- Checks current view
--- @return boolean @Returns true if current camera is an interior view
local function isInteriorView()
    if f6AsOrig then
        return ac.isInteriorView() or SIM.cameraMode == ac.CameraMode.Cockpit or
            SIM.cameraMode == ac.CameraMode.Drivable and SIM.driveableCameraMode == ac.DrivableCamera.Dash
    else
        return SIM.cameraMode == ac.CameraMode.Cockpit or
            SIM.cameraMode == ac.CameraMode.Drivable and SIM.driveableCameraMode == ac.DrivableCamera.Dash
    end
end

--- Hides and shows virtual mirror
local function hideVirtualMirror()
    if SIM.isVirtualMirrorActive and hideMirror.value ~= 1 then
        if hideMirror.value == 2 then -- hide only in cockpit but not in dash view
            ac.redirectVirtualMirror(SIM.cameraMode == ac.CameraMode.Cockpit)
        end
        if hideMirror.value == 3 then -- hide in cockpit and dash views both
            ac.redirectVirtualMirror(isInteriorView())
        end
        if hideMirror.value == 4 then -- hide in exterior views
            ac.redirectVirtualMirror(not isInteriorView())
        end
        if hideMirror.value == 5 then -- always hide
            ac.redirectVirtualMirror(true)
        end
    elseif hideMirror.value == 1 then -- off
        ac.redirectVirtualMirror(false)
    end
end

--- Hides and shows apps as per created rules
local function applyRules()
    -- Apply "auto-hide all" rule
    if hideAllApps.value ~= 1 then
        if isInteriorView() then
            ac.setAppsHidden(hideAllInt)
            isHUDHidden = hideAllInt
            isHideOnTimeOut = false
        else
            ac.setAppsHidden(hideAllExt)
            isHUDHidden = hideAllExt
            isHideOnTimeOut = false
        end
        if hideAllApps.value == 4 then
            isHUDHidden = false
            isHideOnTimeOut = true
        end
    else
        ac.setAppsHidden(false)
        isHUDHidden = false
        isHideOnTimeOut = false
        appsOnTimer = table.filter(listOfRules, function(rule) return rule.condition == 4 end)
        -- Iterate through custom rules and apply them if necessary
        for _, rule in ipairs(listOfRules) do
            if (rule.desktop == UI.currentDesktop + 1 or rule.desktop == #DESKTOPS) and not SIM.isPaused then -- if correct desktop
                if rule.condition == 1 then
                    ac.accessAppWindow(rule.appID):setVisible(true)
                elseif rule.condition == 2 then -- hide in interior
                    ac.accessAppWindow(rule.appID):setVisible(not isInteriorView())
                elseif rule.condition == 3 then -- hide in exterior
                    ac.accessAppWindow(rule.appID):setVisible(isInteriorView())
                end
            elseif rule.appID ~= nil and rule.appID ~= "" then -- restore app window on other desktops
                ac.accessAppWindow(rule.appID):setVisible(ac.accessAppWindow(rule.appID):visible())
            end
        end
    end

    -- hide/show virtual mirror
    hideVirtualMirror()
end

--- Hides ALL apps after hideTimeOut seconds if mouse is not moved or D-Pad is not pressed
--- @param dt number @Time passed since last `update()` call, in seconds.
local function timeOutFull(dt)
    -- detect mouse movement, clicks, CTRL pressed or D-Pad inputs
    if math.abs(ui.mouseDelta().x + ui.mouseDelta().y) > MOUSE_DISTANCE_MOVED or
        ac.isGamepadButtonPressed(4, ac.GamepadButton.DPadUp) or
        ac.isGamepadButtonPressed(4, ac.GamepadButton.DPadDown) or
        ac.isGamepadButtonPressed(4, ac.GamepadButton.DPadLeft) or
        ac.isGamepadButtonPressed(4, ac.GamepadButton.DPadRight) or
        ac.getJoystickDpadValue(0, 0) > -1 or
        ac.isKeyDown(ui.KeyIndex.Control) or
        ac.isKeyDown(ui.KeyIndex.LeftButton) or
        ac.isKeyDown(ui.KeyIndex.RightButton)
    then
        hideTimer = 0
        if isHUDHidden then
            ac.setAppsHidden(false)
            isHUDHidden = false
        end
    end

    -- increment hideTimer
    if hideTimer < hideTimeOut then hideTimer = hideTimer + dt end

    -- hide HUD after timer reaches time-out value
    if not isHUDHidden and hideTimer >= hideTimeOut then
        ac.setAppsHidden(true)
        isHUDHidden = true
    end
end

--- Hides just the apps that were set to "Hide On Timer" after hideTimeOut seconds if mouse is not moved or D-Pad is not pressed
--- @param dt number @Time passed since last `update()` call, in seconds.
local function timeOutIndividual(dt)
    -- detect mouse movement, clicks, CTRL pressed or D-Pad inputs
    if math.abs(ui.mouseDelta().x + ui.mouseDelta().y) > MOUSE_DISTANCE_MOVED or
        ac.isGamepadButtonPressed(4, ac.GamepadButton.DPadUp) or
        ac.isGamepadButtonPressed(4, ac.GamepadButton.DPadDown) or
        ac.isGamepadButtonPressed(4, ac.GamepadButton.DPadLeft) or
        ac.isGamepadButtonPressed(4, ac.GamepadButton.DPadRight) or
        ac.getJoystickDpadValue(0, 0) > -1 or
        ac.isKeyDown(ui.KeyIndex.Control) or
        ac.isKeyDown(ui.KeyIndex.LeftButton) or
        ac.isKeyDown(ui.KeyIndex.RightButton)
    then
        hideTimer = 0
        if appsOnTimerHidden then
            table.forEach(appsOnTimer,
                function(value, _)
                    if (value.desktop == UI.currentDesktop + 1 or value.desktop == #DESKTOPS) and not SIM.isPaused then -- if correct desktop
                        ac.accessAppWindow(value.appID):setVisible(true)
                    elseif value.appID ~= nil and value.appID ~= "" then -- restore app window on other desktops
                        ac.accessAppWindow(value.appID):setVisible(ac.accessAppWindow(value.appID):visible())
                    end
                end
            )
            appsOnTimerHidden = false
        end
    end

    -- increment hideTimer
    if hideTimer < hideTimeOut then hideTimer = hideTimer + dt end

    -- hide apps after timer reaches time-out value
    if not appsOnTimerHidden and hideTimer >= hideTimeOut then
        table.forEach(appsOnTimer,
            function(value, _)
                if (value.desktop == UI.currentDesktop + 1 or value.desktop == #DESKTOPS)and not SIM.isPaused then -- if correct desktop
                    ac.accessAppWindow(value.appID):setVisible(false)
                elseif value.appID ~= nil and value.appID ~= "" then -- restore app window on other desktops
                    ac.accessAppWindow(value.appID):setVisible(ac.accessAppWindow(value.appID):visible())
                end
            end
        )
        appsOnTimerHidden = true
    end
end

--- Auto-hide all apps option
local function autoHideAll()
    ui.combo("Auto-hide all apps", hideAllApps, HIDE_CONDITIONS)
    if ui.itemHovered() then ui.setTooltip("Auto-hide all apps in interior or exterior view or on timer") end

    if hideAllApps.value == 1 then -- off
        hideAllInt = false
        hideAllExt = false
        timeoutSliderVisible = false
    elseif hideAllApps.value == 2 then -- hide in interior
        hideAllInt = true
        hideAllExt = false
        timeoutSliderVisible = false
    elseif hideAllApps.value == 3 then -- hide in exterior
        hideAllInt = false
        hideAllExt = true
        timeoutSliderVisible = false
    elseif hideAllApps.value == 4 then -- hide on timer
        hideAllInt = false
        hideAllExt = false
        timeoutSliderVisible = true
    end
end

--- Auto-hide virtual mirror option
local function autoHideVMirror()
    ui.combo("Auto-hide virtual mirror", hideMirror, HIDE_MIRROR_CONDITIONS)
    if ui.itemHovered() then ui.setTooltip("Works online!") end
end

--- Auto-hide all apps in replays option
local function autoHideInReplays()
    ui.checkbox("Auto-hide all apps in replays", isHideInReplaysCheckbox)
    if ui.itemHovered() then
        ui.setTooltip(
            "Off - Follow the main setting in replays\nOn - Override the main setting in replays")
    end
end

--- Show timeout slider
local function timeOutSlider()
    local valid
    valid = ui.slider("##timeOut", hideTimeOut, MIN_TIMEOUT_VALUE, MAX_TIMEOUT_VALUE, 'Time-Out, sec: %0.1f')

    -- validate manual input
    if valid >= MIN_TIMEOUT_VALUE then
        hideTimeOut = valid
    else
        hideTimeOut = MAX_TIMEOUT_VALUE
    end

    if ui.itemHovered() then
        ui.setTooltip(
            "Amount of seconds to wait before hiding apps that are set up with the timer option.\n\nTo use values greater than " ..
            tostring(MAX_TIMEOUT_VALUE) .. " seconds you can CTRL + Click on this slider for manual input.")
    end
end

--- F6 cameras behaviour option
local function f6Toggle()
    ui.checkbox("Treat F6 interior/exterior cameras in original AC style", f6AsOrigCheckbox)
    if ui.itemHovered() then
        ui.setTooltip(
            "Original AC style: if there's interior audio, then it's an interior view, otherwise it's an exterior view.")
    end
end

--- Show per-app custom rules
local function customRules()
    ui.setNextTextBold()
    ui.text("Per-App Custom Rules")
    ui.separator()
    for i, rule in ipairs(listOfRules) do
        ui.labelText("", "App:")
        ui.sameLine(60)
        if rule.saved then -- for saved rules
            ui.labelText("", rule.appName)
        else               -- for newly added, unsaved rules
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
            if rule.appID ~= nil and rule.appID ~= "" and (rule.desktop == UI.currentDesktop + 1 or rule.desktop == #DESKTOPS) then
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
end

--- Renders the Rules tab and its contents
local function rules()
    autoHideAll()
    ui.sameLine(0, 39)
    autoHideInReplays()
    if #table.filter(listOfRules, function(rule) return rule.condition == 4 end) > 0 or timeoutSliderVisible then
        ui.sameLine(0, 30)
        timeOutSlider()
    end

    autoHideVMirror()
    ui.sameLine()
    f6Toggle()

    ui.separator()
    customRules()
    if #listOfRules > 0 then ui.separator() end

    if ui.modernButton("New Rule", vec2(112, 30), ui.ButtonFlags.None, ui.Icons.Plus) then
        table.insert(listOfRules, { index = 1, appID = "", appName = "", condition = 1, desktop = #DESKTOPS, saved = false })
    end

    ui.sameLine()

    if ui.modernButton("Reset", vec2(100, 30), ui.ButtonFlags.None, ui.Icons.Reset) then
        config = ac.INIConfig.load(CONFIG_PATH)
        listOfRules = {}
        appsOnTimer = {}
        initRules()
        applyRules()
    end
    if ui.itemHovered() then ui.setTooltip("Reset rules to the last saved state") end

    ui.sameLine()

    if ui.modernButton("Save", vec2(85, 30), ui.ButtonFlags.Confirm, ui.Icons.Save) then
        isHideInReplays = isHideInReplaysCheckbox.value
        f6AsOrig = f6AsOrigCheckbox.value
        applyRules()

        saveRules()

        listOfRules = {}
        initRules()
    end
end

--- Renders the about tab and its contents
local function about()
    ui.columns(2)
    ui.setColumnWidth(0, 120)
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
    -- Load rules on session start
    if not rulesInit then initRules() end

    -- Auto-hide after time-out
    if isHideOnTimeOut then
        hideVirtualMirror()
        timeOutFull(dt)
    else
        if #appsOnTimer > 0 then
            timeOutIndividual(dt)
        end

        -- Detect camera changes
        if previousCamera ~= SIM.cameraMode or previousDrivableCamera ~= SIM.driveableCameraMode or previousCarCamera ~= SIM.carCameraIndex then
            applyRules()
        end
        previousCamera = SIM.cameraMode
        previousDrivableCamera = SIM.driveableCameraMode
        previousCarCamera = SIM.carCameraIndex

        -- Detect desktop changes
        if previousDesktop ~= UI.currentDesktop then
            applyRules()
        end
        previousDesktop = UI.currentDesktop

        -- Detect replays
        if isHideInReplays then
            if not isHUDHidden and ac.isInReplayMode() then
                ac.setAppsHidden(true)
                isHUDHidden = true
            elseif isHUDHidden and not ac.isInReplayMode() then
                applyRules()
            end
        end
    end
end
