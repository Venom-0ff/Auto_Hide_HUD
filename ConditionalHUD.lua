SIM = ac.getSim()
DESKTOPS = { "1", "2", "3", "4", "All" }

local apps = ac.getAppWindows()

function getVisibleAppNames()
    local appNames = {}
    for _, app in ipairs(apps) do
        if app.visible then
            table.insert(appNames, app.name)
        end
    end
    return appNames
end

HIDE_CONDITIONS = { "Manually", "Never", "In interior cams", "In exterior cams" }
local hideAllInt = false
local hideAllExt = false
local hideAllRule = 1

local listOfRules = {}
local visibleAppNames = getVisibleAppNames()

function rules(dt)
    hideAllRule = ui.combo("Hide all apps:", hideAllRule, HIDE_CONDITIONS)

    if hideAllRule == 2 then
        hideAllInt = false
        hideAllExt = false
    elseif hideAllRule == 3 then
        hideAllInt = true
        hideAllExt = false
    elseif hideAllRule == 4 then
        hideAllInt = false
        hideAllExt = true
    end

    ui.separator()

    for i, rule in ipairs(listOfRules) do
        ui.text("App:")
        ui.sameLine()
        listOfRules[i].index = ui.combo("##Rule" .. i, rule.index, visibleAppNames)
        listOfRules[i].appName = visibleAppNames[listOfRules[i].index]
        ui.sameLine()
        ui.text("Hide:")
        ui.sameLine()
        listOfRules[i].condition = ui.combo("##Condition" .. i, rule.condition, HIDE_CONDITIONS)
        ui.sameLine()
        ui.text("On desktop:")
        ui.sameLine()
        listOfRules[i].desktop = ui.combo("##Desktop" .. i, rule.desktop, DESKTOPS)
        ui.sameLine()
        if ui.iconButton(ui.Icons.Cancel .. "##Remove" .. i) then
            table.remove(listOfRules, i)
        end
        ui.separator()
    end

    if ui.button("+ Add New Rule") then
        table.insert(listOfRules, { index = 0, appName = "", condition = 1, desktop = 5 })
    end

    -- if ui.button("Save") then
    --
    -- end
end

function script.windowMain(dt)
    ui.tabBar("main", function()
        ui.tabItem("Rules", rules)
    end)
end

function isInteriorView()
    return (SIM.cameraMode == 0 or SIM.driveableCameraMode == 4)
end

function applyRules()
    for _, rule in ipairs(listOfRules) do
        if rule.condition ~= 1 then
            if rule.desktop - 1 == ac.getUI().currentDesktop or rule.desktop == 5 then
                if rule.condition == 2 then
                    ac.accessAppWindow(rule.appName):setVisible(true)
                elseif rule.condition == 3 then
                    ac.accessAppWindow(rule.appName):setVisible(not isInteriorView())
                elseif rule.condition == 4 then
                    ac.accessAppWindow(rule.appName):setVisible(isInteriorView())
                end
            else
                ac.accessAppWindow(rule.appName):setVisible(true)
            end
        end
    end
end

function onCameraChanged()
    if hideAllRule ~= 1 then
        if isInteriorView() then
            ac.setAppsHidden(hideAllInt)
        else
            ac.setAppsHidden(hideAllExt)
        end
    end
    applyRules()
end

local previousCamera = nil
local previousDrivableCamera = nil

function script.update(dt)
    if previousCamera ~= SIM.cameraMode or previousDrivableCamera ~= SIM.driveableCameraMode then
        onCameraChanged()
    end
    previousCamera = SIM.cameraMode
    previousDrivableCamera = SIM.driveableCameraMode
end
