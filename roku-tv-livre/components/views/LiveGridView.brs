sub init()
    m.list = m.top.findNode("list")
    m.video = m.top.findNode("video")
    m.appArt = m.top.findNode("appArt")
    m.ring = m.top.findNode("ring")
    m.info = m.top.findNode("info")
    m.chName = m.top.findNode("chName")
    m.chInfo = m.top.findNode("chInfo")
    m.hint = m.top.findNode("hint")
    m.status = m.top.findNode("status")
    m.osd = m.top.findNode("osd")
    m.osdName = m.top.findNode("osdName")
    m.osdInfo = m.top.findNode("osdInfo")
    m.zapTimer = m.top.findNode("zapTimer")
    m.osdTimer = m.top.findNode("osdTimer")
    m.pageTitle = m.top.findNode("pageTitle")
    m.epgNow = m.top.findNode("epgNow")
    m.epgNext = m.top.findNode("epgNext")
    m.osdEpg = m.top.findNode("osdEpg")
    m.searchBg = m.top.findNode("searchBg")
    m.searchRing = m.top.findNode("searchRing")
    m.searchLabel = m.top.findNode("searchLabel")
    m.groupChips = m.top.findNode("groupChips")
    m.listCount = m.top.findNode("listCount")
    m.bgGradient = m.top.findNode("bgGradient")
    m.infoBar = m.top.findNode("infoBar")
    m.infoBarNum = m.top.findNode("infoBarNum")
    m.infoBarName = m.top.findNode("infoBarName")
    m.infoBarEpg = m.top.findNode("infoBarEpg")
    m.infoBarHint = m.top.findNode("infoBarHint")
    m.infoBarTimer = m.top.findNode("infoBarTimer")
    m.infoBarTimer.observeField("fire", "hideInfoBar")

    m.accentColor = "0x42A5F5FF"

    m.mode = "list"
    m.focusZone = "channels"
    m.playingIndex = -1
    m.query = ""
    m.groupIdx = 0
    m.activeGroupIdx = 0
    m.groupNames = []
    m.groupNodes = []
    m.qualityIndex = loadQualityPref()
    m.qualities = [
        { label: "Auto", bw: 0 },
        { label: "Alta (1080p)", bw: 5000000 },
        { label: "Media (720p)", bw: 2500000 },
        { label: "Baixa (480p)", bw: 1000000 },
        { label: "Minima (360p)", bw: 500000 }
    ]
    m.view = []
    m.epgGuide = {}
    m.chipW = 180
    m.chipH = 38
    m.chipGap = 6
    m.groupScrollX = 0

    startEpg()

    m.list.observeField("itemFocused", "onItemFocused")
    m.list.observeField("itemSelected", "onItemSelected")
    m.video.observeField("state", "onState")
    m.zapTimer.observeField("fire", "playFocused")
    m.osdTimer.observeField("fire", "hideOsd")
    m.top.observeField("closing", "onClosing")
    m.top.observeField("focusedChild", "onFocusChange")
    m.listIdx = 0
end sub

sub onClosing()
    m.video.control = "none"
    m.video.content = invalid
end sub

sub onFocusChange()
    if not m.top.isInFocusChain() then return
    if m.top.getScene().dialog <> invalid then return
    if m.mode = "list"
        if m.focusZone = "channels"
            m.list.setFocus(true)
        else if m.focusZone = "search"
            m.searchBg.setFocus(true)
        else if m.focusZone = "groups"
            m.groupChips.setFocus(true)
        end if
    else
        m.ring.setFocus(true)
    end if
end sub

sub onChannels()
    applyTheme()
    buildGroupChips()
    applyFilter()
end sub

sub applyTheme()
    m.pageTitle.text = m.top.viewTitle
    if m.top.viewTheme = "blue"
        m.bgGradient.uri = "pkg:/images/bg_live24_gradient.png"
        m.accentColor = "0xE53935FF"
    else
        m.accentColor = "0x42A5F5FF"
    end if
    m.searchRing.color = m.accentColor
    m.ring.color = m.accentColor
end sub

' ==================== Groups ====================

