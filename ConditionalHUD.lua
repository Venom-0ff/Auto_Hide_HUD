SIM = ac.getSim()
CAM_MODE = SIM.cameraMode -- SIM.driveableCameraMode

local apps = ac.getAppWindows()
for _, app in ipairs(apps) do
    ac.console(app.title)
end

function script.update(dt)
    if SIM.cameraMode == 0 or SIM.driveableCameraMode == 4 then
        ac.accessAppWindow("FM4 Speedometer"):setVisible(false)
        ac.accessAppWindow("IMGUI_LUA_GT7 HUD_tachometer"):setVisible(false)
    else
        ac.accessAppWindow("FM4 Speedometer"):setVisible(true)
        ac.accessAppWindow("IMGUI_LUA_GT7 HUD_tachometer"):setVisible(true)
    end
end
