-- =================================================================
-- SCRIPT: NINJA POBRE HUB (AGRICULTURA E AMIGOS)
-- =================================================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

local NOME_FICHEIRO_CONFIG = "NinjaPobreHub_Config.json"
local ConfigMemoriaSessao = nil

local Config = {
    AutoPlantacao = false,
    AutoTabua = false,
    AutoLiquido = false,
    TempoColeta = 4.5,
    TempoEspera = 1.8,
    DistanciaRe = 8,
    PausaManobra = 0.45,
    RaioPrompt = 32,
    RaioPlanks = 40
}

local Posicoes = {
    Tabua     = { Serraria = nil, Empresa = nil, Marca = nil },
    Plantacao = { Empresa = nil },
    Liquido   = { Empresa = nil }
}

-- =================================================================
-- 1. GUARDAR E CARREGAR CONFIGURAÇÃO
-- =================================================================

local function serializarCFrame(cf)
    if not cf then return nil end
    return { cf:GetComponents() }
end

local function desserializarCFrame(arr)
    if typeof(arr) == "table" and #arr == 12 then
        return CFrame.new(unpack(arr))
    end
    return nil
end

local function montarPayloadConfig()
    return {
        Hub = "Ninja Pobre Hub",
        Config = {
            TempoColeta = Config.TempoColeta,
            TempoEspera = Config.TempoEspera,
            DistanciaRe = Config.DistanciaRe,
            PausaManobra = Config.PausaManobra,
            RaioPrompt = Config.RaioPrompt,
            RaioPlanks = Config.RaioPlanks
        },
        Posicoes = {
            Tabua = {
                Serraria = serializarCFrame(Posicoes.Tabua.Serraria),
                Empresa  = serializarCFrame(Posicoes.Tabua.Empresa),
                Marca    = serializarCFrame(Posicoes.Tabua.Marca)
            },
            Plantacao = {
                Empresa = serializarCFrame(Posicoes.Plantacao.Empresa)
            },
            Liquido = {
                Empresa = serializarCFrame(Posicoes.Liquido.Empresa)
            }
        }
    }
end

local function aplicarPayloadConfig(dados)
    if typeof(dados) ~= "table" then return false end

    if typeof(dados.Config) == "table" then
        if tonumber(dados.Config.TempoColeta) then Config.TempoColeta = tonumber(dados.Config.TempoColeta) end
        if tonumber(dados.Config.TempoEspera) then Config.TempoEspera = tonumber(dados.Config.TempoEspera) end
        if tonumber(dados.Config.DistanciaRe) then Config.DistanciaRe = tonumber(dados.Config.DistanciaRe) end
        if tonumber(dados.Config.PausaManobra) then Config.PausaManobra = tonumber(dados.Config.PausaManobra) end
        if tonumber(dados.Config.RaioPrompt) then Config.RaioPrompt = tonumber(dados.Config.RaioPrompt) end
        if tonumber(dados.Config.RaioPlanks) then Config.RaioPlanks = tonumber(dados.Config.RaioPlanks) end
    end

    if typeof(dados.Posicoes) == "table" then
        if typeof(dados.Posicoes.Tabua) == "table" then
            Posicoes.Tabua.Serraria = desserializarCFrame(dados.Posicoes.Tabua.Serraria) or Posicoes.Tabua.Serraria
            Posicoes.Tabua.Empresa  = desserializarCFrame(dados.Posicoes.Tabua.Empresa) or Posicoes.Tabua.Empresa
            Posicoes.Tabua.Marca    = desserializarCFrame(dados.Posicoes.Tabua.Marca) or Posicoes.Tabua.Marca
        end
        if typeof(dados.Posicoes.Plantacao) == "table" then
            Posicoes.Plantacao.Empresa = desserializarCFrame(dados.Posicoes.Plantacao.Empresa) or Posicoes.Plantacao.Empresa
        end
        if typeof(dados.Posicoes.Liquido) == "table" then
            Posicoes.Liquido.Empresa = desserializarCFrame(dados.Posicoes.Liquido.Empresa) or Posicoes.Liquido.Empresa
        end
    end

    return true
end

local function guardarConfiguracao()
    local payload = montarPayloadConfig()
    ConfigMemoriaSessao = HttpService:JSONDecode(HttpService:JSONEncode(payload))

    if typeof(writefile) == "function" then
        local ok = pcall(function()
            writefile(NOME_FICHEIRO_CONFIG, HttpService:JSONEncode(payload))
        end)
        if ok then
            return true, "Guardado em ficheiro!"
        end
    end

    return true, "Guardado na sessão!"
end