sub buildGroupChips()
    m.groupChips.removeChildrenIndex(m.groupChips.getChildCount(), 0)
    m.groupNodes = []
    m.groupNames = ["TODOS", "FAVORITOS"]

    chs = m.top.channels
    if chs = invalid then return
    cats = {}
    catCounts = {}
    for each ch in chs
        g = primaryGroup(To_Str(ch.group))
        if g = "" then g = "Geral"
        if cats[g] = invalid
            cats[g] = true
            catCounts[g] = 1
        else
            catCounts[g] = catCounts[g] + 1
        end if
    end for
    sorted = []
    for each k in cats.Keys()
        sorted.Push({ name: k, count: catCounts[k] })
    end for
    for i = 1 to sorted.Count() - 1
        j = i
        while j > 0 and sorted[j].count > sorted[j - 1].count
            tmp = sorted[j]
            sorted[j] = sorted[j - 1]
            sorted[j - 1] = tmp
            j--
        end while
    end for
    for each c in sorted
        m.groupNames.Push(c.name)
    end for

    x = 0
    for i = 0 to m.groupNames.Count() - 1
        chip = createChip(m.groupNames[i], x, i = m.activeGroupIdx)
        m.groupChips.appendChild(chip)
        m.groupNodes.Push(chip)
        x = x + m.chipW + m.chipGap
    end for
end sub

function createChip(text as String, x as Integer, selected as Boolean) as Object
    g = CreateObject("roSGNode", "Group")
    g.translation = [x, 0]
    bg = CreateObject("roSGNode", "Rectangle")
    bg.width = m.chipW
    bg.height = m.chipH
    bg.id = "chipBg"
    if selected
        bg.color = "0xFFFFFF90"
    else
        bg.color = "0xFFFFFF20"
    end if
    g.appendChild(bg)
    lbl = CreateObject("roSGNode", "Label")
    lbl.translation = [10, 6]
    lbl.width = m.chipW - 20
    lbl.horizAlign = "center"
    lbl.id = "chipLabel"
    if selected
        lbl.color = "0x1A0A0DFF"
    else
        lbl.color = "0xCCCCCCFF"
    end if
    font = CreateObject("roSGNode", "Font")
    font.uri = "font:BoldSystemFontFile"
    font.size = 22
    lbl.font = font
    lbl.text = text
    g.appendChild(lbl)
    return g
end function

sub updateChipVisuals()
    focused = (m.focusZone = "groups")
    for i = 0 to m.groupNodes.Count() - 1
        chip = m.groupNodes[i]
        bg = chip.getChild(0)
        lbl = chip.getChild(1)
        isCursor = (focused and i = m.groupIdx)
        isActive = (i = m.activeGroupIdx)
        if isCursor
            bg.color = "0xFFFFFFFF"
            lbl.color = m.accentColor
        else if isActive
            if focused
                bg.color = "0xFFFFFF40"
                lbl.color = "0xDDDDDDFF"
            else
                bg.color = "0xFFFFFF90"
                lbl.color = "0x1A0A0DFF"
            end if
        else
            if focused
                bg.color = "0xFFFFFF15"
                lbl.color = "0x777777FF"
            else
                bg.color = "0xFFFFFF20"
                lbl.color = "0xCCCCCCFF"
            end if
        end if
    end for
    if focused
        scrollGroupsToIndex(m.groupIdx)
    else
        scrollGroupsToIndex(m.activeGroupIdx)
    end if
end sub

sub scrollGroupsToIndex(idx as Integer)
    chipX = idx * (m.chipW + m.chipGap)
    visibleW = 1800
    if chipX < m.groupScrollX
        m.groupScrollX = chipX
    else if chipX + m.chipW > m.groupScrollX + visibleW
        m.groupScrollX = chipX + m.chipW - visibleW
    end if
    m.groupChips.translation = [-m.groupScrollX, 0]
end sub

' ==================== Focus management ====================

sub setFocusZone(zone as String)
    m.focusZone = zone
    m.mode = "list"
    if zone = "channels"
        m.list.setFocus(true)
    else if zone = "search"
        m.searchBg.setFocus(true)
    else if zone = "groups"
        m.groupChips.setFocus(true)
    end if
    updateAllCursors()
end sub

