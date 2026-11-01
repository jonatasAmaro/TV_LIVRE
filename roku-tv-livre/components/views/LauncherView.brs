' Start screen. m.items is the carousel in display order, one entry per card:
' { key, kind, title, appId, icon, removable }. kind: "launch" (ECP app or TV input),
' "live" (TV ao vivo with inline preview), "tvlivre", "inputs", "store".
' m.idx = -1 is the gear. Card order and hidden apps
' are kept in the registry ("launcherOrder", "launcherHidden").
'
' Modes: "row" (browsing carousel), "livePreview" (video playing + menu visible),
' "liveFullscreen" (fullscreen, menu hidden), "inputs", "menu", "move".
sub init()
    m.cardW = 264
    m.cardH = 198
    m.step = 294
    m.trackX = 240
    m.trackY = 834
    m.viewW = 1860 - m.trackX

    m.track = m.top.findNode("track")
    m.title = m.top.findNode("title")
    m.hint = m.top.findNode("hint")
    m.gearRing = m.top.findNode("gearRing")
    m.inputs = m.top.findNode("inputs")
    m.inputRow = m.top.findNode("inputRow")
    m.menu = m.top.findNode("menu")
    m.menuBg = m.top.findNode("menuBg")
    m.menuSel = m.top.findNode("menuSel")
    m.menuItems = m.top.findNode("menuItems")
    m.moveHint = m.top.findNode("moveHint")
    m.arrowLeft = m.top.findNode("arrowLeft")
    m.arrowRight = m.top.findNode("arrowRight")
    m.scrollAnim = m.top.findNode("scrollAnim")
    m.scrollInterp = m.top.findNode("scrollInterp")
    m.clock = m.top.findNode("clock")
    m.date = m.top.findNode("date")
    m.holdTimer = m.top.findNode("holdTimer")
    m.holdTimer.observeField("fire", "onHold")
    clockTimer = m.top.findNode("clockTimer")
    clockTimer.observeField("fire", "updateClock")
    clockTimer.control = "start"
    updateClock()

    m.wallpaper = m.top.findNode("wallpaper")
    m.bgVideo = m.top.findNode("bgVideo")
    m.shade = m.top.findNode("shade")
    m.menuBand = m.top.findNode("menuBand")
    m.liveOsd = m.top.findNode("liveOsd")
    m.liveOsdName = m.top.findNode("liveOsdName")
    m.liveOsdInfo = m.top.findNode("liveOsdInfo")
    m.liveStatus = m.top.findNode("liveStatus")
    m.liveZapTimer = m.top.findNode("liveZapTimer")
    m.liveZapTimer.observeField("fire", "onLiveZapTimer")
    m.liveOsdTimer = m.top.findNode("liveOsdTimer")
    m.liveOsdTimer.observeField("fire", "hideLiveOsd")
    m.bgVideo.observeField("state", "onBgVideoState")

    m.selfId = CreateObject("roAppInfo").GetID()
    m.youTubeId = "837"
    migrateOrder()
    m.apps = []
    m.items = []
    m.cards = []
    m.inputList = []
    m.idx = 0
    m.mode = "row"
    m.offset = 0
    m.okDown = false
    m.hiddenCount = 0

    m.liveChannels = []
    m.liveChIndex = 0
    m.livePlayingIndex = -1
    m.catalogConfig = invalid

    loadCatalog()
    rebuild()
    loadApps()
end sub

sub updateClock()
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    m.clock.text = Pad2(dt.GetHours()) + ":" + Pad2(dt.GetMinutes())
    m.date.text = Fmt_LongDate(dt)
end sub

' ---------- Catalog loading ----------

sub loadCatalog()
    m.catalogConfig = Cfg_Load()
    if m.catalogConfig <> invalid and m.catalogConfig.sections <> invalid
        for each s in m.catalogConfig.sections
            if s.kind = "live" and s.channels <> invalid
                m.liveChannels = s.channels
                exit for
            end if
        end for
    end if
end sub

' ---------- Card list ----------

sub loadApps()
    m.appsTask = CreateObject("roSGNode", "LauncherTask")
    m.appsTask.mode = "apps"
    m.appsTask.observeField("result", "onApps")
    m.appsTask.control = "run"
