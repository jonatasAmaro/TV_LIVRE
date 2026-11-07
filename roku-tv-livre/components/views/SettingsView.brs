sub init()
    m.options = m.top.findNode("options")
    m.detailTitle = m.top.findNode("detailTitle")
    m.detailBody = m.top.findNode("detailBody")
    m.result = m.top.findNode("result")
    m.hint = m.top.findNode("hint")

    m.items = [
        { id: "about", title: "Sobre o TV Livre", hint: "" },
        { id: "update", title: "Verificar atualização", hint: "OK verifica agora" },
        { id: "anime", title: "Atualizar episódios de anime", hint: "OK procura episódios novos" },
        { id: "clearRecent", title: "Limpar ""Continuar assistindo""", hint: "OK apaga (pede confirmação)" },
        { id: "clearFavs", title: "Limpar ""Minha Lista""", hint: "OK apaga (pede confirmação)" }
    ]
    root = CreateObject("roSGNode", "ContentNode")
    for each it in m.items
        n = root.createChild("ContentNode")
        n.title = "   " + it.title
    end for
    m.options.content = root

    m.options.observeField("itemFocused", "onFocused")
    m.options.observeField("itemSelected", "onSelected")
    m.top.observeField("focusedChild", "onFocusChange")
    m.top.observeField("active", "onActive")
    m.top.observeField("config", "onActive")
end sub

sub onFocusChange()
    if m.top.hasFocus() then m.options.setFocus(true)
end sub

sub onActive()
    showDetail(m.options.itemFocused)
end sub

sub onFocused()
    m.result.text = ""
    showDetail(m.options.itemFocused)
end sub

sub showDetail(i as Integer)
    if m.top.config = invalid then return
    if i < 0 or i >= m.items.Count() then i = 0
    it = m.items[i]
    m.detailTitle.text = it.title
    m.hint.text = it.hint
    if it.id = "about"
        m.detailBody.text = aboutText()
    else if it.id = "update"
        url = To_Str(m.top.config.versionUrl)
        if url = ""
            m.detailBody.text = "Versão instalada: " + appVersion() + Chr(10) + Chr(10) + "Nenhum endereço de atualização configurado ainda (campo versionUrl em config/catalog.json). As atualizações são instaladas pelo deploy.ps1 no computador."
        else
            m.detailBody.text = "Versão instalada: " + appVersion() + Chr(10) + "Consulta: " + url
        end if
    else if it.id = "anime"
        m.detailBody.text = "Procura agora os episódios lançados (calendário AniList). O número de episódios novos aparece na aba ANIMES. O app também verifica sozinho a cada 6 horas."
    else if it.id = "clearRecent"
        m.detailBody.text = "Apaga o histórico usado em ""Continuar assistindo"" (" + Recent_List().Count().ToStr() + " itens)."
    else if it.id = "clearFavs"
        m.detailBody.text = "Remove todos os itens da Minha Lista (" + Fav_List().Count().ToStr() + " itens)."
    end if
end sub

function appVersion() as String
    return CreateObject("roAppInfo").GetVersion()
end function

function aboutText() as String
    di = CreateObject("roDeviceInfo")
    os = di.GetOSVersion()
    osText = To_Str(os.major) + "." + To_Str(os.minor) + "." + To_Str(os.revision)
    ips = []
    for each ip in di.GetIPAddrs().Items()
        ips.Push(ip.value)
    end for
    channels = 0
    for each s in m.top.config.sections
        if s.channels <> invalid then channels = channels + s.channels.Count()
    end for
    lines = [
        "Versão do app: " + appVersion(),
        "TV: " + di.GetModelDisplayName() + " (" + di.GetModel() + ")",
        "Roku OS: " + osText,
        "Endereço na rede: " + ips.Join(", "),
        "Canais e atalhos configurados: " + channels.ToStr(),
        catalogText(),
        "",
        "Conteúdo de fontes oficiais e gratuitas: emissoras públicas e abertas, Internet Archive (domínio público), Blender, AniList e YouTube."
    ]
    return lines.Join(Chr(10))
end function

' "Catálogo: 2026110701 (online) · sincronizado sex 07/11 14:32 (atualizado)"
function catalogText() as String
    cfg = Cfg_Load()
    ver = To_Str(cfg.catalogVersion)
    if ver = "" then ver = "sem versão"
    line = "Catálogo: " + ver + " (" + To_Str(cfg.catalogSource) + ")"
    sync = Store_Get("catalogSync", invalid)
    if sync <> invalid and To_Int(sync.at) > 0
        names = { updated: "atualizado", same: "sem mudanças", error: "falhou", off: "desligado" }
        res = To_Str(sync.result)
        if names[res] <> invalid then res = names[res]
        line = line + Chr(10) + "Última sincronização: " + Fmt_LocalDate(To_Int(sync.at)) + " (" + res + ")"
    end if
    return line
end function

sub onSelected()
    it = m.items[m.options.itemSelected]
    if it.id = "update"
        checkUpdate()
    else if it.id = "anime"
        m.top.navigate = { to: "refreshAnime" }
        m.result.text = "Procurando episódios novos... o número aparece na aba ANIMES."
    else if it.id = "clearRecent"
        confirm("Limpar ""Continuar assistindo""?", "clearRecent")
    else if it.id = "clearFavs"
        confirm("Limpar a Minha Lista?", "clearFavs")
    end if
end sub

sub checkUpdate()
    url = To_Str(m.top.config.versionUrl)
    if url = ""
        m.result.text = "Sem endereço de atualização configurado."
        return
    end if
    m.result.text = "Verificando..."
    m.updTask = CreateObject("roSGNode", "HttpJsonTask")
    m.updTask.url = url
    m.updTask.observeField("result", "onUpdateResult")
    m.updTask.control = "run"
end sub

sub onUpdateResult()
    latest = To_Str(m.updTask.result.version)
    if latest = ""
        m.result.text = "Não consegui consultar a atualização."
    else if Version_Compare(latest, appVersion()) > 0
        m.result.text = "Nova versão disponível: " + latest + ". Instale pelo deploy.ps1."
    else
        m.result.text = "O app já está na versão mais recente."
    end if
end sub

sub confirm(title as String, action as String)
    m.pending = action
    m.dlg = CreateObject("roSGNode", "StandardMessageDialog")
    m.dlg.title = title
    m.dlg.message = ["Essa ação não pode ser desfeita."]
    m.dlg.buttons = ["Cancelar", "Limpar"]
    m.dlg.observeField("buttonSelected", "onConfirm")
    m.dlg.observeField("wasClosed", "onDialogClosed")
    m.top.getScene().dialog = m.dlg
end sub

sub onConfirm()
    if m.dlg.buttonSelected = 1
        if m.pending = "clearRecent"
            Store_Set("recent", [])
            m.result.text = """Continuar assistindo"" foi limpo."
        else if m.pending = "clearFavs"
            Store_Set("favorites", [])
            m.result.text = "Minha Lista foi limpa."
        end if
        showDetail(m.options.itemFocused)
    end if
    m.dlg.close = true
end sub

sub onDialogClosed()
    m.options.setFocus(true)
end sub