sub updateAllCursors()
    isChannels = (m.mode = "list" and m.focusZone = "channels")
    isPreview = (m.mode = "preview")
    isGroups = (m.mode = "list" and m.focusZone = "groups")
    isSearch = (m.mode = "list" and m.focusZone = "search")

    if isChannels
        m.list.focusedColor = "0xFFFFFFFF"
    else
        m.list.focusedColor = "0xC8D0DCFF"
    end if

    m.ring.visible = isPreview

    m.searchRing.visible = isSearch
    if isSearch
        m.searchBg.color = "0xFFFFFFFF"
        m.searchLabel.color = "0x333333FF"
    else
        m.searchBg.color = "0x00000030"
        if m.query <> ""
            m.searchLabel.color = "0xFFFFFFFF"
        else
            m.searchLabel.color = "0xBBBBBBFF"
        end if
    end if

    updateChipVisuals()
end sub

' ==================== Search ====================

function Fold(s as String) as String
    s = LCase(s)
    pairs = [["á","a"],["à","a"],["â","a"],["ã","a"],["ä","a"],["Á","a"],["À","a"],["Â","a"],["Ã","a"],["é","e"],["ê","e"],["É","e"],["Ê","e"],["í","i"],["Í","i"],["ó","o"],["ô","o"],["õ","o"],["Ó","o"],["Ô","o"],["Õ","o"],["ú","u"],["ü","u"],["Ú","u"],["ç","c"],["Ç","c"]]
    for each p in pairs
        s = s.Replace(p[0], p[1])
    end for
    return s
end function

function primaryGroup(g as String) as String
    parts = g.Split(";")
    if parts.Count() > 0 then return parts[0].Trim()
    return "Geral"
end function

sub openSearch()
    kb = CreateObject("roSGNode", "StandardKeyboardDialog")
    kb.title = "Pesquisar canal"
    kb.message = ["Nome, emissora ou grupo"]
    kb.text = m.query
    kb.buttons = ["Pesquisar", "Limpar", "Cancelar"]
    kb.observeField("buttonSelected", "onSearchButton")
    kb.observeField("wasClosed", "onSearchClosed")
    m.kb = kb
    m.top.getScene().dialog = kb
end sub

sub onSearchButton()
    idx = m.kb.buttonSelected
    text = m.kb.text
    m.kb.close = true
    if idx = 0
        m.query = text.Trim()
    else if idx = 1
        m.query = ""
    end if
    if m.query <> ""
        m.searchLabel.text = "   Pesquisa: " + m.query
    else
        m.searchLabel.text = "   Pesquisar canal..."
    end if
    applyFilter()
end sub

sub onSearchClosed()
    setFocusZone("search")
end sub

' ==================== Filtering ====================

sub applyFilter()
    q = Fold(m.query)
    groupName = ""
    isFav = false
    if m.activeGroupIdx = 1
        isFav = true
    else if m.activeGroupIdx >= 2
        groupName = m.groupNames[m.activeGroupIdx]
    end if

    prevPlayingNum = -1
    if m.playingIndex >= 0 and m.playingIndex < m.view.Count()
        prevPlayingNum = m.view[m.playingIndex].num
    end if

    m.view = []
    chs = m.top.channels
    if chs = invalid then return
    favIds = {}
    if isFav
        for each f in Fav_List()
            favIds[f.id] = true
        end for
    end if

    for i = 0 to chs.Count() - 1
        ch = chs[i]
        if isFav and favIds[To_Str(ch.id)] = invalid then goto skipCh
        if groupName <> "" and primaryGroup(To_Str(ch.group)) <> groupName then goto skipCh
        text = Fold(To_Str(ch.title) + " " + To_Str(ch.info) + " " + To_Str(ch.group))
        if q <> "" and Instr(1, text, q) = 0 then goto skipCh
        kind = "live"
        if To_Str(ch.appId) <> "" then kind = "app"
        m.view.Push({ kind: kind, ch: ch, num: i + 1 })
        skipCh:
    end for

    root = CreateObject("roSGNode", "ContentNode")
    for each e in m.view
        n = root.createChild("ContentNode")
        prefix = Pad2(e.num) + "   "
        n.title = prefix + To_Str(e.ch.title)
    end for
    m.list.content = root

    total = m.view.Count()
    m.listCount.text = total.ToStr() + " canais"

    first = 0
    startAt = m.top.startIndex
    if startAt > 0
        for vi = 0 to m.view.Count() - 1
            if m.view[vi].num = startAt + 1
                first = vi
                exit for
            end if
        end for
        m.top.startIndex = 0
    else if prevPlayingNum > 0
        for vi = 0 to m.view.Count() - 1
            if m.view[vi].num = prevPlayingNum
                first = vi
                exit for
            end if
        end for
    end if
    m.listIdx = first
    m.list.jumpToItem = first
    if m.focusZone <> "groups"
        m.playingIndex = -1
        if total > 0
            updateInfo(first)
            playIndex(first)
        else
            m.chName.text = ""
            m.chInfo.text = ""
            showStatus("Nenhum canal encontrado")
        end if
    else
        if total > 0
            updateInfo(first)
        end if
    end if