local function carregarConfiguracao()
    if typeof(isfile) == "function" and typeof(readfile) == "function" then
        local existe = false
        pcall(function() existe = isfile(NOME_FICHEIRO_CONFIG) end)
        if existe then
            local ok, conteudo = pcall(function() return readfile(NOME_FICHEIRO_CONFIG) end)
            if ok and conteudo then
                local decOk, dados = pcall(function() return HttpService:JSONDecode(conteudo) end)
                if decOk and aplicarPayloadConfig(dados) then
                    return true, "Config carregada!"
                end
            end
        end
    end

    if ConfigMemoriaSessao and aplicarPayloadConfig(ConfigMemoriaSessao) then
        return true, "Config da sessão carregada!"
    end

    return false, "Sem config guardada"
end

local function limparConfiguracao()
    Posicoes.Tabua.Serraria = nil
    Posicoes.Tabua.Empresa = nil
    Posicoes.Tabua.Marca = nil
    Posicoes.Plantacao.Empresa = nil
    Posicoes.Liquido.Empresa = nil
    ConfigMemoriaSessao = nil

    if typeof(isfile) == "function" and typeof(delfile) == "function" then
        pcall(function()
            if isfile(NOME_FICHEIRO_CONFIG) then
                delfile(NOME_FICHEIRO_CONFIG)
            end
        end)
    end
end

-- =================================================================
-- 2. FUNÇÕES DE MOVIMENTO, MANOBRA E AUTOMAÇÃO
-- =================================================================

local function zerarFisica(part)
    if part and part:IsA("BasePart") then
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
    end
end

local function obterAlvoDeMovimento()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local hrp = character and character:FindFirstChild("HumanoidRootPart")

    if not character or not humanoid or not hrp then
        return nil, nil
    end

    if humanoid.SeatPart then
        local seat = humanoid.SeatPart
        local vehicleModel = seat:FindFirstAncestorOfClass("Model")
        if vehicleModel and vehicleModel.PrimaryPart then
            return vehicleModel.PrimaryPart, vehicleModel
        elseif vehicleModel then
            return seat, vehicleModel
        end
        return seat, nil
    end

    return hrp, nil
end

local function obterCFrameAtual()
    local alvoPart, vehicleModel = obterAlvoDeMovimento()
    if vehicleModel then
        return vehicleModel:GetPivot()
    elseif alvoPart then
        return alvoPart.CFrame
    end
    return nil
end

local function aplicarCFrameEstavel(cf)
    local alvoPart, vehicleModel = obterAlvoDeMovimento()
    if not alvoPart or not cf then return end

    local pos = cf.Position
    local look = cf.LookVector
    local flatLook = Vector3.new(look.X, 0, look.Z)
    if flatLook.Magnitude < 0.001 then
        flatLook = Vector3.new(0, 0, -1)
    end
    local cframeEstavel = CFrame.lookAt(pos, pos + flatLook.Unit)

    if vehicleModel then
        zerarFisica(alvoPart)
        for _, desc in ipairs(vehicleModel:GetDescendants()) do
            if desc:IsA("BasePart") then
                zerarFisica(desc)
                desc.CanTouch = true
            end
        end
        vehicleModel:PivotTo(cframeEstavel)
    else
        zerarFisica(alvoPart)
        alvoPart.CanTouch = true
        alvoPart.CFrame = cframeEstavel
    end
end

local function deslocarRelativo(distancia)
    local cfAtual = obterCFrameAtual()
    if not cfAtual then return end

    local pos = cfAtual.Position
    local look = cfAtual.LookVector
    local flatLook = Vector3.new(look.X, 0, look.Z)
    if flatLook.Magnitude < 0.001 then
        flatLook = Vector3.new(0, 0, -1)
    end
    flatLook = flatLook.Unit

    local novaPos = pos + (flatLook * distancia)
    aplicarCFrameEstavel(CFrame.lookAt(novaPos, novaPos + flatLook))
end

local function clicarPosicaoTela(x, y)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
    end)
end

local function ehNomePlanks(nome)
    local n = string.lower(tostring(nome or ""))
    return string.find(n, "planks", 1, true) ~= nil
        or string.find(n, "m2 planks", 1, true) ~= nil
        or string.find(n, "m2_planks", 1, true) ~= nil
end

