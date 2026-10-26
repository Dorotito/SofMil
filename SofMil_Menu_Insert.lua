-- Sof&Mil | Menú Knife Duels con foto integrada, Insert mejorado y modos de seguimiento
-- Ejecuta este archivo completo. No requiere pegar la imagen en un servidor externo
-- si tu ejecutor soporta getcustomasset + writefile; en otro caso usa Asset ID.
local SOURCE = [=====[
-- Sof&Mil | Knife Duels - menu configurable (Luau)
-- INSERT: mostrar/ocultar. Boton lateral: remapear a F6 en el software del mouse.
-- Requiere un entorno que admita Drawing y, para guardar/teleport, readfile/writefile/queue_on_teleport.
repeat task.wait() until game:IsLoaded() and game:GetService("Players").LocalPlayer

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local GUI = player:WaitForChild("PlayerGui")

if type(_G.KD_ESP_UNLOAD) == "function" then pcall(_G.KD_ESP_UNLOAD) end

local SCRIPT_FILE = "SofMil_Menu.lua"
local CONFIG_FILE = "SofMil_Config.json"
local settings = {
    AimEnabled = true, AimKey = "F6", AimMode = "Hold", AimPart = "Head", AimSmooth = 0,
    RequireLineOfSight = true, BackgroundAssetId = "",
    AimFOV = 75, MaxDistance = 1000, ShowFOV = true, TeamCheck = true,
    ESPEnabled = true, SkeletonESP = true, NamesEnabled = true,
    BoxESP = false, TracerESP = false,
    ExcludedTeam = "mina", ExcludedNames = {zmilton15 = true, mina = true}
}
local parts = {"Head", "UpperTorso", "HumanoidRootPart", "LowerTorso", "Torso"}
local partAllowed = {}
for _, name in ipairs(parts) do partAllowed[name] = true end

local function trim(value)
    return (tostring(value):gsub("^%s+", ""):gsub("%s+$", ""))
end
local function cleanName(value)
    return trim(value):gsub("^@", ""):lower():sub(1, 40)
end
local function loadConfig()
    if type(readfile) ~= "function" then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
    -- Actualiza desde la versión anterior, sin perder las preferencias.
    if not ok then
        ok, data = pcall(function() return HttpService:JSONDecode(readfile("KD_Salz_Config.json")) end)
    end
    if not ok or type(data) ~= "table" then return end
    for key, original in pairs(settings) do
        if key ~= "ExcludedNames" and type(data[key]) == type(original) then
            settings[key] = data[key]
        end
    end
    if type(data.ExcludedNames) == "table" then
        settings.ExcludedNames = {}
        for name, enabled in pairs(data.ExcludedNames) do
            if type(name) == "string" and enabled == true then
                local cleaned = cleanName(name)
                if cleaned ~= "" then settings.ExcludedNames[cleaned] = true end
            end
        end
    end
    if not partAllowed[settings.AimPart] then settings.AimPart = "Head" end
    if settings.AimMode ~= "Toggle" then settings.AimMode = "Hold" end
    settings.BackgroundAssetId = trim(settings.BackgroundAssetId):gsub("[^%d]", ""):sub(1, 25)
    if not Enum.KeyCode[settings.AimKey] or settings.AimKey == "Insert" then settings.AimKey = "F6" end
    settings.AimFOV = math.clamp(settings.AimFOV, 10, 450)
    settings.AimSmooth = math.clamp(settings.AimSmooth, 0, 0.95)
    settings.MaxDistance = math.clamp(settings.MaxDistance, 100, 3000)
    settings.ExcludedTeam = trim(settings.ExcludedTeam):lower():sub(1, 40)
end
loadConfig()

local function saveConfig()
    if type(writefile) ~= "function" then return false end
    return pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(settings)) end)
end

local autoStatus = "No disponible"
if type(queue_on_teleport or queueonteleport) == "function" and type(readfile) == "function" then
    local snippet = [[
        repeat task.wait() until game:IsLoaded()
        local ok, source = pcall(readfile, "SofMil_Menu.lua")
        if ok and type(source) == "string" then
            local execute, err = loadstring(source)
            if execute then execute() else warn("Sof&Mil: ", err) end
        end
    ]]
    local ok = pcall(queue_on_teleport or queueonteleport, snippet)
    autoStatus = ok and "Preparado (si el ejecutor lo admite)" or "Falló la cola de teleport"
end