end sub

function viewEntry(i as Integer) as Dynamic
    if i < 0 or i >= m.view.Count() then return invalid
    return m.view[i]
end function

' ==================== List events ====================

sub onItemFocused()
    if m.mode <> "list" then return
    if m.focusZone <> "channels" then return
    idx = m.list.itemFocused
    if idx < 0 then return
    m.listIdx = idx
    updateInfo(idx)
    m.zapTimer.control = "stop"
    m.zapTimer.control = "start"
end sub

sub onItemSelected()
    if m.focusZone <> "channels" then return
    i = m.list.itemSelected
    m.listIdx = i
    if isApp(i)
        playIndex(i)
        openApp(i)
    else
        playIndex(i)
        setMode("full", true)
    end if
end sub

sub playFocused()
    playIndex(m.listIdx)
end sub

function isApp(i as Integer) as Boolean
    e = viewEntry(i)
    return e <> invalid and e.kind = "app"
end function

function isSpecial(i as Integer) as Boolean
    e = viewEntry(i)
    return e = invalid or e.kind <> "live"
end function

sub openApp(i as Integer)
    ch = viewEntry(i).ch
    showStatus("Abrindo " + To_Str(ch.title) + "...")
    m.appTask = CreateObject("roSGNode", "YouTubeTask")
    m.appTask.mode = "app"
    m.appTask.appId = To_Str(ch.appId)
    m.appTask.observeField("result", "onAppOpened")
    m.appTask.control = "run"
end sub

sub onAppOpened()
    if not Is_True(m.appTask.result.launched)
        showStatus("Não consegui abrir o app." + Chr(10) + "Abra pela tela inicial da Roku.")
    end if
end sub

sub updateInfo(i as Integer)
    e = viewEntry(i)
    if e = invalid then return
    ch = e.ch
    m.chName.text = To_Str(ch.title)
    parts = []
    if To_Str(ch.info) <> "" then parts.Push(To_Str(ch.info))
    if To_Str(ch.group) <> "" then parts.Push(To_Str(ch.group))
    m.chInfo.text = parts.Join("   •   ")
    m.osdName.text = Pad2(e.num) + "   " + m.chName.text
    m.osdInfo.text = m.chInfo.text
    updateEpgLabels(To_Str(ch.title))
end sub

sub playIndex(i as Integer)
    e = viewEntry(i)
    if e = invalid then return
    updateInfo(i)
    if i = m.playingIndex then return
    m.playingIndex = i
    ch = e.ch
    if isApp(i)
        m.video.control = "none"
        m.appArt.uri = To_Str(ch.logo)
        m.appArt.visible = true
        showStatus("")
        m.status.visible = false
        return
    end if
    m.appArt.visible = false
    c = CreateObject("roSGNode", "ContentNode")
    c.url = To_Str(ch.url)
    c.title = To_Str(ch.title)
    c.streamFormat = "hls"
    c.live = true
    bw = m.qualities[m.qualityIndex].bw
    if bw > 0 then c.maxBandwidth = bw
    m.video.control = "none"
    m.video.content = c
    m.video.control = "play"
    Store_Set("lastLiveCh", (e.num - 1).ToStr())
    showStatus("Carregando " + c.title + "...")
end sub

