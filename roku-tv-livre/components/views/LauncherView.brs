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
    m.liveInfoBar = m.top.findNode("liveInfoBar")
    m.liveInfoNum = m.top.findNode("liveInfoNum")
    m.liveInfoName = m.top.findNode("liveInfoName")
    m.liveInfoEpg = m.top.findNode("liveInfoEpg")
    m.liveInfoHint = m.top.findNode("liveInfoHint")
    m.liveInfoTimer = m.top.findNode("liveInfoTimer")
    m.liveInfoTimer.observeField("fire", "hideLiveInfoBar")
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
    m.live24Channels = []
    m.liveChIndex = To_Int(Store_Get("lastLiveCh", "0"))
    m.livePlayingIndex = -1
    m.catalogConfig = invalid
    m.live24Section = invalid

    m.seriesPanel = m.top.findNode("seriesPanel")
    m.seriesHeadline = m.top.findNode("seriesHeadline")
    m.seriesDesc = m.top.findNode("seriesDesc")
    m.seriesDeck = m.top.findNode("seriesDeck")
    m.seriesSection = invalid
    m.seriesCategories = []
    m.seriesBuilt = false

    m.live24Panel = m.top.findNode("live24Panel")
    m.live24Headline = m.top.findNode("live24Headline")
    m.live24Desc = m.top.findNode("live24Desc")
    m.live24Built = false

    m.moviesPanel = m.top.findNode("moviesPanel")
    m.moviesBg = m.top.findNode("moviesBg")
    m.moviesHeadline = m.top.findNode("moviesHeadline")
    m.moviesDesc = m.top.findNode("moviesDesc")
    m.moviesSection = invalid
    m.moviesBuilt = false

    m.animePanel = m.top.findNode("animePanel")
    m.animeHeadline = m.top.findNode("animeHeadline")
    m.animeDesc = m.top.findNode("animeDesc")
    m.animeDeck = m.top.findNode("animeDeck")
    m.animeSection = invalid
    m.animeCategories = []
    m.animeBuilt = false

    m.top.observeField("resumed", "onResumed")

    loadCatalog()
    rebuild()
    loadApps()
end sub

sub onResumed()
    if m.idx >= 0 and m.idx < m.items.Count()
        it = m.items[m.idx]
        if it.kind = "live"
            saved = To_Int(Store_Get("lastLiveCh", "0"))
            if saved >= 0 and saved < m.liveChannels.Count()
                m.liveChIndex = saved
            end if
            enterLivePreview()
        else if it.kind = "series"
            enterSeriesPreview()
        else if it.kind = "anime"
            enterAnimePreview()
        else if it.kind = "movies"
            enterMoviesPreview()
        else if it.kind = "live24"
            enterLive24Preview()
        end if
    end if
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
                if To_Str(s.id) = "canais24h"
                    m.live24Channels = s.channels
                    m.live24Section = s
                else
                    m.liveChannels = s.channels
                end if
            else if s.kind = "grid" and To_Str(s.id) = "series_tab"
                m.seriesSection = s
                if s.categories <> invalid then m.seriesCategories = s.categories
            else if s.kind = "grid" and To_Str(s.id) = "anime_tab"
                m.animeSection = s
                if s.categories <> invalid then m.animeCategories = s.categories
            else if s.kind = "movies" and To_Str(s.id) = "filmes"
                m.moviesSection = s
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
        { key: "live", kind: "live", title: "TV ao vivo", appId: "", icon: "pkg:/images/card_live.png", removable: false }
        { key: "series", kind: "series", title: "Séries", appId: "", icon: "pkg:/images/card_series.png", removable: false }
        { key: "anime", kind: "anime", title: "Animes", appId: "", icon: "pkg:/images/card_anime.png", removable: false }
        { key: "live24", kind: "live24", title: "Canais 24 hs", appId: "", icon: "pkg:/images/card_24h.png", removable: false }
        { key: "movies", kind: "movies", title: "Filmes", appId: "", icon: "pkg:/images/card_movies.png", removable: false }
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
    rowFocus = (m.mode = "row" or m.mode = "move" or m.mode = "menu" or m.mode = "livePreview" or m.mode = "seriesPreview" or m.mode = "animePreview" or m.mode = "moviesPreview" or m.mode = "live24Preview")
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
        m.hint.text = "OK ou Cima: tela cheia   |   CH+/CH-: trocar canal"
    else if m.mode = "seriesPreview"
        m.hint.text = "OK: abrir séries"
    else if m.mode = "animePreview"
        m.hint.text = "OK: abrir animes"
    else if m.mode = "moviesPreview"
        m.hint.text = "OK: abrir filmes"
    else if m.mode = "live24Preview"
        m.hint.text = "OK: abrir canais 24 hs"
    else
        m.hint.text = "Segure OK para mover ou ocultar"
    end if