end sub

sub onApps()
    m.apps = m.appsTask.result.apps
    m.inputList = []
    for each a in m.apps
        if a.type = "tvin" and a.id <> "tvinput.dtv" then m.inputList.Push(a)
    end for
    rebuild()
end sub

function findApp(id as String) as Dynamic
    for each a in m.apps
        if a.id = id then return a
    end for
    return invalid
end function

function allItems() as Object
    list = [
        { key: "live", kind: "live", title: "TV ao vivo", appId: "", icon: "pkg:/images/icon_fhd.png", removable: false }
        { key: "inputs", kind: "inputs", title: "Conexões", appId: "", icon: "pkg:/images/card_inputs.png", removable: false }
    ]
    yt = findApp(m.youTubeId)
    if yt <> invalid then list.Push({ key: "app:" + yt.id, kind: "launch", title: yt.name, appId: yt.id, icon: yt.icon, removable: true })
    for each a in m.apps
        if a.type = "appl" and a.id <> m.selfId and a.id <> m.youTubeId
            list.Push({ key: "app:" + a.id, kind: "launch", title: a.name, appId: a.id, icon: a.icon, removable: true })
        end if
    end for
    list.Push({ key: "store", kind: "store", title: "Central de Apps", appId: "", icon: "pkg:/images/card_store.png", removable: false })
    return list
end function

sub migrateOrder()
    if To_Int(Store_Get("launcherDefaults", 1)) >= 2 then return
    yt = "app:" + m.youTubeId
    out = []
    for each k in Store_Get("launcherOrder", [])
        if k <> yt then out.Push(k)
        if k = "inputs" then out.Push(yt)
    end for
    if out.Count() > 0 then Store_Set("launcherOrder", out)
    Store_Set("launcherDefaults", 2)
end sub

function inList(list as Object, value as String) as Boolean
    for each v in list
        if v = value then return true
    end for
    return false
end function

sub rebuild()
    focusKey = ""
    if m.idx >= 0 and m.idx < m.items.Count() then focusKey = m.items[m.idx].key

    hidden = Store_Get("launcherHidden", [])
    m.hiddenCount = 0
    byKey = {}
    defaults = []
    for each it in allItems()
        if inList(hidden, it.key)
            m.hiddenCount++
        else
            defaults.Push(it)
            byKey[it.key] = it
        end if
    end for
    ordered = []
    used = {}
    for each k in Store_Get("launcherOrder", [])
        it = byKey[k]
        if it <> invalid and used[k] = invalid
            ordered.Push(it)
            used[k] = true
        end if
    end for
    for each it in defaults
        if used[it.key] = invalid
            n = ordered.Count()
            if n > 0 and ordered[n - 1].key = "store"
                last = ordered.Pop()
                ordered.Push(it)
                ordered.Push(last)
            else
                ordered.Push(it)
            end if
            used[it.key] = true
        end if
    end for
    m.items = ordered

    m.track.removeChildrenIndex(m.track.getChildCount(), 0)
    m.cards = []
    for each it in m.items
        m.cards.Push(makeCard(m.track, it, m.cardW, m.cardH))
    end for
    layoutCards()

    idx = m.idx
    for i = 0 to m.items.Count() - 1
        if m.items[i].key = focusKey then idx = i
    end for
    if idx >= m.items.Count() then idx = m.items.Count() - 1
    setIndex(idx, false)
end sub

function makeCard(parent as Object, it as Object, w as Integer, h as Integer) as Object
    g = parent.createChild("Group")
    g.scaleRotateCenter = [w / 2, h / 2]
    bg = g.createChild("Rectangle")
    bg.width = w
    bg.height = h
    bg.color = "0x1B2233FF"
    lbl = g.createChild("Label")
    font = CreateObject("roSGNode", "Font")
    font.uri = "font:BoldSystemFontFile"
    font.size = 28
    lbl.font = font
    lbl.text = it.title
    lbl.color = "0xFFFFFFFF"
    lbl.translation = [12, 0]
    lbl.width = w - 24
    lbl.height = h
    lbl.wrap = true
    lbl.horizAlign = "center"
    lbl.vertAlign = "center"
    if it.icon <> ""
        pic = g.createChild("Poster")
        pic.uri = it.icon
        pic.width = w
        pic.height = h
        pic.loadDisplayMode = "scaleToFit"
    end if
    ring = g.createChild("Poster")
    ring.uri = "pkg:/images/ring.9.png"
    ring.translation = [-8, -8]
    ring.width = w + 16
    ring.height = h + 16
    ring.visible = false
    return { node: g, ring: ring }
