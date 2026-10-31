' Modes: "list" (browsing channels, preview follows focus), "preview" (preview
' selected, OK expands) and "full" (fullscreen; up/down zaps, Back returns).
' The list shows m.view: a search entry first, then the channels matching m.query.
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
    m.listTitle = m.top.findNode("listTitle")
    m.epgNow = m.top.findNode("epgNow")
    m.epgNext = m.top.findNode("epgNext")
    m.osdEpg = m.top.findNode("osdEpg")
    m.mode = "list"
    m.playingIndex = -1
    m.query = ""
    m.catFilter = ""
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
    m.streamOffline = {}
    m.streamCheckTask = invalid
    m.checkDlg = invalid

    startEpg()

    m.list.observeField("itemFocused", "onItemFocused")
    m.list.observeField("itemSelected", "onItemSelected")
    m.video.observeField("state", "onState")
    m.zapTimer.observeField("fire", "playFocused")
    m.osdTimer.observeField("fire", "hideOsd")
    m.top.observeField("focusedChild", "onFocusChange")
    m.top.observeField("active", "onActive")
    setMode("list", false)
end sub

' In preview/fullscreen the preview frame (a sibling of the list) holds focus, so the
' list cannot swallow arrow keys; focusing this node itself would be ignored by Roku
' while the list, its descendant, still has focus.
sub onFocusChange()
    if not m.top.hasFocus() then return
    if m.mode = "list"
        m.list.setFocus(true)
    else
        m.ring.setFocus(true)
    end if
end sub

sub onChannels()
    applyFilter("")
end sub

' ---------- Search ----------

' Lowercase without accents, so "camara" finds "TV Câmara".
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

sub applyFilter(query as String)
    m.query = query.Trim()
    q = Fold(m.query)
    cat = m.catFilter
    m.view = [{ kind: "search" }]
    chs = m.top.channels
    for i = 0 to chs.Count() - 1
        ch = chs[i]
        if cat <> "" and primaryGroup(To_Str(ch.group)) <> cat then goto nextCh
        text = Fold(To_Str(ch.title) + " " + To_Str(ch.info) + " " + To_Str(ch.group))
        if q = "" or Instr(1, text, q) > 0
            kind = "live"
            if To_Str(ch.appId) <> "" then kind = "app"
            m.view.Push({ kind: kind, ch: ch, num: i + 1 })
        end if
        nextCh:
    end for

    root = CreateObject("roSGNode", "ContentNode")
    for each e in m.view
        n = root.createChild("ContentNode")
        if e.kind = "search"
            label = "   Pesquisar canal..."
            if m.query <> "" then label = "   Pesquisa: " + m.query + "  (" + (m.view.Count() - 1).ToStr() + ")"
            if cat <> "" then label = label + "   [" + cat + "]"
            n.title = label
        else
            prefix = Pad2(e.num) + "    "
            title = To_Str(e.ch.title)
            id = To_Str(e.ch.id)
            if m.streamOffline <> invalid and m.streamOffline[id] <> invalid
                title = "[X] " + title
            end if
            n.title = prefix + title
        end if
    end for
    m.list.content = root
    if cat <> ""
        m.listTitle.text = cat + "   •   " + (m.view.Count() - 1).ToStr() + " canais"
    else if m.query = ""
        m.listTitle.text = "Lista de canais"
    else
        m.listTitle.text = "Resultado da pesquisa   •   Voltar limpa"
    end if

    ' Focus the first match (or the first channel) and preview it.
    first = 0
    if m.view.Count() > 1 then first = 1
    m.list.jumpToItem = first
    m.playingIndex = -1
    updateInfo(first)
    if m.top.active and m.top.visible then playIndex(first)
end sub

sub openSearch()
    kb = CreateObject("roSGNode", "StandardKeyboardDialog")
    kb.title = "Pesquisar canal"
    kb.message = ["Nome, emissora ou grupo (ex.: cultura, notícias, pluto)"]
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
        applyFilter(text)
    else if idx = 1
        applyFilter("")
    end if
end sub

sub onSearchClosed()
    setMode("list", true)
end sub