end sub

' ---------- Live preview (TV AO VIVO inline) ----------

sub exitAllPreviews()
    if m.mode = "livePreview" then exitLivePreview()
    if m.mode = "seriesPreview" then exitSeriesPreview()
    if m.mode = "animePreview" then exitAnimePreview()
    if m.mode = "moviesPreview" then exitMoviesPreview()
    if m.mode = "live24Preview" then exitLive24Preview()
end sub

sub onFocusChanged(oldIdx as Integer, newIdx as Integer)
    if m.mode <> "row" and m.mode <> "livePreview" and m.mode <> "seriesPreview" and m.mode <> "animePreview" and m.mode <> "moviesPreview" and m.mode <> "live24Preview" then return
    it = invalid
    if newIdx >= 0 and newIdx < m.items.Count() then it = m.items[newIdx]
    if it <> invalid and it.kind = "live"
        if m.mode <> "livePreview" then exitAllPreviews()
        if m.mode <> "livePreview"
            enterLivePreview()
        end if
        m.liveZapTimer.control = "stop"
        m.liveZapTimer.control = "start"
    else if it <> invalid and it.kind = "series"
        if m.mode <> "seriesPreview" then exitAllPreviews()
        if m.mode <> "seriesPreview"
            enterSeriesPreview()
        end if
    else if it <> invalid and it.kind = "anime"
        if m.mode <> "animePreview" then exitAllPreviews()
        if m.mode <> "animePreview"
            enterAnimePreview()
        end if
    else if it <> invalid and it.kind = "movies"
        if m.mode <> "moviesPreview" then exitAllPreviews()
        if m.mode <> "moviesPreview"
            enterMoviesPreview()
        end if
    else if it <> invalid and it.kind = "live24"
        if m.mode <> "live24Preview" then exitAllPreviews()
        if m.mode <> "live24Preview"
            enterLive24Preview()
        end if
    else
        exitAllPreviews()
    end if
end sub

sub enterLivePreview()
    m.mode = "livePreview"
    m.wallpaper.visible = false
    m.bgVideo.visible = true
    playLiveChannel(m.liveChIndex)
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
    Store_Set("lastLiveCh", i.ToStr())

    c = CreateObject("roSGNode", "ContentNode")
    c.url = To_Str(ch.url)
    c.title = To_Str(ch.title)
    c.streamFormat = "hls"
    c.live = true
    m.bgVideo.control = "none"
    m.bgVideo.content = c
    m.bgVideo.control = "play"

    num = Pad2(i + 1)
    m.liveOsdName.text = num + "   " + To_Str(ch.title)
    m.liveOsdInfo.text = To_Str(ch.info)
    m.liveStatus.text = "Carregando " + To_Str(ch.title) + "..."
    m.liveStatus.visible = true
end sub

sub stopLiveVideo()
    m.bgVideo.control = "none"
    m.bgVideo.content = invalid
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
    showLiveInfoBar()
    m.top.setFocus(true)
end sub

sub exitLiveFullscreen()
    m.mode = "livePreview"
    showMenuBar(true)
    hideLiveInfoBar()
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

sub updateLiveInfoBar()
    if m.liveChannels.Count() = 0 then return
    i = m.liveChIndex
    if i < 0 or i >= m.liveChannels.Count() then return
    ch = m.liveChannels[i]
    m.liveInfoNum.text = "CANAL " + Pad2(i + 1)
    m.liveInfoName.text = UCase(To_Str(ch.title))
    m.liveInfoEpg.text = To_Str(ch.info)
end sub

sub showLiveInfoBar()
    updateLiveInfoBar()
    m.liveInfoBar.visible = true
    m.liveInfoTimer.control = "stop"
    m.liveInfoTimer.control = "start"
end sub

sub hideLiveInfoBar()
    m.liveInfoBar.visible = false
    m.liveInfoTimer.control = "stop"
end sub

sub toggleLiveInfoBar()
    if m.liveInfoBar.visible
        hideLiveInfoBar()
    else
        showLiveInfoBar()
    end if
end sub

sub liveZap(delta as Integer)
    n = m.liveChannels.Count()
    if n = 0 then return
    i = (m.liveChIndex + delta + n) mod n
    playLiveChannel(i)
    if m.mode = "liveFullscreen" then showLiveInfoBar()
end sub

' ---------- Series preview (informative overlay when SÉRIES is focused) ----------