end function

sub layoutCards()
    for i = 0 to m.cards.Count() - 1
        y = 0
        if m.mode = "move" and i = m.idx then y = -34
        m.cards[i].node.translation = [i * m.step, y]
    end for
end sub

' ---------- Focus ----------

sub setIndex(i as Integer, animate as Boolean)
    old = m.idx
    m.idx = i
    if i >= 0 then scrollTo(i, animate)
    refreshFocus()
    onFocusChanged(old, i)
end sub

sub scrollTo(i as Integer, animate as Boolean)
    x = i * m.step
    if x - m.offset < 0 then m.offset = x
    if x + m.cardW + 40 - m.offset > m.viewW then m.offset = x + m.cardW + 40 - m.viewW
    target = [m.trackX - m.offset, m.trackY]
    if animate
        m.scrollAnim.control = "stop"
        m.scrollInterp.keyValue = [m.track.translation, target]
        m.scrollAnim.control = "start"
    else
        m.track.translation = target
    end if
end sub

sub refreshFocus()
    rowFocus = (m.mode = "row" or m.mode = "move" or m.mode = "menu" or m.mode = "livePreview")
    m.gearRing.visible = rowFocus and m.idx = -1
    for i = 0 to m.cards.Count() - 1
        c = m.cards[i]
        focused = (i = m.idx)
        c.ring.visible = focused and rowFocus
        if focused
            c.node.scale = [1.08, 1.08]
            c.node.opacity = 1.0
        else
            c.node.scale = [1.0, 1.0]
            if m.mode = "inputs" or m.mode = "move" then c.node.opacity = 0.45 else c.node.opacity = 1.0
        end if
    end for
    layoutCards()
    refreshText()
end sub

sub refreshText()
    m.moveHint.visible = false
    if m.mode = "inputs"
        m.title.text = "Conexões"
        m.hint.text = "OK abre a entrada   |   Voltar fecha"
        return
    end if
    if m.idx = -1
        m.title.text = "Configurações da TV"
        m.hint.text = "OK abre a tela inicial da Roku"
        return
    end if
    if m.idx >= m.items.Count() then return
    m.title.text = m.items[m.idx].title
    if m.mode = "move"
        m.hint.text = "Esquerda/Direita muda a posição   |   OK conclui"
        x = m.trackX - m.offset + m.idx * m.step
        y = m.trackY - 34 + (m.cardH - 48) / 2
        m.arrowLeft.translation = [x - 74, y]
        m.arrowRight.translation = [x + m.cardW + 26, y]
        m.arrowLeft.visible = m.idx > 0
        m.arrowRight.visible = m.idx < m.items.Count() - 1
        m.moveHint.visible = true
    else if m.mode = "livePreview"
        m.hint.text = "OK ou Cima: tela cheia   |   Esq/Dir: trocar"
    else
        m.hint.text = "Segure OK para mover ou ocultar"
    end if
end sub

' ---------- Live preview (TV AO VIVO inline) ----------

sub onFocusChanged(oldIdx as Integer, newIdx as Integer)
    if m.mode <> "row" and m.mode <> "livePreview" then return
    it = invalid
    if newIdx >= 0 and newIdx < m.items.Count() then it = m.items[newIdx]
    if it <> invalid and it.kind = "live"
        if m.mode <> "livePreview"
            enterLivePreview()
        end if
        m.liveZapTimer.control = "stop"
        m.liveZapTimer.control = "start"
    else
        if m.mode = "livePreview" then exitLivePreview()
    end if
end sub

sub enterLivePreview()
    m.mode = "livePreview"
    m.wallpaper.visible = false
    m.bgVideo.visible = true
    if m.livePlayingIndex < 0
        m.liveChIndex = 0
        playLiveChannel(0)
    end if
    refreshFocus()
end sub