sub onState()
    if isSpecial(m.playingIndex) then return
    s = m.video.state
    if s = "playing"
        m.status.visible = false
    else if s = "buffering"
        showStatus("Carregando...")
    else if s = "error"
        showStatus("Canal indisponível no momento." + Chr(10) + "Escolha outro canal.")
    end if
end sub

sub showStatus(text as String)
    m.status.text = text
    m.status.visible = true
end sub

' ==================== Mode ====================

sub setMode(mode as String, takeFocus as Boolean)
    m.mode = mode
    full = (mode = "full")
    m.info.visible = not full
    m.bgGradient.visible = not full
    if full
        m.video.translation = [0, 0]
        m.video.width = 1920
        m.video.height = 1080
        m.status.translation = [0, 520]
        m.status.width = 1920
        showInfoBar()
    else
        m.video.translation = [730, 180]
        m.video.width = 1120
        m.video.height = 690
        m.status.translation = [730, 500]
        m.status.width = 1120
        hideInfoBar()
        hideOsd()
    end if
    showBrowseUI(not full)
    if mode = "list"
        m.hint.text = "<<: qualidade   *: pesquisar"
    else
        m.hint.text = "Play: favoritar   <<: qualidade"
    end if
    if takeFocus
        if mode = "list"
            setFocusZone("channels")
        else
            m.ring.setFocus(true)
            updateAllCursors()
        end if
    else
        updateAllCursors()
    end if
end sub

sub showBrowseUI(show as Boolean)
    m.top.findNode("pageTitle").visible = show
    m.searchRing.visible = false
    m.searchBg.visible = show
    m.searchLabel.visible = show
    m.top.findNode("groupClip").visible = show
    m.list.visible = show
    m.listCount.visible = show
end sub

sub showOsd()
    m.osd.visible = true
    m.osdTimer.control = "stop"
    m.osdTimer.control = "start"
end sub

sub hideOsd()
    m.osd.visible = false
end sub

sub updateInfoBar()
    e = viewEntry(m.playingIndex)
    if e = invalid then return
    ch = e.ch
    m.infoBarNum.text = "CANAL " + Pad2(e.num)
    m.infoBarName.text = UCase(To_Str(ch.title))
    epg = EpgForChannel(To_Str(ch.title))
    if epg.now <> invalid
        m.infoBarEpg.text = "Agora: " + epg.now.title
    else
        m.infoBarEpg.text = To_Str(ch.info)
    end if
end sub

sub showInfoBar()
    updateInfoBar()
    m.infoBar.visible = true
    m.infoBarTimer.control = "stop"
    m.infoBarTimer.control = "start"
end sub

sub hideInfoBar()
    m.infoBar.visible = false
    m.infoBarTimer.control = "stop"
end sub

sub toggleInfoBar()
    if m.infoBar.visible
        hideInfoBar()
    else
        showInfoBar()
    end if
end sub

sub zap(delta as Integer)
    n = m.view.Count()
    if n = 0 then return
    i = m.playingIndex
    for tries = 1 to n
        i = (i + delta + n) mod n
        if not isSpecial(i) then exit for
    end for
    m.listIdx = i
    m.list.jumpToItem = i
    playIndex(i)
    showInfoBar()
end sub

' ==================== EPG ====================

sub startEpg()
    m.epgTask = CreateObject("roSGNode", "EPGTask")
    m.epgTask.epgUrl = m.top.epgUrl
    m.epgTask.observeField("result", "onEpgLoaded")
    m.epgTask.control = "run"
end sub

sub onEpgLoaded()
    res = m.epgTask.result
    if res <> invalid and Is_True(res.ok)
        raw = res.guide
        m.epgGuide = {}
        for each k in raw.Keys()
            nk = EpgNorm(k)
            if nk <> "" then m.epgGuide[nk] = raw[k]
        end for
        if m.listIdx >= 0 then updateInfo(m.listIdx)
    end if
end sub

function EpgNorm(s as String) as String
    s = LCase(s.Trim())
    r = CreateObject("roRegex", "\([^)]*\)|\[[^\]]*\]", "")
    s = r.ReplaceAll(s, "")
    r2 = CreateObject("roRegex", "\b(hd|sd)\b", "")
    s = r2.ReplaceAll(s, "")
    s = s.Replace("-", " ").Replace("  ", " ").Trim()
    r3 = CreateObject("roRegex", "\s*\w+_local$", "")
    s = r3.ReplaceAll(s, "")
    return s.Trim()