sub buildSeriesPanel()
    if m.seriesBuilt then return
    m.seriesBuilt = true

    m.seriesHeadline.text = "As melhores séries"
    m.seriesDesc.text = "Maratone suas séries favoritas com episódios completos, organizados por temporada. Sitcoms clássicas, ação e muito mais — tudo disponível agora."

    posters = []
    for each cat in m.seriesCategories
        if cat.items <> invalid
            for each item in cat.items
                p = To_Str(item.poster)
                if p <> "" then posters.Push({ uri: p, id: To_Str(item.id) })
            end for
        end if
    end for
    deckOrder = ["todo_mundo_odeia_o_chris", "bigbang", "o_continental"]
    ordered = []
    for each dId in deckOrder
        for each po in posters
            if po.id = dId then ordered.Push(po.uri)
        end for
    end for
    for each po in posters
        found = false
        for each dId in deckOrder
            if po.id = dId then found = true
        end for
        if not found then ordered.Push(po.uri)
    end for
    posters = ordered

    posterW = 280
    posterH = 420
    count = posters.Count()
    if count > 4 then count = 4
    for i = 0 to count - 1
        g = m.seriesDeck.createChild("Group")
        offsetX = i * 80
        offsetY = i * 14
        rot = -6 + i * 4
        g.translation = [offsetX, offsetY]
        g.rotation = rot * 0.01745329
        g.scaleRotateCenter = [posterW / 2, posterH / 2]

        shadow = g.createChild("Rectangle")
        shadow.width = posterW + 4
        shadow.height = posterH + 4
        shadow.translation = [-2, -2]
        shadow.color = "0x00000088"

        bg = g.createChild("Rectangle")
        bg.width = posterW
        bg.height = posterH
        bg.color = "0x1B2233FF"

        pic = g.createChild("Poster")
        pic.uri = posters[i]
        pic.width = posterW
        pic.height = posterH
        pic.loadDisplayMode = "scaleToFit"
    end for
end sub

sub enterSeriesPreview()
    m.mode = "seriesPreview"
    buildSeriesPanel()
    m.seriesPanel.visible = true
    refreshFocus()
end sub

sub exitSeriesPreview()
    m.mode = "row"
    m.seriesPanel.visible = false
    refreshFocus()
end sub

sub openSeriesGrid()
    m.seriesPanel.visible = false
    if m.seriesSection <> invalid
        m.top.navigate = { to: "seriesGrid", section: m.seriesSection }
    end if
end sub

sub buildMoviesPanel()
    if m.moviesBuilt then return
    m.moviesBuilt = true
    m.moviesHeadline.text = "Filmes de ação"
    m.moviesDesc.text = "Os maiores clássicos do cinema de ação. John Wick, O Protetor e muito mais — assista agora em alta qualidade."
    m.moviesBg.uri = "pkg:/images/preview_movies.png"
end sub

sub enterMoviesPreview()
    m.mode = "moviesPreview"
    buildMoviesPanel()
    m.moviesPanel.visible = true
    refreshFocus()
end sub

sub exitMoviesPreview()
    m.mode = "row"
    m.moviesPanel.visible = false
    refreshFocus()
end sub

sub openMoviesGrid()
    m.moviesPanel.visible = false
    if m.moviesSection <> invalid
        m.top.navigate = { to: "moviesGrid", section: m.moviesSection }
    end if
end sub

sub buildAnimePanel()
    if m.animeBuilt then return
    m.animeBuilt = true

    m.animeHeadline.text = "Os melhores animes"
    m.animeDesc.text = "Assista animes dublados completos, organizados por temporada. Ação, aventura, fantasia e muito mais — tudo disponível agora."

    posters = []
    for each cat in m.animeCategories
        if cat.items <> invalid
            for each item in cat.items
                p = To_Str(item.poster)
                if p <> "" then posters.Push({ uri: p, id: To_Str(item.id) })
            end for
        end if
    end for
    deckOrder = ["solo_leveling_dub", "re_zero_dub", "yu_yu_hakusho_dub"]
    ordered = []
    for each dId in deckOrder
        for each po in posters
            if po.id = dId then ordered.Push(po.uri)
        end for
    end for
    for each po in posters
        found = false
        for each dId in deckOrder
            if po.id = dId then found = true
        end for
        if not found then ordered.Push(po.uri)
    end for
    posters = ordered

    posterW = 280
    posterH = 420
    count = posters.Count()
    if count > 4 then count = 4
    for i = 0 to count - 1
        g = m.animeDeck.createChild("Group")
        offsetX = i * 80
        offsetY = i * 14
        rot = -6 + i * 4
        g.translation = [offsetX, offsetY]
        g.rotation = rot * 0.01745329
        g.scaleRotateCenter = [posterW / 2, posterH / 2]

        shadow = g.createChild("Rectangle")
        shadow.width = posterW + 4
        shadow.height = posterH + 4
        shadow.translation = [-2, -2]
        shadow.color = "0x00000088"

        bg = g.createChild("Rectangle")
        bg.width = posterW
        bg.height = posterH
        bg.color = "0x1B2233FF"

        pic = g.createChild("Poster")
        pic.uri = posters[i]
        pic.width = posterW
        pic.height = posterH
        pic.loadDisplayMode = "scaleToFit"
    end for