sub exitLivePreview()
    m.mode = "row"
    stopLiveVideo()
    m.wallpaper.visible = true
    m.bgVideo.visible = false
    m.liveStatus.visible = false
    refreshFocus()
end sub

sub onLiveZapTimer()
    playLiveChannel(m.liveChIndex)
end sub

sub playLiveChannel(i as Integer)
    if m.liveChannels.Count() = 0 then return
    if i < 0 or i >= m.liveChannels.Count() then i = 0
    m.liveChIndex = i
    ch = m.liveChannels[i]
    m.livePlayingIndex = i

    c = CreateObject("roSGNode", "ContentNode")
    c.url = To_Str(ch.url)
    c.title = To_Str(ch.title)
    c.streamFormat = "hls"
    c.live = true
    m.bgVideo.control = "stop"
    m.bgVideo.content = c
    m.bgVideo.control = "play"

    num = Pad2(i + 1)
    m.liveOsdName.text = num + "   " + To_Str(ch.title)
    m.liveOsdInfo.text = To_Str(ch.info)
    m.liveStatus.text = "Carregando " + To_Str(ch.title) + "..."
    m.liveStatus.visible = true
end sub

sub stopLiveVideo()
    m.bgVideo.control = "stop"
    m.livePlayingIndex = -1
end sub

sub onBgVideoState()
    s = m.bgVideo.state
    if s = "playing"
        m.liveStatus.visible = false
    else if s = "buffering"
        m.liveStatus.text = "Carregando..."
        m.liveStatus.visible = true
    else if s = "error"
        m.liveStatus.text = "Canal indisponível"
        m.liveStatus.visible = true
    end if
end sub

sub enterLiveFullscreen()
    m.mode = "liveFullscreen"
    showMenuBar(false)
    showLiveOsd()
    m.top.setFocus(true)
end sub

sub exitLiveFullscreen()
    m.mode = "livePreview"
    showMenuBar(true)
    hideLiveOsd()
    m.top.setFocus(true)
    refreshFocus()
end sub

sub showMenuBar(show as Boolean)
    m.track.visible = show
    m.shade.visible = show
    m.menuBand.visible = show
    m.title.visible = show
    m.hint.visible = show
    m.clock.visible = show
    m.date.visible = show
    m.top.findNode("gear").visible = show
end sub

sub showLiveOsd()
    m.liveOsd.visible = true
    m.liveOsdTimer.control = "stop"
    m.liveOsdTimer.control = "start"
end sub

sub hideLiveOsd()
    m.liveOsd.visible = false
end sub

sub liveZap(delta as Integer)
    n = m.liveChannels.Count()
    if n = 0 then return
    i = (m.liveChIndex + delta + n) mod n
    playLiveChannel(i)
    if m.mode = "liveFullscreen" then showLiveOsd()
end sub

' ---------- Actions ----------

sub activate()
    if m.idx = -1
        pressKey("Home")
        return
    end if
    it = m.items[m.idx]
    if it.kind = "live"
        enterLiveFullscreen()
    else if it.kind = "launch"
        launch(it.appId, it.title)
    else if it.kind = "tvlivre"
        m.top.navigate = { to: "tvlivre" }
    else if it.kind = "inputs"
        openInputs()
    else if it.kind = "store"
        launch("11", it.title)
    end if
end sub

sub launch(appId as String, title as String)
    m.launchTitle = title
    m.title.text = "Abrindo " + title + "..."
    m.launchTask = CreateObject("roSGNode", "LauncherTask")
    m.launchTask.mode = "launch"
    m.launchTask.appId = appId
    m.launchTask.observeField("result", "onLaunched")
    m.launchTask.control = "run"
end sub

sub onLaunched()
    if not Is_True(m.launchTask.result.launched)
        m.title.text = "Não consegui abrir " + m.launchTitle
    end if
end sub

sub pressKey(key as String)
    m.keyTask = CreateObject("roSGNode", "LauncherTask")
    m.keyTask.mode = "key"
    m.keyTask.key = key
    m.keyTask.control = "run"
end sub

' ---------- Conexões panel ----------

