-- Conditional HUD App
-- Author: Venom
-- Version: 1.0

local SIM = ac.getSim()
local UI = ac.getUI()
local CONFIG_PATH = ac.getFolder(ac.FolderID.ACApps) .. "/lua/ConditionalHUD/rules.ini"
local CONFIG = ac.INIConfig.load(CONFIG_PATH)
local DESKTOPS = { "1", "2", "3", "4", "All" }
local HIDE_CONDITIONS = { "Off", "Never", "In interior views", "In exterior views" }

local listOfRules = {}
local visibleAppIDs = {}
local visibleAppNames = {}

local rulesInit = false
local hideAllInt = false
local hideAllExt = false
local hideAllApps = CONFIG:get("GENERAL", "hideAllApps", 1)

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
    for i = 1, CONFIG:get("GENERAL", "count", 0) do
        table.insert(listOfRules, {
            appID = CONFIG:get("RULE_" .. i, "appID", ""),
            appName = CONFIG:get("RULE_" .. i, "appName", ""),
            condition = CONFIG:get("RULE_" .. i, "condition", 1),
            desktop = CONFIG:get("RULE_" .. i, "desktop", 5),
            saved = CONFIG:get("RULE_" .. i, "saved", false),
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
    end

    for _, rule in ipairs(listOfRules) do
        if rule.condition ~= 1 then
            if rule.desktop == UI.currentDesktop + 1 or rule.desktop == 5 then
                if rule.condition == 2 then
                    ac.accessAppWindow(rule.appID):setVisible(true)
                elseif rule.condition == 3 then
                    ac.accessAppWindow(rule.appID):setVisible(not isInteriorView())
                elseif rule.condition == 4 then
                    ac.accessAppWindow(rule.appID):setVisible(isInteriorView())
                end
            else
                ac.accessAppWindow(rule.appID):setVisible(true)
            end
        end
    end
end

local function rules(dt)
    hideAllApps = ui.combo("Hide all apps:", hideAllApps, HIDE_CONDITIONS)

    if hideAllApps == 2 then
        hideAllInt = false
        hideAllExt = false
    elseif hideAllApps == 3 then
        hideAllInt = true
        hideAllExt = false
    elseif hideAllApps == 4 then
        hideAllInt = false
        hideAllExt = true
    end

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
            listOfRules[i].appID = visibleAppIDs[listOfRules[i].index]
            listOfRules[i].appName = visibleAppNames[listOfRules[i].index]
        end
        ui.sameLine()

        ui.text("Hide:")
        ui.sameLine()
        listOfRules[i].condition = ui.combo("##Condition" .. i, rule.condition, HIDE_CONDITIONS)
        ui.sameLine()

        ui.text("On desktop:")
        ui.sameLine()
        listOfRules[i].desktop = ui.combo("##Desktop" .. i, rule.desktop, DESKTOPS)
        ui.sameLine()

        if ui.modernButton("##Remove" .. i, vec2(22, 22), ui.ButtonFlags.Cancel, ui.Icons.Delete) then
            if rule.appID ~= nil then
                ac.accessAppWindow(rule.appID):setVisible(true)
            end

            CONFIG:set("RULE_" .. i, "appID", nil)
            CONFIG:set("RULE_" .. i, "appName", nil)
            CONFIG:set("RULE_" .. i, "condition", nil)
            CONFIG:set("RULE_" .. i, "desktop", nil)
            CONFIG:set("RULE_" .. i, "saved", nil)

            table.remove(listOfRules, i)
        end
        ui.separator()
    end

    if ui.modernButton("New Rule", vec2(112, 30), ui.ButtonFlags.None, ui.Icons.Plus) then
        table.insert(listOfRules, { index = 0, appID = "", appName = "", condition = 1, desktop = 5, saved = false })
    end

    ui.sameLine()

    if ui.modernButton("Preview", vec2(100, 30), ui.ButtonFlags.None, ui.Icons.Eye) then
        applyRules()
    end

    ui.sameLine()

    if ui.modernButton("Save", vec2(85, 30), ui.ButtonFlags.Confirm, ui.Icons.Save) then
        applyRules()
        CONFIG:set("GENERAL", "hideAllApps", hideAllApps)
        CONFIG:set("GENERAL", "count", #listOfRules)
        for i, rule in ipairs(listOfRules) do
            CONFIG:set("RULE_" .. i, "appID", rule.appID)
            CONFIG:set("RULE_" .. i, "appName", rule.appName)
            CONFIG:set("RULE_" .. i, "condition", rule.condition)
            CONFIG:set("RULE_" .. i, "desktop", rule.desktop)
            CONFIG:set("RULE_" .. i, "saved", true)
        end
        CONFIG:save(CONFIG_PATH)
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
    ui.text(ac.INIConfig.load("manifest.ini"):get("ABOUT", "NAME ", ""))
    ui.text(ac.INIConfig.load("manifest.ini"):get("ABOUT", "DESCRIPTION ", ""))
    ui.text(ac.INIConfig.load("manifest.ini"):get("ABOUT", "AUTHOR ", ""))
    ui.text(ac.INIConfig.load("manifest.ini"):get("ABOUT", "VERSION ", ""))
    ui.textHyperlink(ac.INIConfig.load("manifest.ini"):get("ABOUT", "URL ", ""))
end

function script.windowMain(dt)
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