local function acionarPromptsEClickDetectors(refPos, raio, priorizarPlanks)
    for _, obj in ipairs(workspace:GetDescendants()) do
        local parent = obj.Parent
        local parentPos = nil

        if parent and parent:IsA("BasePart") then
            parentPos = parent.Position
        elseif parent and parent:IsA("Model") then
            if parent.PrimaryPart then
                parentPos = parent.PrimaryPart.Position
            else
                local ok, pivot = pcall(function() return parent:GetPivot() end)
                if ok then parentPos = pivot.Position end
            end
        end

        if parentPos then
            local ehPlanks = priorizarPlanks and (
                ehNomePlanks(obj.Name)
                or (parent and (ehNomePlanks(parent.Name) or (parent.Parent and ehNomePlanks(parent.Parent.Name))))
            )
            local raioEfetivo = ehPlanks and math.max(raio, Config.RaioPlanks) or raio

            if (refPos - parentPos).Magnitude <= raioEfetivo then
                if obj:IsA("ProximityPrompt") and obj.Enabled then
                    if typeof(fireproximityprompt) == "function" then
                        pcall(function()
                            fireproximityprompt(obj)
                        end)
                    end
                elseif obj:IsA("ClickDetector") then
                    if typeof(fireclickdetector) == "function" then
                        pcall(function()
                            fireclickdetector(obj)
                        end)
                    end
                end
            end
        end
    end
end

local function estaVisivelNaTela(guiObj)
    local atual = guiObj
    while atual and atual ~= LocalPlayer:FindFirstChild("PlayerGui") do
        if atual:IsA("GuiObject") and not atual.Visible then
            return false
        end
        if atual:IsA("ScreenGui") and not atual.Enabled then
            return false
        end
        atual = atual.Parent
    end
    return true
end

local function acionarBotoesAcaoNaTela(modo)
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end

    local palavrasChave = (modo == "Coleta")
        and { "m2 planks", "planks", "pegar", "coletar", "carregar", "serrar", "cortar", "madeira", "tabua", "tábua", "get", "take", "load" }
        or  { "colocar", "entregar", "depositar", "deixar", "descarregar", "empresa", "enviar", "drop", "place" }

    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Name ~= "NinjaPobreHubGUI" and gui.Enabled then
            for _, desc in ipairs(gui:GetDescendants()) do
                if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Active and estaVisivelNaTela(desc) then
                    local texto = string.lower((desc:IsA("TextButton") and desc.Text or "") .. " " .. desc.Name)
                    local match = false
                    for _, palavra in ipairs(palavrasChave) do
                        if string.find(texto, palavra, 1, true) then
                            match = true
                            break
                        end
                    end

                    if match then
                        if typeof(getconnections) == "function" then
                            for _, conn in ipairs(getconnections(desc.MouseButton1Click) or {}) do
                                pcall(function() conn:Fire() end)
                            end
                            for _, conn in ipairs(getconnections(desc.Activated) or {}) do
                                pcall(function() conn:Fire() end)
                            end
                        end

                        local absPos = desc.AbsolutePosition
                        local absSize = desc.AbsoluteSize
                        if absSize.X > 2 and absSize.Y > 2 then
                            clicarPosicaoTela(absPos.X + absSize.X * 0.5, absPos.Y + absSize.Y * 0.5)
                        end
                    end
                end
            end
        end
    end
end

local function acionarAcoesAtuais(modo)
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local alvoPart = obterAlvoDeMovimento()
    local refPos = (hrp and hrp.Position) or (alvoPart and alvoPart.Position)
    if refPos then
        acionarPromptsEClickDetectors(refPos, Config.RaioPrompt, modo == "Coleta")
    end
    acionarBotoesAcaoNaTela(modo)
end

local function moverParaDestino(cframeDestino, modo)
    if not cframeDestino then return end
    aplicarCFrameEstavel(cframeDestino)
    task.wait(0.25)
    acionarAcoesAtuais(modo)
end

local function coletarAutomaticoNaSerraria(pontoBase)
    local fim = os.clock() + Config.TempoColeta
    local passo = 0
    while Config.AutoTabua and os.clock() < fim do
        passo += 1
        acionarAcoesAtuais("Coleta")

        if pontoBase then
            if passo % 3 == 1 then
                aplicarCFrameEstavel(pontoBase)
            elseif passo % 3 == 2 then
                deslocarRelativo(2)
            else
                deslocarRelativo(-2)
            end
        end

        task.wait(0.5)
    end

    if pontoBase then
        aplicarCFrameEstavel(pontoBase)
    end
end

local function executarCicloTabua()
    local pontos = Posicoes.Tabua

    if Config.AutoTabua and pontos.Serraria then
        moverParaDestino(pontos.Serraria, "Coleta")
        coletarAutomaticoNaSerraria(pontos.Serraria)
        task.wait(0.35)
    end

    if Config.AutoTabua and pontos.Empresa then
        moverParaDestino(pontos.Empresa, "Entrega")
        task.wait(Config.PausaManobra)

        deslocarRelativo(-math.abs(Config.DistanciaRe))
        task.wait(Config.PausaManobra)
        acionarAcoesAtuais("Entrega")

        if Config.AutoTabua and pontos.Marca then
            moverParaDestino(pontos.Marca, "Entrega")
            task.wait(Config.PausaManobra)
            acionarAcoesAtuais("Entrega")
        end

        task.wait(Config.TempoEspera * 0.5)
    end