sub openInputs()
    if m.inputList.Count() = 0
        m.title.text = "Nenhuma conexão encontrada"
        return
    end if
    m.inputRow.removeChildrenIndex(m.inputRow.getChildCount(), 0)
    m.inputCards = []
    for i = 0 to m.inputList.Count() - 1
        a = m.inputList[i]
        c = makeCard(m.inputRow, { title: a.name, icon: a.icon }, 200, 150)
        c.node.translation = [i * 236, 0]
        cap = m.inputRow.createChild("Label")
        font = CreateObject("roSGNode", "Font")
        font.uri = "font:SystemFontFile"
        font.size = 26
        cap.font = font
        cap.text = a.name
        cap.color = "0xDDE3EAFF"
        cap.width = 200
        cap.horizAlign = "center"
        cap.translation = [i * 236, 168]
        m.inputCards.Push(c)
    end for
    m.inIdx = 0
    m.mode = "inputs"
    m.inputs.visible = true
    refreshInputs()
    refreshFocus()
end sub

sub refreshInputs()
    for i = 0 to m.inputCards.Count() - 1
        c = m.inputCards[i]
        c.ring.visible = (i = m.inIdx)
        if i = m.inIdx then c.node.scale = [1.08, 1.08] else c.node.scale = [1.0, 1.0]
    end for
end sub

sub closeInputs()
    m.inputs.visible = false
    m.mode = "row"
    refreshFocus()
end sub

' ---------- Hold-OK menu ----------

sub onHold()
    if not m.okDown then return
    m.okDown = false
    openMenu()
end sub

sub openMenu()
    if m.idx < 0 or m.idx >= m.items.Count() then return
    it = m.items[m.idx]
    m.menuOpts = [{ id: "move", label: "Mover" }]
    if it.removable then m.menuOpts.Push({ id: "hide", label: "Ocultar da tela inicial" })
    if m.hiddenCount > 0 then m.menuOpts.Push({ id: "restore", label: "Mostrar apps ocultos (" + m.hiddenCount.ToStr() + ")" })

    w = 420
    rowH = 60
    h = m.menuOpts.Count() * rowH + 20
    m.menuItems.removeChildrenIndex(m.menuItems.getChildCount(), 0)
    for i = 0 to m.menuOpts.Count() - 1
        lbl = m.menuItems.createChild("Label")
        font = CreateObject("roSGNode", "Font")
        font.uri = "font:BoldSystemFontFile"
        font.size = 28
        lbl.font = font
        lbl.text = m.menuOpts[i].label
        lbl.color = "0xFFFFFFFF"
        lbl.translation = [30, 10 + i * rowH]
        lbl.width = w - 60
        lbl.height = rowH
        lbl.vertAlign = "center"
    end for
    m.menuBg.width = w
    m.menuBg.height = h
    m.menuSel.width = w
    m.menuSel.height = rowH
    x = m.trackX - m.offset + m.idx * m.step + (m.cardW - w) / 2
    if x < 40 then x = 40
    if x > 1880 - w then x = 1880 - w
    m.menu.translation = [x, m.trackY - 30 - h]
    m.menuIdx = 0
    m.mode = "menu"
    m.menu.visible = true
    refreshMenu()
end sub

sub refreshMenu()
    m.menuSel.translation = [0, 10 + m.menuIdx * 60]
end sub

sub closeMenu()
    m.menu.visible = false
    m.mode = "row"
    refreshFocus()
end sub

sub menuChoose()
    id = m.menuOpts[m.menuIdx].id
    m.menu.visible = false
    if id = "move"
        m.mode = "move"
        refreshFocus()
    else if id = "hide"
        hidden = Store_Get("launcherHidden", [])
        hidden.Push(m.items[m.idx].key)
        Store_Set("launcherHidden", hidden)
        m.mode = "row"
        rebuild()
    else if id = "restore"
        Store_Set("launcherHidden", [])
        m.mode = "row"
        rebuild()
    end if
end sub

' ---------- Move mode ----------

sub moveBy(delta as Integer)
    j = m.idx + delta
    if j < 0 or j >= m.items.Count() then return
    t = m.items[m.idx]
    m.items[m.idx] = m.items[j]
    m.items[j] = t
    c = m.cards[m.idx]
    m.cards[m.idx] = m.cards[j]
    m.cards[j] = c
    setIndex(j, true)