local connections, drawings = {}, {}
local redrawAimStatus = function() end
local isAiming, selected, rebinding, menuOpen = false, nil, false, true
local function track(connection) connections[#connections + 1] = connection return connection end
local function draw(class, props)
    local item = Drawing.new(class)
    for k, v in pairs(props) do item[k] = v end
    drawings[#drawings + 1] = item
    return item
end
local circle = draw("Circle", {Visible=false, Filled=false, NumSides=48, Thickness=1, Color=Color3.fromRGB(255,70,70), Radius=settings.AimFOV})
local skeleton15 = {
    {"Head","UpperTorso"}, {"UpperTorso","LowerTorso"}, {"UpperTorso","LeftUpperArm"},
    {"LeftUpperArm","LeftLowerArm"}, {"LeftLowerArm","LeftHand"}, {"UpperTorso","RightUpperArm"},
    {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"}, {"LowerTorso","LeftUpperLeg"},
    {"LeftUpperLeg","LeftLowerLeg"}, {"LeftLowerLeg","LeftFoot"}, {"LowerTorso","RightUpperLeg"},
    {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"}
}
local skeleton6 = {{"Head","Torso"}, {"Torso","Left Arm"}, {"Torso","Right Arm"}, {"Torso","Left Leg"}, {"Torso","Right Leg"}}
local visuals = {}
local function createVisual(other)
    if other == player or visuals[other] then return end
    local o = {lines={}}
    o.name = draw("Text", {Visible=false, Color=Color3.fromRGB(255,255,255), Size=13, Center=true, Outline=true})
    o.box = draw("Square", {Visible=false, Filled=false, Thickness=1, Color=Color3.fromRGB(255,70,70)})
    o.tracer = draw("Line", {Visible=false, Thickness=1, Color=Color3.fromRGB(255,255,255)})
    for i = 1, 14 do o.lines[i] = draw("Line", {Visible=false, Thickness=1.5, Color=Color3.fromRGB(0,255,140)}) end
    visuals[other] = o
end
local function hideVisual(o)
    o.name.Visible, o.box.Visible, o.tracer.Visible = false, false, false
    for _, line in ipairs(o.lines) do line.Visible = false end
end
local function removeVisual(other)
    local o = visuals[other]
    if not o then return end
    for _, object in ipairs({o.name, o.box, o.tracer}) do pcall(function() object:Remove() end) end
    for _, line in ipairs(o.lines) do pcall(function() line:Remove() end) end
    visuals[other] = nil
end
local function excluded(other)
    if not other or other == player then return true end
    if settings.ExcludedNames[other.Name:lower()] or settings.ExcludedNames[other.DisplayName:lower()] then return true end
    if other.Team and settings.ExcludedTeam ~= "" and other.Team.Name:lower() == settings.ExcludedTeam then return true end
    return settings.TeamCheck and player.Team ~= nil and other.Team ~= nil and player.Team == other.Team
end
local function aimPartOf(char)
    if not char then return nil end
    local name = settings.AimPart
    local found = char:FindFirstChild(name)
    if found and found:IsA("BasePart") then return found end
    if name == "UpperTorso" or name == "LowerTorso" then return char:FindFirstChild("Torso") end
    if name == "Torso" then return char:FindFirstChild("UpperTorso") end
    return nil
end
local function validTarget(other)
    if excluded(other) or not other.Character then return nil end
    local hum = other.Character:FindFirstChildOfClass("Humanoid")
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local part = aimPartOf(other.Character)
    if not (hum and hum.Health > 0 and root and part) then return nil end
    if (part.Position - root.Position).Magnitude > settings.MaxDistance then return nil end
    return part
end
-- Sólo permite objetivos si hay línea de visión despejada.
-- Si RequireLineOfSight = false, permite objetivos tras geometría.
local function lineOfSight(part)
    if not settings.RequireLineOfSight then return true end
    local camera = workspace.CurrentCamera
    if not camera or not part or not part.Parent then return false end
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = player.Character and {player.Character} or {}
    rayParams.IgnoreWater = true
    local origin = camera.CFrame.Position
    local result = workspace:Raycast(origin, part.Position - origin, rayParams)
    return (result == nil) or result.Instance:IsDescendantOf(part.Parent)
end
local function closest()
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    local best, distance = nil, settings.AimFOV
    local xy = UIS:GetMouseLocation()
    for _, other in ipairs(Players:GetPlayers()) do
        local part = validTarget(other)
        if part then
            local p, visible = camera:WorldToViewportPoint(part.Position)
            if visible and p.Z > 0 and lineOfSight(part) then
                local d = (Vector2.new(p.X, p.Y) - xy).Magnitude
                if d < distance then best, distance = other, d end
            end
        end
    end
    return best
end
local function showSkeleton(char, lines)
    local camera = workspace.CurrentCamera
    local pairsList = char:FindFirstChild("UpperTorso") and skeleton15 or skeleton6
    for i, line in ipairs(lines) do
        local pair = pairsList[i]
        local a = pair and char:FindFirstChild(pair[1])
        local b = pair and char:FindFirstChild(pair[2])
        if a and b and camera then
            local va, visibleA = camera:WorldToViewportPoint(a.Position)
            local vb, visibleB = camera:WorldToViewportPoint(b.Position)
            line.Visible = visibleA or visibleB
            if line.Visible then line.From = Vector2.new(va.X, va.Y); line.To = Vector2.new(vb.X, vb.Y) end
        else line.Visible = false end
    end
end
local function update()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local xy = UIS:GetMouseLocation()
    circle.Position = xy
    circle.Radius = settings.AimFOV
    circle.Visible = settings.AimEnabled and settings.ShowFOV
    if isAiming and settings.AimEnabled and not menuOpen then
        local part = validTarget(selected)
        if part and not lineOfSight(part) then part = nil; selected = nil end
        if not part then selected = closest(); part = validTarget(selected) end
        if part then
            local current = camera.CFrame
            local wanted = CFrame.lookAt(current.Position, part.Position)
            camera.CFrame = settings.AimSmooth <= 0 and wanted or current:Lerp(wanted, settings.AimSmooth)
        end
    else selected = nil end

    local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    for other, o in pairs(visuals) do
        local char = other.Character
        local head = char and char:FindFirstChild("Head")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (settings.ESPEnabled and myRoot and head and root and hum and hum.Health > 0) then
            hideVisual(o)
        elseif (myRoot.Position - root.Position).Magnitude > settings.MaxDistance then
            hideVisual(o)
        else
            local hp, visible = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.4, 0))
            local feet = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
            if not visible then hideVisual(o) else
                o.name.Visible = settings.NamesEnabled
                if o.name.Visible then
                    o.name.Text = string.format("%s [%d]", other.DisplayName, math.floor((myRoot.Position-root.Position).Magnitude))
                    o.name.Position = Vector2.new(hp.X, hp.Y-16)
                end
                o.box.Visible = settings.BoxESP
                if o.box.Visible then
                    local h = math.abs(feet.Y-hp.Y)
                    local w = h*0.55
                    o.box.Position = Vector2.new(hp.X-w/2, hp.Y)
                    o.box.Size = Vector2.new(w, h)
                end
                o.tracer.Visible = settings.TracerESP
                if o.tracer.Visible then
                    o.tracer.From = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
                    o.tracer.To = Vector2.new(hp.X, feet.Y)
                end
                if settings.SkeletonESP then showSkeleton(char, o.lines)
                else for _, line in ipairs(o.lines) do line.Visible = false end end
            end
        end
    end
end

-- Fondo incorporado: la fotografía enviada por el usuario.
-- Se prepara como archivo local cuando el entorno admite archivos y getcustomasset.
local BG_JPG_BASE64 = [==[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]==]
local BG_FILE = "SofMil_Fondo_Perito.jpg"
local function decodeBase64(encoded)
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local index = {}
    for i = 1, #alphabet do index[alphabet:sub(i,i)] = i-1 end
    local result = {}
    for i = 1, #encoded, 4 do
        local a, b, c, d = encoded:sub(i,i), encoded:sub(i+1,i+1), encoded:sub(i+2,i+2), encoded:sub(i+3,i+3)
        if a == "" or b == "" then break end
        local n = (index[a] or 0)*262144 + (index[b] or 0)*4096 + (index[c] or 0)*64 + (index[d] or 0)
        result[#result+1] = string.char(math.floor(n/65536)%256)
        if c ~= "=" then result[#result+1] = string.char(math.floor(n/256)%256) end
        if d ~= "=" then result[#result+1] = string.char(n%256) end
    end
    return table.concat(result)
end
local backgroundState = "Imagen no cargada"
local function backgroundSource()
    local customAsset = getcustomasset or getsynasset
    if type(customAsset) == "function" and type(writefile) == "function" then
        local ok, image = pcall(function()
            local exists = type(isfile) == "function" and isfile(BG_FILE)
            if not exists then writefile(BG_FILE, decodeBase64(BG_JPG_BASE64)) end
            return customAsset(BG_FILE)
        end)
        if ok and type(image) == "string" then
            backgroundState = "Foto local cargada"
            return image
        end
    end
    if settings.BackgroundAssetId ~= "" then
        backgroundState = "Foto por asset ID"
        return "rbxassetid://" .. settings.BackgroundAssetId
    end
    backgroundState = "Sube la foto a Roblox e introduce el asset ID en SISTEMA"
    return ""
end

-- MENU Sof&Mil
local colors = {bg=Color3.fromRGB(14,17,25), panel=Color3.fromRGB(24,29,40), row=Color3.fromRGB(33,39,54), accent=Color3.fromRGB(0,205,145), white=Color3.fromRGB(239,242,248), mute=Color3.fromRGB(158,171,191)}
local function make(class, props, parent)
    local inst = Instance.new(class)
    for key, value in pairs(props) do inst[key] = value end
    inst.Parent = parent
    return inst
end
local function round(what, px)
    make("UICorner", {CornerRadius=UDim.new(0,px or 8)}, what)
    return what
end
local screen = make("ScreenGui", {Name="SofMilMenu", ResetOnSpawn=false, IgnoreGuiInset=true, DisplayOrder=99999, ZIndexBehavior=Enum.ZIndexBehavior.Sibling}, GUI)
local window = round(make("Frame", {Size=UDim2.fromOffset(560,410), Position=UDim2.new(0.5,-280,0.5,-205), BackgroundColor3=colors.bg, BorderSizePixel=0, Active=true}, screen), 11)
local background = round(make("ImageLabel", {Name="SofMilDogBackground", Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Image=backgroundSource(), ImageTransparency=0.37, ScaleType=Enum.ScaleType.Crop, BorderSizePixel=0}, window), 11)
local shade = round(make("Frame", {Size=UDim2.fromScale(1,1), BackgroundColor3=colors.bg, BackgroundTransparency=0.40, BorderSizePixel=0}, window), 11)
make("UIStroke", {Color=Color3.fromRGB(65,75,92), Thickness=1}, window)
local header = make("Frame", {Size=UDim2.new(1,0,0,55), BackgroundTransparency=1, Active=true}, window)
make("TextLabel", {Text="Sof&Mil  /  KNIFE DUELS", Size=UDim2.new(1,-130,0,30), Position=UDim2.fromOffset(18,9), BackgroundTransparency=1, Font=Enum.Font.GothamBold, TextSize=18, TextXAlignment=Enum.TextXAlignment.Left, TextColor3=colors.white}, header)
make("TextLabel", {Text="INSERT = abrir / cerrar", Size=UDim2.new(1,-130,0,14), Position=UDim2.fromOffset(19,34), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left, TextColor3=colors.mute}, header)
local close = round(make("TextButton", {Text="X", Size=UDim2.fromOffset(30,29), Position=UDim2.new(1,-44,0,13), BackgroundColor3=colors.row, TextColor3=colors.white, TextSize=14, Font=Enum.Font.GothamBold}, header), 6)
-- Botón flotante de respaldo: en Arsenal algunos atajos son interceptados.
local reopen = round(make("TextButton", {Name="SofMilReopen", Text="Sof&Mil ☰", Size=UDim2.fromOffset(116,35), Position=UDim2.new(1,-130,0,12), BackgroundColor3=colors.accent, TextColor3=colors.bg, Font=Enum.Font.GothamBold, TextSize=13, BorderSizePixel=0, Visible=false},screen),8)
local sidebar = make("Frame", {Position=UDim2.fromOffset(11,61), Size=UDim2.new(0,126,1,-72), BackgroundTransparency=1}, window)
local content = round(make("Frame", {Position=UDim2.fromOffset(148,61), Size=UDim2.new(1,-159,1,-72), BackgroundColor3=colors.panel, BackgroundTransparency=0.26, BorderSizePixel=0}, window), 9)
local pages, tabButtons = {}, {}
local function page(name)
    local sf = make("ScrollingFrame", {Visible=false, Position=UDim2.fromOffset(8,9), Size=UDim2.new(1,-16,1,-18), BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3, ScrollBarImageColor3=colors.accent, CanvasSize=UDim2.fromOffset(0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y}, content)
    make("UIListLayout", {Padding=UDim.new(0,7), SortOrder=Enum.SortOrder.LayoutOrder}, sf)
    pages[name] = sf
    return sf
end
local function switchPage(name)
    for key, sf in pairs(pages) do sf.Visible = key == name end
    for key, button in pairs(tabButtons) do
        button.BackgroundColor3 = key == name and colors.accent or colors.row
        button.TextColor3 = key == name and colors.bg or colors.white
    end
end
for i, name in ipairs({"AIMBOT","VISUALES","EXCLUIR","SISTEMA"}) do
    local button = round(make("TextButton", {Text=name, Position=UDim2.fromOffset(0,(i-1)*46), Size=UDim2.fromOffset(126,39), BackgroundColor3=colors.row, BorderSizePixel=0, TextColor3=colors.white, TextSize=12, Font=Enum.Font.GothamBold},sidebar), 7)
    tabButtons[name] = button
    track(button.MouseButton1Click:Connect(function() switchPage(name) end))
end
local refreshers = {}
local function refreshLater(fn) refreshers[#refreshers+1] = fn; fn() end
local function heading(parent, text)
    make("TextLabel", {Text=text, Size=UDim2.new(1,-8,0,27), BackgroundTransparency=1, TextColor3=colors.accent, Font=Enum.Font.GothamBold, TextSize=16, TextXAlignment=Enum.TextXAlignment.Left},parent)
end
local function note(parent, text, height)
    return make("TextLabel", {Text=text, Size=UDim2.new(1,-8,0,height or 35), BackgroundTransparency=1, TextWrapped=true, TextColor3=colors.mute, Font=Enum.Font.Gotham, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left},parent)
end
local function row(parent, title)
    local frame = round(make("Frame", {Size=UDim2.new(1,-8,0,42), BackgroundColor3=colors.row, BorderSizePixel=0},parent), 6)
    make("TextLabel", {Text=title, Position=UDim2.fromOffset(10,0), Size=UDim2.new(1,-178,1,0), BackgroundTransparency=1, TextColor3=colors.white, Font=Enum.Font.Gotham, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left},frame)
    return frame
end
local function control(frame, label, width, right)
    return round(make("TextButton", {Text=label, Size=UDim2.fromOffset(width or 125,29), Position=UDim2.new(1,-(right or (width or 125)+7),0.5,-14), BackgroundColor3=colors.panel, BorderSizePixel=0, TextColor3=colors.accent, Font=Enum.Font.GothamBold, TextSize=12},frame),5)
end
local function toggle(parent, text, key)
    local frame = row(parent, text)
    local button = control(frame,"",105,112)
    refreshLater(function() button.Text=settings[key] and "ACTIVADO" or "APAGADO" end)
    track(button.MouseButton1Click:Connect(function()
        settings[key] = not settings[key]
        selected = nil; saveConfig()
        button.Text = settings[key] and "ACTIVADO" or "APAGADO"
    end))
end
local function stepper(parent, text, key, step, minValue, maxValue)
    local frame = row(parent, text)
    local minus = control(frame,"-",28,148)
    local number = make("TextLabel", {Size=UDim2.fromOffset(79,28), Position=UDim2.new(1,-115,0.5,-14), BackgroundTransparency=1, TextColor3=colors.accent, Font=Enum.Font.GothamBold, TextSize=13}, frame)
    local plus = control(frame,"+",28,36)
    local function redraw() number.Text=tostring(settings[key]) end
    refreshLater(redraw)
    local function adjust(delta)
        local n = math.clamp(settings[key] + delta, minValue, maxValue)
        settings[key] = math.floor(n*100+0.5)/100
        redraw(); saveConfig()
    end
    track(minus.MouseButton1Click:Connect(function() adjust(-step) end))
    track(plus.MouseButton1Click:Connect(function() adjust(step) end))
end
local a = page("AIMBOT")
heading(a,"Seguimiento de mira")
toggle(a,"Aimbot activo", "AimEnabled")
local modeRow = row(a,"Activación de seguimiento")
local modeBtn = control(modeRow,"",145,152)
local function redrawMode()
    modeBtn.Text = settings.AimMode == "Toggle" and "TOGGLE (ON/OFF)" or "MANTENER TECLA"
end
refreshLater(redrawMode)
track(modeBtn.MouseButton1Click:Connect(function()
    settings.AimMode = settings.AimMode == "Toggle" and "Hold" or "Toggle"
    isAiming=false; selected=nil; redrawMode(); saveConfig()
end))
local visibilityRow = row(a,"Objetivos tras paredes")
local visibilityBtn = control(visibilityRow,"",145,152)
local function redrawVisibility()
    visibilityBtn.Text = settings.RequireLineOfSight and "SOLO VISIBLES" or "ATRAVÉS PAREDES"
end
refreshLater(redrawVisibility)
track(visibilityBtn.MouseButton1Click:Connect(function()
    settings.RequireLineOfSight = not settings.RequireLineOfSight
    selected=nil; redrawVisibility(); saveConfig()
end))
local bindingRow = row(a,"Tecla de seguimiento")
local bindButton = control(bindingRow,"",145,152)
local function bindLabel() bindButton.Text = rebinding and "Pulsa una tecla..." or settings.AimKey end
refreshLater(bindLabel)
track(bindButton.MouseButton1Click:Connect(function() rebinding = true; isAiming = false; selected = nil; bindLabel() end))
local bodyRow = row(a,"Parte del cuerpo")
local bodyButton = control(bodyRow,"",155,162)
local function bodyLabel() bodyButton.Text = settings.AimPart end
refreshLater(bodyLabel)
track(bodyButton.MouseButton1Click:Connect(function()
    local index=1
    for i, name in ipairs(parts) do if name == settings.AimPart then index = i; break end end
    settings.AimPart = parts[index % #parts + 1]
    selected = nil; bodyLabel(); saveConfig()
end))
stepper(a,"FOV de selección", "AimFOV", 10, 10, 450)
stepper(a,"Smooth (0 = inmediato)", "AimSmooth", 0.05, 0, 0.95)
stepper(a,"Distancia máxima", "MaxDistance", 100, 100, 3000)
toggle(a,"Mostrar círculo FOV", "ShowFOV")
note(a,"MANTENER: funciona mientras pulses la tecla. TOGGLE: una pulsación activa y otra desactiva. Insert abre el menú. Botón lateral: remapea a F6.", 57)
local aimStatus = note(a,"Estado: DESACTIVADO",24)
redrawAimStatus = function()
    aimStatus.Text = "Estado: " .. (isAiming and "ACTIVO" or "DESACTIVADO") .. " / " .. settings.AimMode
end
redrawAimStatus()

local v = page("VISUALES")
heading(v,"Elementos visuales (ESP)")
toggle(v,"ESP general", "ESPEnabled")
toggle(v,"Esqueleto", "SkeletonESP")
toggle(v,"Mostrar nombres", "NamesEnabled")
toggle(v,"Recuadro (BoxESP)", "BoxESP")
toggle(v,"Líneas (Tracers)", "TracerESP")
note(v,"BoxESP y Tracers comienzan apagados, pero puedes activarlos desde aquí.", 36)

local x = page("EXCLUIR")
heading(x,"Jugadores que NO serán seguidos")
toggle(x,"Ignorar mi mismo equipo", "TeamCheck")
note(x,"Los nombres se comparan sin distinguir mayúsculas. Puedes poner usuario o nombre visible.", 35)
local inputRow = round(make("Frame", {Size=UDim2.new(1,-8,0,43), BackgroundColor3=colors.row},x),6)
local usernameBox = round(make("TextBox", {PlaceholderText="Usuario o nombre visible...", Text="", ClearTextOnFocus=false, Size=UDim2.new(1,-160,0,29), Position=UDim2.fromOffset(8,7), TextSize=12, Font=Enum.Font.Gotham, TextColor3=colors.white, PlaceholderColor3=colors.mute, BackgroundColor3=colors.panel},inputRow),5)
local addButton = round(make("TextButton", {Text="AGREGAR", Size=UDim2.fromOffset(135,29), Position=UDim2.new(1,-143,0,7), BackgroundColor3=colors.accent, TextColor3=colors.bg, TextSize=12, Font=Enum.Font.GothamBold}, inputRow),5)
local blacklist = make("Frame", {Size=UDim2.new(1,-8,0,1), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1},x)
make("UIListLayout", {Padding=UDim.new(0,5), SortOrder=Enum.SortOrder.LayoutOrder},blacklist)
local nameConnections = {}
local function refreshNames()
    for _, conn in ipairs(nameConnections) do pcall(function() conn:Disconnect() end) end
    nameConnections = {}
    for _, child in ipairs(blacklist:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
    local list = {}
    for name, enabled in pairs(settings.ExcludedNames) do if enabled then list[#list+1] = name end end
    table.sort(list)
    for _, name in ipairs(list) do
        local frame = row(blacklist, "@" .. name)
        local remove = control(frame,"QUITAR",75,82)
        nameConnections[#nameConnections+1] = remove.MouseButton1Click:Connect(function()
            settings.ExcludedNames[name] = nil
            selected = nil; saveConfig(); refreshNames()
        end)
    end
    if #list == 0 then note(blacklist,"La lista está vacía.",24) end
end
refreshNames()
local function addName()
    local name = cleanName(usernameBox.Text)
    if name == "" then return end
    settings.ExcludedNames[name] = true
    usernameBox.Text = ""
    selected = nil; saveConfig(); refreshNames()
end
track(addButton.MouseButton1Click:Connect(addName))
track(usernameBox.FocusLost:Connect(function(enter) if enter then addName() end end))
note(x,"Equipo excluido por nombre (por defecto: mina). Deja el campo vacío para desactivar esta exclusión.", 36)
local teamRow = round(make("Frame", {Size=UDim2.new(1,-8,0,43), BackgroundColor3=colors.row},x),6)
local teamBox = round(make("TextBox", {PlaceholderText="Nombre de equipo", Text=settings.ExcludedTeam, ClearTextOnFocus=false, Size=UDim2.new(1,-160,0,29), Position=UDim2.fromOffset(8,7), TextSize=12, Font=Enum.Font.Gotham, TextColor3=colors.white, PlaceholderColor3=colors.mute, BackgroundColor3=colors.panel},teamRow),5)
local teamApply = round(make("TextButton", {Text="APLICAR", Size=UDim2.fromOffset(135,29), Position=UDim2.new(1,-143,0,7), BackgroundColor3=colors.accent, TextColor3=colors.bg, TextSize=12, Font=Enum.Font.GothamBold},teamRow),5)
track(teamApply.MouseButton1Click:Connect(function()
    settings.ExcludedTeam = cleanName(teamBox.Text)
    teamBox.Text = settings.ExcludedTeam
    selected = nil; saveConfig()
end))

local s = page("SISTEMA")
heading(s,"Configuración y estado")
note(s,"INSERT: abrir/cerrar. Si Arsenal intercepta la tecla, usa el botón flotante Sof&Mil (esquina superior derecha).",50)
note(s,"Fondo: " .. backgroundState,42)
local photoRow = round(make("Frame", {Size=UDim2.new(1,-8,0,43), BackgroundColor3=colors.row},s),6)
local photoBox = round(make("TextBox", {PlaceholderText="ID de imagen Roblox (opcional)", Text=settings.BackgroundAssetId, ClearTextOnFocus=false, Size=UDim2.new(1,-124,0,29), Position=UDim2.fromOffset(8,7), TextSize=12, Font=Enum.Font.Gotham, TextColor3=colors.white, PlaceholderColor3=colors.mute, BackgroundColor3=colors.panel},photoRow),5)
local photoApply = round(make("TextButton", {Text="APLICAR", Size=UDim2.fromOffset(101,29), Position=UDim2.new(1,-109,0,7), BackgroundColor3=colors.accent, TextColor3=colors.bg, TextSize=12, Font=Enum.Font.GothamBold},photoRow),5)
track(photoApply.MouseButton1Click:Connect(function()
    settings.BackgroundAssetId = tostring(photoBox.Text):gsub("[^%d]", ""):sub(1,25)
    photoBox.Text = settings.BackgroundAssetId
    if settings.BackgroundAssetId ~= "" then background.Image = "rbxassetid://" .. settings.BackgroundAssetId
    else background.Image = backgroundSource() end
    saveConfig()
end))
note(s,"Autocarga tras teletransporte: " .. autoStatus,46)
note(s,"Guardado: SofMil_Config.json (cuando el ejecutor permite writefile/readfile).",44)
local saveRow = row(s,"Guardar configuración")
local saveButton = control(saveRow,"GUARDAR",105,112)
local status = note(s,"",40)
track(saveButton.MouseButton1Click:Connect(function()
    status.Text = saveConfig() and "Configuración guardada." or "El ejecutor no permite guardar archivos."
end))
local unloadRow = row(s,"Cerrar y descargar script")
local unloadButton = control(unloadRow,"DESCARGAR",110,117)
track(unloadButton.MouseButton1Click:Connect(function() if type(_G.KD_ESP_UNLOAD)=="function" then _G.KD_ESP_UNLOAD() end end))

switchPage("AIMBOT")
local function setMenuVisible(value)
    menuOpen = value
    window.Visible = value
    reopen.Visible = not value
    if settings.AimMode == "Hold" then isAiming = false end
    selected = nil
    rebinding = false
    bindLabel()
    redrawAimStatus()
end
track(close.MouseButton1Click:Connect(function() setMenuVisible(false) end))
track(reopen.MouseButton1Click:Connect(function() setMenuVisible(true) end))
-- Usa BindActionAtPriority para priorizar Insert y UIS de respaldo.
local actionName = "SofMil_OpenClose_Insert"
local lastInsert = -10
local function toggleInsert()
    if rebinding or UIS:GetFocusedTextBox() then return end
    local now = os.clock()
    if now - lastInsert < 0.18 then return end
    lastInsert = now
    setMenuVisible(not menuOpen)
end
pcall(function()
    CAS:UnbindAction(actionName)
    CAS:BindActionAtPriority(actionName,function(_, state)
        if state == Enum.UserInputState.Begin then toggleInsert() end
        return Enum.ContextActionResult.Sink
    end,false,10000,Enum.KeyCode.Insert)
end)

-- Arrastrar desde la cabecera
local dragging, dragStart, startPosition = false, nil, nil
track(header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging=true; dragStart=input.Position; startPosition=window.Position
    end
end))
track(UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging=false end
end))
track(UIS.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position-dragStart
        window.Position = UDim2.new(startPosition.X.Scale,startPosition.X.Offset+delta.X,startPosition.Y.Scale,startPosition.Y.Offset+delta.Y)
    end
end))

track(UIS.InputBegan:Connect(function(input, processed)
    if rebinding then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Escape then
                rebinding = false
            elseif input.KeyCode ~= Enum.KeyCode.Insert and input.KeyCode ~= Enum.KeyCode.Unknown then
                settings.AimKey = input.KeyCode.Name
                isAiming=false; selected=nil; rebinding=false; saveConfig()
            end
            bindLabel()
        end
        return
    end
    if input.KeyCode == Enum.KeyCode.Insert then
        toggleInsert() -- fallback si el juego interceptó ContextActionService
        return
    end
    if processed or menuOpen or UIS:GetFocusedTextBox() then return end
    if input.KeyCode.Name == settings.AimKey then
        if settings.AimMode == "Toggle" then isAiming = not isAiming
        else isAiming = true end
        selected = nil
        redrawAimStatus()
    end
end))
track(UIS.InputEnded:Connect(function(input)
    if input.KeyCode.Name == settings.AimKey and settings.AimMode == "Hold" then
        isAiming=false; selected=nil; redrawAimStatus()
    end
end))
track(UIS.WindowFocusReleased:Connect(function()
    if settings.AimMode == "Hold" then isAiming=false end
    selected=nil; dragging=false; redrawAimStatus()
end))
for _, other in ipairs(Players:GetPlayers()) do createVisual(other) end
track(Players.PlayerAdded:Connect(createVisual))
track(Players.PlayerRemoving:Connect(function(other) removeVisual(other); if selected == other then selected=nil end end))
local renderID = "SofMil_Menu_Render"
RunService:UnbindFromRenderStep(renderID)
RunService:BindToRenderStep(renderID, Enum.RenderPriority.Camera.Value+1, update)
_G.KD_ESP_UNLOAD = function()
    isAiming=false; selected=nil
    pcall(function() CAS:UnbindAction(actionName) end)
    RunService:UnbindFromRenderStep(renderID)
    for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
    for _, conn in ipairs(nameConnections) do pcall(function() conn:Disconnect() end) end
    for other in pairs(visuals) do removeVisual(other) end
    for _, object in ipairs(drawings) do pcall(function() object:Remove() end) end
    pcall(function() screen:Destroy() end)
    _G.KD_ESP_UNLOAD=nil
end
print("Sof&Mil | INSERT | " .. settings.AimMode .. " / " .. settings.AimKey .. " | cargado")

]=====]
if type(writefile) == "function" then
    local ok, err = pcall(writefile, "SofMil_Menu.lua", SOURCE)
    if not ok then warn("Sof&Mil: guardado no disponible: " .. tostring(err)) end
end
local compiled, err = loadstring(SOURCE)
if compiled then compiled() else warn("Sof&Mil: error de sintaxis: " .. tostring(err)) end