end function

function EpgForChannel(title as String) as Object
    key = EpgNorm(title)
    progs = m.epgGuide[key]
    if progs <> invalid and progs.Count() > 0
        return EpgFindNowNext(progs)
    end if
    for each gk in m.epgGuide.Keys()
        if Instr(1, key, gk) > 0 or Instr(1, gk, key) > 0
            return EpgFindNowNext(m.epgGuide[gk])
        end if
    end for
    return { now: invalid, next: invalid }
end function

function EpgFindNowNext(progs as Object) as Object
    now = CreateObject("roDateTime").AsSeconds()
    current = invalid
    upcoming = invalid
    for i = 0 to progs.Count() - 1
        p = progs[i]
        if p.start <= now and (p.stop = 0 or p.stop > now)
            current = p
            if i + 1 < progs.Count() then upcoming = progs[i + 1]
            exit for
        else if p.start > now
            upcoming = p
            exit for
        end if
    end for
    return { now: current, next: upcoming }
end function

sub updateEpgLabels(title as String)
    epg = EpgForChannel(title)
    if epg.now <> invalid
        dt = CreateObject("roDateTime")
        dt.FromSeconds(epg.now.start)
        dt.ToLocalTime()
        timeStr = Pad2(dt.GetHours()) + ":" + Pad2(dt.GetMinutes())
        m.epgNow.text = "Agora: " + epg.now.title + "  (" + timeStr + ")"
        m.epgNow.visible = true
        m.osdEpg.text = "Agora: " + epg.now.title
    else
        m.epgNow.visible = false
        m.osdEpg.text = ""
    end if
    if epg.next <> invalid
        dt = CreateObject("roDateTime")
        dt.FromSeconds(epg.next.start)
        dt.ToLocalTime()
        timeStr = Pad2(dt.GetHours()) + ":" + Pad2(dt.GetMinutes())
        m.epgNext.text = "A seguir: " + epg.next.title + "  (" + timeStr + ")"
        m.epgNext.visible = true
    else
        m.epgNext.visible = false
    end if
end sub

' ==================== Quality ====================

function loadQualityPref() as Integer
    v = Store_Get("streamQuality", "0")
    if v <> invalid and v <> "" then return To_Int(v)
    return 0
end function

sub openQualityPicker()
    buttons = []
    for i = 0 to m.qualities.Count() - 1
        q = m.qualities[i]
        lbl = q.label
        if i = m.qualityIndex then lbl = "> " + lbl
        buttons.Push(lbl)
    end for
    dlg = CreateObject("roSGNode", "StandardMessageDialog")
    dlg.title = "Qualidade do stream"
    dlg.message = ["Atual: " + m.qualities[m.qualityIndex].label]
    dlg.buttons = buttons
    dlg.observeField("buttonSelected", "onQualitySelected")
    dlg.observeField("wasClosed", "onQualityClosed")
    m.qualityDlg = dlg
    m.top.getScene().dialog = dlg
end sub

sub onQualitySelected()
    idx = m.qualityDlg.buttonSelected
    m.qualityDlg.close = true
    if idx >= 0 and idx < m.qualities.Count()
        m.qualityIndex = idx
        Store_Set("streamQuality", idx.ToStr())
        showStatus("Qualidade: " + m.qualities[idx].label)
        reloadCurrentStream()
    end if
end sub

sub onQualityClosed()
    m.qualityDlg = invalid
    setFocusZone(m.focusZone)
end sub

sub reloadCurrentStream()
    if m.playingIndex < 0 then return
    saved = m.playingIndex
    m.playingIndex = -1
    playIndex(saved)
end sub