end sub

sub finishMove()
    keys = []
    for each it in m.items
        keys.Push(it.key)
    end for
    Store_Set("launcherOrder", keys)
    m.mode = "row"
    refreshFocus()
end sub

' ---------- Keys ----------

function onKeyEvent(key as String, press as Boolean) as Boolean
    ' OK acts on release, so holding it can open the menu instead.
    if key = "OK" and not press
        if m.okDown
            m.okDown = false
            m.holdTimer.control = "stop"
            activate()
        end if
        return true
    end if
    if not press then return false

    ' --- Fullscreen live mode ---
    if m.mode = "liveFullscreen"
        if key = "back"
            exitLiveFullscreen()
        else if key = "OK"
            stopLiveVideo()
            exitLiveFullscreen()
            exitLivePreview()
            m.top.navigate = { to: "liveGrid", channels: m.liveChannels, epgUrl: To_Str(m.catalogConfig.epgUrl) }
        else if key = "up" or key = "channelUp"
            liveZap(-1)
        else if key = "down" or key = "channelDown"
            liveZap(1)
        else if key = "info"
            showLiveOsd()
        end if
        return true
    end if

    ' --- Live preview (video playing, menu still visible) ---
    if m.mode = "livePreview"
        if key = "up" or key = "OK"
            if key = "OK"
                m.okDown = false
                m.holdTimer.control = "stop"
            end if
            enterLiveFullscreen()
            return true
        else if key = "left"
            if m.idx > -1 then setIndex(m.idx - 1, true)
            return true
        else if key = "right"
            if m.idx < m.items.Count() - 1 then setIndex(m.idx + 1, true)
            return true
        else if key = "back"
            exitLivePreview()
            return true
        else if key = "options"
            openMenu()
            return true
        end if
        return false
    end if

    if m.mode = "menu"
        if key = "up" and m.menuIdx > 0
            m.menuIdx--
            refreshMenu()
        else if key = "down" and m.menuIdx < m.menuOpts.Count() - 1
            m.menuIdx++
            refreshMenu()
        else if key = "OK"
            menuChoose()
        else if key = "back" or key = "options"
            closeMenu()
        end if
        return true
    end if

    if m.mode = "move"
        if key = "left"
            moveBy(-1)
        else if key = "right"
            moveBy(1)
        else if key = "OK" or key = "back" or key = "up" or key = "down"
            finishMove()
        end if
        return true
    end if

    if m.mode = "inputs"
        if key = "left" and m.inIdx > 0
            m.inIdx--
            refreshInputs()
        else if key = "right" and m.inIdx < m.inputCards.Count() - 1
            m.inIdx++
            refreshInputs()
        else if key = "OK"
            a = m.inputList[m.inIdx]
            launch(a.id, a.name)
        else if key = "back" or key = "down"
            closeInputs()
        end if
        return true
    end if

    if key = "left"
        if m.idx > -1 then setIndex(m.idx - 1, true)
        return true
    else if key = "right"
        if m.idx < m.items.Count() - 1 then setIndex(m.idx + 1, true)
        return true
    else if key = "OK"
        if m.idx = -1
            activate()
        else
            m.okDown = true
            m.holdTimer.control = "start"
        end if
        return true
    else if key = "options"
        openMenu()
        return true
    else if key = "back"
        confirmExit()
        return true
    end if
    return false
end function

sub confirmExit()
    m.exitDlg = CreateObject("roSGNode", "StandardMessageDialog")
    m.exitDlg.title = "Sair do TV Livre"
    m.exitDlg.message = ["Deseja fechar o app e voltar ao menu de configuração original da TV?"]
    m.exitDlg.buttons = ["Continuar aqui", "Fechar e voltar ao menu da TV"]
    m.exitDlg.observeField("buttonSelected", "onExitButton")
    m.exitDlg.observeField("wasClosed", "onExitClosed")
    m.top.getScene().dialog = m.exitDlg
end sub

sub onExitButton()
    if m.exitDlg.buttonSelected = 1
        m.top.getScene().exitApp = true
    else
        m.exitDlg.close = true
    end if
end sub

sub onExitClosed()
    m.top.setFocus(true)
end sub