function viewEntry(i as Integer) as Dynamic
    if i < 0 or i >= m.view.Count() then return invalid
    return m.view[i]
end function

sub onActive()
    if m.top.active and m.top.visible
        m.playingIndex = -1
        playIndex(m.list.itemFocused)
    else
        m.zapTimer.control = "stop"
        m.video.control = "stop"
        m.playingIndex = -1
        if m.mode = "full" then setMode("preview", false)
    end if
end sub

sub onItemFocused()
    if m.mode <> "list" then return
    updateInfo(m.list.itemFocused)
    m.zapTimer.control = "stop"
    m.zapTimer.control = "start"
end sub

sub playFocused()
    playIndex(m.list.itemFocused)
end sub

sub onItemSelected()
    i = m.list.itemSelected
    e = viewEntry(i)
    if e <> invalid and e.kind = "search"
        openSearch()
    else if isApp(i)
        playIndex(i)
        openApp(i)
    else
        playIndex(i)
        setMode("full", true)
    end if
end sub

' Entries with "appId" are shortcuts to another installed Roku app.
function isApp(i as Integer) as Boolean
    e = viewEntry(i)
    return e <> invalid and e.kind = "app"
end function

' Entries that do not play inside the preview (search box, app shortcuts).
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
    if e.kind = "search"
        m.chName.text = "Pesquisar canal"
        m.chInfo.text = "OK abre o teclado   •   " + (m.view.Count() - 1).ToStr() + " canais na lista"
        return
    end if
    ch = e.ch
    m.chName.text = To_Str(ch.title)
    parts = []
    if To_Str(ch.info) <> "" then parts.Push(To_Str(ch.info))
    if To_Str(ch.group) <> "" then parts.Push(To_Str(ch.group))
    m.chInfo.text = parts.Join("   •   ")
    fav = Fav_Has(To_Str(ch.id))
    if fav then m.chName.text = m.chName.text + "  *"
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
    if e.kind = "search"
        m.video.control = "stop"
        m.appArt.visible = false
        showStatus("Aperte OK para pesquisar um canal")
        return
    end if
    ch = e.ch
    if isApp(i)
        m.video.control = "stop"
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
    m.video.control = "stop"
    m.video.content = c
    m.video.control = "play"
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

sub setMode(mode as String, takeFocus as Boolean)
    m.mode = mode
    full = (mode = "full")
    m.ring.visible = (mode = "preview")
    m.info.visible = not full
    if full
        m.video.translation = [0, 0]
        m.video.width = 1920
        m.video.height = 1080
        m.status.translation = [0, 520]
        m.status.width = 1920
        showOsd()
    else
        m.video.translation = [720, 270]
        m.video.width = 1120
        m.video.height = 630
        m.status.translation = [720, 560]
        m.status.width = 1120
        hideOsd()
    end if
    if mode = "list"
        m.hint.text = "<<: verificar   >>: categorias"
    else
        m.hint.text = "Play: favoritar   •   <<: qualidade"
    end if
    if takeFocus
        if mode = "list"
            m.list.setFocus(true)
        else
            m.ring.setFocus(true)
        end if
    end if
end sub

sub showOsd()
    m.osd.visible = true
    m.osdTimer.control = "stop"
    m.osdTimer.control = "start"
end sub

sub hideOsd()
    m.osd.visible = false
end sub

sub zap(delta as Integer)
    n = m.view.Count()
    if n = 0 then return
    i = m.playingIndex
    ' Fullscreen zapping skips the search entry and app shortcuts.
    for tries = 1 to n
        i = (i + delta + n) mod n
        if not isSpecial(i) then exit for
    end for
    m.list.jumpToItem = i
    playIndex(i)
    showOsd()
end sub

' ---------- EPG ----------

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
        print "[epg] loaded "; m.epgGuide.Count(); " normalised channels"
        updateInfo(m.list.itemFocused)
    end if
end sub

