-- Auto-Hide HUD App
-- Author: Venom
-- Version: 1.0

local SIM = ac.getSim()
local UI = ac.getUI()
local DESKTOPS = { "1", "2", "3", "4", "All" }
local HIDE_CONDITIONS = { "Off", "In interior views", "In exterior views" }

local MANIFEST = ac.INIConfig.load("manifest.ini")
local CONFIG_PATH = ac.getFolder(ac.FolderID.ACApps) .. "/lua/Auto_Hide_HUD/rules.ini"
local config = ac.INIConfig.load(CONFIG_PATH)


local listOfRules = {}
local visibleAppIDs = {}
local visibleAppNames = {}

local rulesInit = false
local hideAllInt = false
local hideAllExt = false
local hideAllApps = config:get("GENERAL", "hideAllApps", 1)

local previousCamera = nil
local previousDesktop = nil
local previousDrivableCamera = nil

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

local function initRules()
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

local function isInteriorView()
    return (SIM.cameraMode == 0 or SIM.driveableCameraMode == 4)
end

local function applyRules()
    if hideAllApps ~= 1 then
        if isInteriorView() then
            ac.setAppsHidden(hideAllInt)
        else
            ac.setAppsHidden(hideAllExt)
        end
    else
        ac.setAppsHidden(false)
    end

    for _, rule in ipairs(listOfRules) do
        if rule.condition ~= 1 then
            if rule.desktop == UI.currentDesktop + 1 or rule.desktop == 5 then
                if rule.condition == 2 then
                    ac.accessAppWindow(rule.appID):setVisible(not isInteriorView())
                elseif rule.condition == 3 then
                    ac.accessAppWindow(rule.appID):setVisible(isInteriorView())
                end
            elseif rule.appID ~= nil then
                ac.accessAppWindow(rule.appID):setVisible(ac.accessAppWindow(rule.appID):visible())
            end
        end
    end
end

local function rules(dt)
    hideAllApps = ui.combo("Hide all apps:", hideAllApps, HIDE_CONDITIONS)
    if ui.itemHovered() then ui.setTooltip("Auto-hide all apps in interior or exterior view") end

    if hideAllApps == 1 then
        hideAllInt = false
        hideAllExt = false
    elseif hideAllApps == 2 then
        hideAllInt = true
        hideAllExt = false
    elseif hideAllApps == 3 then
        hideAllInt = false
        hideAllExt = true
    end

    ui.separator()
    ui.text("Custom Rules")
    ui.separator()
    for i, rule in ipairs(listOfRules) do
        ui.labelText("", "App:")
        ui.sameLine(60)
        if rule.saved then
            ui.setNextTextBold()
            ui.labelText("", rule.appName)
        else
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
            if rule.appID ~= nil then
                ac.accessAppWindow(rule.appID):setVisible(true)
            end

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
    end
    if ui.itemHovered() then ui.setTooltip("Reset rules to the last saved state") end

    ui.sameLine()

    if ui.modernButton("Save", vec2(85, 30), ui.ButtonFlags.Confirm, ui.Icons.Save) then
        applyRules()
        config:set("GENERAL", "hideAllApps", hideAllApps)
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

local function about()
    ui.columns(2)
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

function script.windowMain(dt)
    ui.icon("icon.png", vec2(15,15))
    ui.sameLine()
    ui.setNextTextBold()
    ui.text(MANIFEST:get("ABOUT", "NAME", ""))
    ui.tabBar("main", function()
        ui.tabItem("Rules", rules)
        ui.tabItem("About", about)
    end)
end

function script.update(dt)
    if not rulesInit then initRules() end

    if previousCamera ~= SIM.cameraMode or previousDrivableCamera ~= SIM.driveableCameraMode then
        applyRules()
    end
    previousCamera = SIM.cameraMode
    previousDrivableCamera = SIM.driveableCameraMode

    if previousDesktop ~= UI.currentDesktop then
        applyRules()
    end
    previousDesktop = UI.currentDesktop
end