end sub

sub enterAnimePreview()
    m.mode = "animePreview"
    buildAnimePanel()
    m.animePanel.visible = true
    refreshFocus()
end sub

sub exitAnimePreview()
    m.mode = "row"
    m.animePanel.visible = false
    refreshFocus()
end sub

sub openAnimeGrid()
    m.animePanel.visible = false
    if m.animeSection <> invalid
        m.top.navigate = { to: "animeGrid", section: m.animeSection }
    end if
end sub

sub buildLive24Panel()
    if m.live24Built then return
    m.live24Built = true
    m.live24Headline.text = "Canais 24 horas"
    m.live24Desc.text = "Assista animes, desenhos e séries 24 horas por dia, sem interrupção. Canais dedicados com programação contínua dos seus favoritos."
end sub

sub enterLive24Preview()
    m.mode = "live24Preview"
    buildLive24Panel()
    m.live24Panel.visible = true
    refreshFocus()
end sub

sub exitLive24Preview()
    m.mode = "row"
    m.live24Panel.visible = false
    refreshFocus()
end sub

sub openLive24Grid()
    m.live24Panel.visible = false
    if m.live24Channels.Count() > 0
        m.top.navigate = { to: "liveGrid", channels: m.live24Channels, epgUrl: To_Str(m.catalogConfig.epgUrl), startIndex: 0, viewTitle: "Canais 24 hs", viewTheme: "blue" }
    end if
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
    else if it.kind = "series"
        openSeriesGrid()
    else if it.kind = "anime"
        openAnimeGrid()
    else if it.kind = "movies"
        openMoviesGrid()
    else if it.kind = "live24"
        openLive24Grid()
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
            hideLiveInfoBar()
            exitLiveFullscreen()
        else if key = "OK"
            hideLiveInfoBar()
            stopLiveVideo()
            exitLiveFullscreen()
            exitLivePreview()
            m.top.navigate = { to: "liveGrid", channels: m.liveChannels, epgUrl: To_Str(m.catalogConfig.epgUrl), startIndex: m.liveChIndex }
        else if key = "channelUp" or key = "right"
            liveZap(1)
        else if key = "channelDown" or key = "left"
            liveZap(-1)
        else if key = "up" or key = "info"
            toggleLiveInfoBar()
        else if key = "down"
            hideLiveInfoBar()
            exitLiveFullscreen()
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
        else if key = "channelUp"
            liveZap(1)
            return true
        else if key = "channelDown"
            liveZap(-1)
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

    ' --- Movies preview (informative overlay) ---
    if m.mode = "moviesPreview"
        if key = "OK"
            m.okDown = false
            m.holdTimer.control = "stop"
            openMoviesGrid()
            return true
        else if key = "left"
            if m.idx > -1 then setIndex(m.idx - 1, true)
            return true
        else if key = "right"
            if m.idx < m.items.Count() - 1 then setIndex(m.idx + 1, true)
            return true
        else if key = "back"
            exitMoviesPreview()
            return true
        else if key = "options"
            openMenu()
            return true
        end if
        return false
    end if

    ' --- Anime preview (informative overlay) ---
    if m.mode = "animePreview"
        if key = "OK"
            m.okDown = false
            m.holdTimer.control = "stop"
            openAnimeGrid()
            return true
        else if key = "left"
            if m.idx > -1 then setIndex(m.idx - 1, true)
            return true
        else if key = "right"
            if m.idx < m.items.Count() - 1 then setIndex(m.idx + 1, true)
            return true
        else if key = "back"
            exitAnimePreview()
            return true
        else if key = "options"
            openMenu()
            return true
        end if
        return false
    end if

    ' --- Canais 24h preview (informative overlay) ---
    if m.mode = "live24Preview"
        if key = "OK"
            m.okDown = false
            m.holdTimer.control = "stop"
            openLive24Grid()
            return true
        else if key = "left"
            if m.idx > -1 then setIndex(m.idx - 1, true)
            return true
        else if key = "right"
            if m.idx < m.items.Count() - 1 then setIndex(m.idx + 1, true)
            return true
        else if key = "back"
            exitLive24Preview()
            return true
        else if key = "options"
            openMenu()
            return true
        end if
        return false
    end if

    ' --- Series preview (informative overlay, no browsing) ---
    if m.mode = "seriesPreview"
        if key = "OK"
            m.okDown = false
            m.holdTimer.control = "stop"
            openSeriesGrid()
            return true
        else if key = "left"
            if m.idx > -1 then setIndex(m.idx - 1, true)
            return true
        else if key = "right"
            if m.idx < m.items.Count() - 1 then setIndex(m.idx + 1, true)
            return true
        else if key = "back"
            exitSeriesPreview()
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