' Normalise a channel name for EPG matching: lowercase, strip resolution
' tags like "(720p)", "hd", hyphens, and extra whitespace.
function EpgNorm(s as String) as String
    s = LCase(s.Trim())
    ' Remove resolution/quality tags: (720p), (1080p), (480p), [not 24/7], [geo-blocked] etc.
    r = CreateObject("roRegex", "\([^)]*\)|\[[^\]]*\]", "")
    s = r.ReplaceAll(s, "")
    ' Remove "hd", "sd" as standalone words
    r2 = CreateObject("roRegex", "\b(hd|sd)\b", "")
    s = r2.ReplaceAll(s, "")
    ' Remove hyphens, extra spaces
    s = s.Replace("-", " ").Replace("  ", " ").Trim()
    ' Remove "_local" suffix (e.g. "sp_local")
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
    ' Fallback: try partial match
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

' ---------- Stream checker ----------

sub startStreamCheck()
    if m.streamCheckTask <> invalid
        showStatus("Verificacao ja em andamento...")
        return
    end if
    chs = m.top.channels
    if chs = invalid or chs.Count() = 0
        showStatus("Nenhum canal para verificar")
        return
    end if
    m.streamCheckTask = CreateObject("roSGNode", "StreamCheckTask")
    m.streamCheckTask.channels = chs
    m.streamCheckTask.observeField("progress", "onStreamCheckProgress")
    m.streamCheckTask.observeField("result", "onStreamCheckDone")
    m.streamCheckTask.control = "run"
    m.streamOffline = {}
    showCheckDialog(0, chs.Count(), "Iniciando...")
end sub

sub showCheckDialog(checked as Integer, total as Integer, current as String)
    if m.checkDlg = invalid
        m.checkDlg = CreateObject("roSGNode", "StandardMessageDialog")
        m.checkDlg.title = "Verificando streams"
        m.checkDlg.buttons = ["Cancelar"]
        m.checkDlg.observeField("buttonSelected", "onCheckCancel")
        m.checkDlg.observeField("wasClosed", "onCheckDialogClosed")
        m.top.getScene().dialog = m.checkDlg
    end if
    pct = 0
    if total > 0 then pct = Int(checked * 100 / total)
    bar = ""
    filled = Int(pct / 5)
    for j = 0 to 19
        if j < filled then bar = bar + "#" else bar = bar + "-"
    end for
    m.checkDlg.message = [
        "[" + bar + "] " + pct.ToStr() + "%",
        checked.ToStr() + " / " + total.ToStr() + " canais",
        current
    ]
end sub

sub onStreamCheckProgress()
    p = m.streamCheckTask.progress
    if p = invalid then return
    showCheckDialog(p.checked, p.total, To_Str(p.current))
end sub

sub onCheckCancel()
    if m.streamCheckTask <> invalid
        m.streamCheckTask.control = "stop"
        m.streamCheckTask = invalid
    end if
    if m.checkDlg <> invalid then m.checkDlg.close = true
end sub

sub onCheckDialogClosed()
    m.checkDlg = invalid
end sub

sub onStreamCheckDone()
    res = m.streamCheckTask.result
    m.streamCheckTask = invalid
    if m.checkDlg <> invalid then m.checkDlg.close = true

    if res = invalid or not Is_True(res.ok) then return

    m.streamOffline = {}
    offList = []
    for each r in res.results
        if r.status <> "online"
            m.streamOffline[r.id] = r.status
            offList.Push(r.title)
        end if
    end for

    refreshListLabels()

    dlg = CreateObject("roSGNode", "StandardMessageDialog")
    dlg.title = "Resultado da verificacao"
    dlg.message = [
        "Total: " + res.total.ToStr(),
        "Online: " + res.online.ToStr(),
        "Offline: " + res.offline.ToStr(),
        "",
        "Canais offline marcados com [X] na lista."
    ]
    dlg.buttons = ["OK"]
    dlg.observeField("buttonSelected", "onResultDlgClose")
    m.resultDlg = dlg
    m.top.getScene().dialog = dlg
end sub

sub onResultDlgClose()
    if m.resultDlg <> invalid then m.resultDlg.close = true
end sub

' ---------- Category filter ----------