' ==================== Keys ====================

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "options"
        openSearch()
        return true
    end if

    ' --- Fullscreen ---
    if m.mode = "full"
        if key = "back" or key = "OK"
            hideInfoBar()
            setMode("list", true)
        else if key = "channelUp" or key = "right"
            zap(1)
        else if key = "channelDown" or key = "left"
            zap(-1)
        else if key = "up" or key = "info"
            toggleInfoBar()
        else if key = "down"
            hideInfoBar()
            setMode("list", true)
        else if key = "play"
            toggleFav()
        else if key = "rewind" or key = "fastforward"
            openQualityPicker()
        end if
        return true
    end if

    ' --- Preview ---
    if m.mode = "preview"
        if key = "left" or key = "back"
            setMode("list", true)
            return true
        else if key = "up"
            setMode("list", false)
            m.groupIdx = m.activeGroupIdx
            setFocusZone("groups")
            return true
        else if key = "OK"
            if isApp(m.playingIndex)
                openApp(m.playingIndex)
            else
                setMode("full", true)
            end if
            return true
        else if key = "play"
            toggleFav()
            return true
        else if key = "rewind" or key = "fastforward"
            openQualityPicker()
            return true
        end if
        return false
    end if

    ' --- List mode: depends on focusZone ---
    if m.focusZone = "search"
        if key = "OK"
            openSearch()
            return true
        else if key = "down"
            setFocusZone("groups")
            return true
        else if key = "back"
            saveLastChannel()
            m.video.control = "none"
            m.video.content = invalid
            m.top.navigate = { to: "back" }
            return true
        end if
        return true
    end if

    if m.focusZone = "groups"
        if key = "left"
            if m.groupIdx > 0
                m.groupIdx = m.groupIdx - 1
                m.activeGroupIdx = m.groupIdx
                updateChipVisuals()
                applyFilter()
            end if
            return true
        else if key = "right"
            if m.groupIdx < m.groupNames.Count() - 1
                m.groupIdx = m.groupIdx + 1
                m.activeGroupIdx = m.groupIdx
                updateChipVisuals()
                applyFilter()
            end if
            return true
        else if key = "up"
            setFocusZone("search")
            return true
        else if key = "down" or key = "OK"
            m.list.jumpToItem = m.listIdx
            setFocusZone("channels")
            if m.view.Count() > 0
                playIndex(m.listIdx)
            end if
            return true
        else if key = "back"
            if m.activeGroupIdx > 0
                m.activeGroupIdx = 0
                m.groupIdx = 0
                updateChipVisuals()
                applyFilter()
            else
                saveLastChannel()
                m.video.control = "none"
                m.video.content = invalid
                m.top.navigate = { to: "back" }
            end if
            return true
        end if
        return true
    end if

    ' focusZone = "channels" — list has focus; component intercepts keys first
    if key = "up"
        if m.listIdx <= 0
            m.groupIdx = m.activeGroupIdx
            setFocusZone("groups")
            return true
        end if
        return false
    else if key = "down"
        if m.listIdx >= m.view.Count() - 1
            return true
        end if
        return false
    else if key = "right"
        playIndex(m.listIdx)
        setMode("preview", true)
        return true
    else if key = "back"
        if m.query <> ""
            m.query = ""
            m.searchLabel.text = "   Pesquisar canal..."
            applyFilter()
        else if m.activeGroupIdx > 0
            m.activeGroupIdx = 0
            m.groupIdx = 0
            updateChipVisuals()
            applyFilter()
        else
            saveLastChannel()
            m.video.control = "none"
            m.video.content = invalid
            m.top.navigate = { to: "back" }
        end if
        return true
    else if key = "rewind" or key = "fastforward"
        openQualityPicker()
        return true
    end if
    return false
end function

sub saveLastChannel()
    if m.playingIndex >= 0 and m.playingIndex < m.view.Count()
        e = m.view[m.playingIndex]
        Store_Set("lastLiveCh", (e.num - 1).ToStr())
    end if
end sub

sub toggleFav()
    e = viewEntry(m.playingIndex)
    if e = invalid or e.kind <> "live" then return
    ch = e.ch
    Fav_Toggle({ id: To_Str(ch.id), title: To_Str(ch.title), poster: To_Str(ch.logo), kind: "live" })
    updateInfo(m.playingIndex)
    if Fav_Has(To_Str(ch.id))
        showStatus("Adicionado a Minha Lista")
    else
        showStatus("Removido da Minha Lista")
    end if
end sub