end

local function executarApenasEmpresa(categoriaKey, configKey)
    local pontoEmpresa = Posicoes[categoriaKey] and Posicoes[categoriaKey].Empresa
    if Config[configKey] and pontoEmpresa then
        moverParaDestino(pontoEmpresa, "Entrega")
        task.wait(Config.TempoEspera * 0.5)
        acionarAcoesAtuais("Entrega")
        task.wait(Config.TempoEspera * 0.5)
    end
end

-- =================================================================
-- 3. LOOPS DE AUTOMAÇÃO CONTÍNUA
-- =================================================================

task.spawn(function()
    while true do
        if Config.AutoTabua then
            pcall(executarCicloTabua)
            task.wait(0.4)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while true do
        if Config.AutoPlantacao then
            pcall(function() executarApenasEmpresa("Plantacao", "AutoPlantacao") end)
            task.wait(0.35)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while true do
        if Config.AutoLiquido then
            pcall(function() executarApenasEmpresa("Liquido", "AutoLiquido") end)
            task.wait(0.35)
        else
            task.wait(0.5)
        end
    end
end)

-- =================================================================
-- 4. INTERFACE GRÁFICA — NINJA POBRE HUB
-- =================================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NinjaPobreHubGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local larguraAberta = 436
local alturaAberta = 252
local alturaBarra = 36
local alturaAbas = 30

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, larguraAberta, 0, alturaAberta)
Frame.Position = UDim2.new(0.5, -larguraAberta / 2, 0.22, 0)
Frame.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Draggable = true
Frame.ClipsDescendants = true
Frame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = Frame

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, alturaBarra)
TopBar.BackgroundColor3 = Color3.fromRGB(42, 42, 52)
TopBar.BorderSizePixel = 0
TopBar.Parent = Frame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 8)
TopCorner.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Ninja Pobre Hub"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.Parent = TopBar

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 30, 0, 26)
MinimizeBtn.Position = UDim2.new(1, -38, 0.5, -13)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 86)
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 16
MinimizeBtn.Parent = TopBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinimizeBtn

local BodyFrame = Instance.new("Frame")
BodyFrame.Size = UDim2.new(1, 0, 1, -alturaBarra)
BodyFrame.Position = UDim2.new(0, 0, 0, alturaBarra)
BodyFrame.BackgroundTransparency = 1
BodyFrame.ClipsDescendants = false
BodyFrame.Parent = Frame

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -20, 0, alturaAbas)
TabBar.Position = UDim2.new(0, 10, 0, 6)
TabBar.BackgroundColor3 = Color3.fromRGB(36, 36, 44)
TabBar.BorderSizePixel = 0
TabBar.Parent = BodyFrame

local TabBarCorner = Instance.new("UICorner")
TabBarCorner.CornerRadius = UDim.new(0, 6)
TabBarCorner.Parent = TabBar

local TabFarmBtn = Instance.new("TextButton")
TabFarmBtn.Size = UDim2.new(0.5, -4, 1, -4)
TabFarmBtn.Position = UDim2.new(0, 2, 0, 2)
TabFarmBtn.BackgroundColor3 = Color3.fromRGB(65, 115, 195)
TabFarmBtn.Text = "Farm"
TabFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TabFarmBtn.Font = Enum.Font.GothamBold
TabFarmBtn.TextSize = 12
TabFarmBtn.Parent = TabBar

local tfCorner = Instance.new("UICorner")
tfCorner.CornerRadius = UDim.new(0, 5)
tfCorner.Parent = TabFarmBtn

local TabConfigBtn = Instance.new("TextButton")
TabConfigBtn.Size = UDim2.new(0.5, -4, 1, -4)
TabConfigBtn.Position = UDim2.new(0.5, 2, 0, 2)
TabConfigBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 62)
TabConfigBtn.Text = "Salvar Config"
TabConfigBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
TabConfigBtn.Font = Enum.Font.GothamBold
TabConfigBtn.TextSize = 12
TabConfigBtn.Parent = TabBar

local tcCorner = Instance.new("UICorner")
tcCorner.CornerRadius = UDim.new(0, 5)
tcCorner.Parent = TabConfigBtn

local FarmPage = Instance.new("Frame")
FarmPage.Size = UDim2.new(1, 0, 1, -(alturaAbas + 10))
FarmPage.Position = UDim2.new(0, 0, 0, alturaAbas + 10)
FarmPage.BackgroundTransparency = 1
FarmPa