sub openCategoryPicker()
    chs = m.top.channels
    if chs = invalid then return
    cats = {}
    for each ch in chs
        g = primaryGroup(To_Str(ch.group))
        if g = "" then g = "Geral"
        if cats[g] = invalid then cats[g] = 0
        cats[g] = cats[g] + 1
    end for

    sorted = []
    for each k in cats.Keys()
        sorted.Push({ name: k, count: cats[k] })
    end for
    ' Simple insertion sort by count descending
    for i = 1 to sorted.Count() - 1
        j = i
        while j > 0 and sorted[j].count > sorted[j - 1].count
            tmp = sorted[j]
            sorted[j] = sorted[j - 1]
            sorted[j - 1] = tmp
            j--
        end while
    end for

    buttons = ["Todas (" + chs.Count().ToStr() + ")"]
    m.catNames = [""]
    for each c in sorted
        buttons.Push(c.name + " (" + c.count.ToStr() + ")")
        m.catNames.Push(c.name)
    end for

    dlg = CreateObject("roSGNode", "StandardMessageDialog")
    dlg.title = "Filtrar por categoria"
    dlg.message = ["Escolha uma categoria para filtrar os canais:"]
    dlg.buttons = buttons
    dlg.observeField("buttonSelected", "onCatSelected")
    dlg.observeField("wasClosed", "onCatClosed")
    m.catDlg = dlg
    m.top.getScene().dialog = dlg
end sub

sub onCatSelected()
    idx = m.catDlg.buttonSelected
    m.catDlg.close = true
    if idx >= 0 and idx < m.catNames.Count()
        m.catFilter = m.catNames[idx]
    else
        m.catFilter = ""
    end if
    applyFilter(m.query)
end sub

sub onCatClosed()
    m.catDlg = invalid
    setMode("list", true)
end sub

' ---------- Quality selector ----------

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
    if m.mode = "full"
        m.ring.setFocus(true)
    else if m.mode = "preview"
        m.ring.setFocus(true)
    else
        m.list.setFocus(true)
    end if
end sub

sub reloadCurrentStream()
    if m.playingIndex < 0 then return
    saved = m.playingIndex
    m.playingIndex = -1
    playIndex(saved)
end sub

sub refreshListLabels()
    root = m.list.content
    if root = invalid then return
    for i = 0 to root.getChildCount() - 1
        e = viewEntry(i)
        if e = invalid or e.kind <> "live" then goto nextLabel
        ch = e.ch
        id = To_Str(ch.id)
        prefix = Pad2(e.num) + "    "
        title = To_Str(ch.title)
        if m.streamOffline <> invalid and m.streamOffline[id] <> invalid
            title = "[X] " + title
        end if
        root.getChild(i).title = prefix + title
        nextLabel:
    end for
end sub

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

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "options"
        openSearch()
        return true
    end if
    if m.mode = "list"
        if key = "right"
            e = viewEntry(m.list.itemFocused)
            if e <> invalid and e.kind = "search" then return true
            playIndex(m.list.itemFocused)
            setMode("preview", true)
            return true
        else if key = "back" and (m.query <> "" or m.catFilter <> "")
            m.catFilter = ""
            applyFilter("")
            return true
        else if key = "rewind"
            startStreamCheck()
            return true
        else if key = "fastforward"
            openCategoryPicker()
            return true
        end if
        return false
    else if m.mode = "preview"
        if key = "left" or key = "back"
            setMode("list", true)
            return true
        else if key = "up"
            ' Up from the preview goes to the tab bar; coming back down returns to the preview.
            m.top.navigate = { to: "tabs" }
            return true
        else if key = "OK"
            e = viewEntry(m.playingIndex)
            if e <> invalid and e.kind = "search"
                openSearch()
            else if isApp(m.playingIndex)
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
    ' fullscreen
    if key = "back"
        setMode("preview", true)
    else if key = "up" or key = "channelUp"
        zap(-1)
    else if key = "down" or key = "channelDown"
        zap(1)
    else if key = "OK" or key = "info"
        showOsd()
    else if key = "play"
        toggleFav()
    else if key = "rewind" or key = "fastforward"
        openQualityPicker()
    end if
    return true
end function
