' Home = thin top bar + hero background + tab content in lower half.
' Each tab view can set heroData on its navigate field to update the hero.
sub init()
    m.tabsGroup = m.top.findNode("tabs")
    m.content = m.top.findNode("content")
    m.clock = m.top.findNode("clock")
    m.tabTimer = m.top.findNode("tabTimer")
    m.tabTimer.observeField("fire", "onTabTimer")
    m.sections = []
    m.tabNodes = []
    m.tabViews = {}
    m.tabIndex = 0
    m.shownIndex = -1
    m.inTabs = false
    m.inGear = false
    m.inCW = false
    m.animeTask = invalid
    m.animeEntries = invalid

    ' Hero
    m.heroBg = m.top.findNode("heroBg")
    m.heroTitle = m.top.findNode("heroTitle")
    m.heroMeta = m.top.findNode("heroMeta")
    m.heroDesc = m.top.findNode("heroDesc")

    ' Gear
    m.gearSel = m.top.findNode("gearSel")
    m.gearIcon = m.top.findNode("gearIcon")

    ' Continue Watching row
    m.cwGroup = m.top.findNode("cwGroup")
    m.cwGrid = m.top.findNode("cwGrid")
    m.cwGrid.observeField("itemSelected", "onCWSelected")
    m.cwItems = []

    m.top.observeField("focusedChild", "onFocusChange")
    m.top.observeField("resumed", "onResumed")
    m.top.observeField("visible", "onVisible")

    clockTimer = m.top.findNode("clockTimer")
    clockTimer.observeField("fire", "updateClock")
    clockTimer.control = "start"
    m.animeTimer = m.top.findNode("animeTimer")
    m.animeTimer.observeField("fire", "checkAnime")
    updateClock()
end sub

sub onConfig()
    cfg = m.top.config
    m.sections = cfg.sections
    m.epgUrl = To_Str(cfg.epgUrl)
    buildTabs()
    refreshContinueWatching()
    showTab(0)
    focusContent()

    hours = To_Int(cfg.animeRefreshHours)
    if hours > 0 then m.animeTimer.duration = hours * 3600
    m.animeTimer.control = "start"
    checkAnime()
    checkUpdate(To_Str(cfg.versionUrl))
end sub

' ---------- Tab bar (centered, clean text style) ----------

function tabLabel(s as Object) as String
    t = To_Str(s.tab)
    if t = "" then t = To_Str(s.title)
    return t
end function

sub buildTabs()
    ' First pass: compute total width to center
    labels = []
    totalW = 0
    for each s in m.sections
        lbl = tabLabel(s)
        labels.Push(lbl)
        totalW = totalW + lbl.Len() * 16 + 60
    end for
    ' Build tabs
    x = 0
    for i = 0 to m.sections.Count() - 1
        g = m.tabsGroup.createChild("Group")
        g.translation = [x, 0]
        ' Underline (active indicator)
        underline = g.createChild("Rectangle")
        underline.color = "0x9B5DE5FF"
        underline.height = 3
        underline.translation = [12, 42]
        underline.visible = false
        ' Label
        lbl = g.createChild("Label")
        font = CreateObject("roSGNode", "Font")
        font.uri = "font:BoldSystemFontFile"
        font.size = 26
        lbl.font = font
        lbl.color = "0x9AA4B2FF"
        lbl.text = labels[i]
        lbl.translation = [12, 8]
        w = lbl.boundingRect().width + 24
        underline.width = w
        ' Badge (anime new episodes)
        badgeBg = g.createChild("Rectangle")
        badgeBg.color = "0xFF006EFF"
        badgeBg.height = 22
        badgeBg.translation = [w, 0]
        badgeBg.visible = false
        badgeBg.cornerRadius = 11
        badge = g.createChild("Label")
        bfont = CreateObject("roSGNode", "Font")
        bfont.uri = "font:BoldSystemFontFile"
        bfont.size = 16
        badge.font = bfont
        badge.color = "0xFFFFFFFF"
        badge.height = 22
        badge.horizAlign = "center"
        badge.vertAlign = "center"
        badge.translation = [w, 0]
        badge.visible = false
        m.tabNodes.Push({ underline: underline, label: lbl, badge: badge, badgeBg: badgeBg })
        x = x + w + 30
    end for
    ' Add settings text tab at end
    g = m.tabsGroup.createChild("Group")
    g.translation = [x, 0]
    settingsLbl = g.createChild("Label")
    sf = CreateObject("roSGNode", "Font")
    sf.uri = "font:SystemFontFile"
    sf.size = 24
    settingsLbl.font = sf
    settingsLbl.color = "0x9AA4B2FF"
    settingsLbl.text = "Configurações"
    settingsLbl.translation = [12, 10]
    m.settingsLbl = settingsLbl
    refreshTabs()
end sub

sub refreshTabs()
    for i = 0 to m.tabNodes.Count() - 1
        t = m.tabNodes[i]
        selected = (i = m.tabIndex)
        t.underline.visible = selected
        if selected
            t.label.color = "0xFFFFFFFF"
        else
            t.label.color = "0x9AA4B2FF"
        end if
        ' Brighter when tab bar is focused
        if m.inTabs and not m.inGear and selected
            t.underline.opacity = 1
        else
            t.underline.opacity = 0.6
        end if
    end for
    refreshGear()
end sub

sub refreshGear()
    if m.inGear
        m.gearSel.opacity = 0.85
        m.gearIcon.blendColor = "0xFFFFFFFF"
        m.settingsLbl.color = "0xFFFFFFFF"
    else
        m.gearSel.opacity = 0
        m.gearIcon.blendColor = "0x9AA4B2FF"
        m.settingsLbl.color = "0x9AA4B2FF"
    end if
end sub

sub setGear(on as Boolean)
    m.inGear = on
    refreshGear()
    refreshTabs()
end sub

function wrapTab(i as Integer) as Integer
    n = m.sections.Count()
    if n = 0 then return 0
    return (i + n) mod n
end function

sub selectTab(i as Integer)
    if i < 0 or i >= m.sections.Count() then return
    m.tabIndex = i
    refreshTabs()
    m.tabTimer.control = "stop"
    m.tabTimer.control = "start"
end sub

sub onTabTimer()
    showTab(m.tabIndex)
end sub

sub showTab(i as Integer)
    if i = m.shownIndex then return
    old = currentView()
    if old <> invalid
        old.active = false
        old.visible = false
        if m.sections[m.shownIndex].kind = "anime"
            Store_Set("animeSeen", Now_Seconds())
            if m.animeEntries <> invalid then updateAnimeBadge()
        end if
    end if
    m.shownIndex = i
    key = i.ToStr()
    v = m.tabViews[key]
    if v = invalid
        v = createTabView(m.sections[i])
        m.tabViews[key] = v
        m.content.appendChild(v)
    end if
    v.visible = true
    v.active = true
    ' Set hero for this tab
    updateHeroForTab(i)
end sub

function createTabView(s as Object) as Object
    kind = To_Str(s.kind)
    if kind = "live"
        v = CreateObject("roSGNode", "LiveTab")
        v.channels = s.channels
        v.epgUrl = m.epgUrl
    else if kind = "anime"
        v = CreateObject("roSGNode", "AnimeView")
        v.embedded = true
    else if kind = "grid"
        v = CreateObject("roSGNode", "GridView")
        v.embedded = true
        v.section = s
    else
        v = CreateObject("roSGNode", "CatalogView")
        v.embedded = true
        v.section = s
    end if
    v.observeField("navigate", "onTabNavigate")
    return v
end function

function currentView() as Dynamic
    if m.shownIndex < 0 then return invalid
    return m.tabViews[m.shownIndex.ToStr()]
end function

sub onTabNavigate(ev as Object)
    nav = ev.getData()
    if nav <> invalid and nav.to = "tabs"
        focusTabs()
    else if nav <> invalid and nav.hero <> invalid
        setHero(nav.hero)
    else
        m.top.navigate = nav
    end if
end sub

' ---------- Hero ----------

sub updateHeroForTab(i as Integer)
    s = m.sections[i]
    kind = To_Str(s.kind)
    title = tabLabel(s)
    if kind = "live"
        m.heroTitle.text = "TV Ao Vivo"
        m.heroMeta.text = ""
        m.heroDesc.text = "Selecione um canal para assistir"
        m.heroBg.uri = ""
    else
        m.heroTitle.text = title
        m.heroMeta.text = ""
        m.heroDesc.text = ""
        m.heroBg.uri = ""
    end if
end sub

sub setHero(data as Object)
    if data.background <> invalid and data.background <> ""
        m.heroBg.uri = To_Str(data.background)
    end if
    if data.title <> invalid
        m.heroTitle.text = To_Str(data.title)
    end if
    if data.meta <> invalid
        m.heroMeta.text = To_Str(data.meta)
    end if
    if data.description <> invalid
        m.heroDesc.text = To_Str(data.description)
    end if
end sub

' ---------- Focus ----------

sub focusTabs()
    m.inTabs = true
    refreshTabs()
    m.tabsGroup.setFocus(true)
end sub

sub focusContent()
    m.tabTimer.control = "stop"
    showTab(m.tabIndex)
    m.inTabs = false
    m.inCW = false
    refreshTabs()
    v = currentView()
    if v <> invalid then v.setFocus(true)
end sub

sub focusCW()
    m.tabTimer.control = "stop"
    showTab(m.tabIndex)
    m.inTabs = false
    m.inCW = true
    refreshTabs()
    m.cwGrid.setFocus(true)
end sub

sub onFocusChange()
    if m.inTabs
        if m.top.hasFocus() then m.tabsGroup.setFocus(true)
    else if m.inCW
        if m.top.hasFocus() then m.cwGrid.setFocus(true)
    else if m.top.hasFocus()
        v = currentView()
        if v <> invalid then v.setFocus(true)
    end if
end sub

sub onVisible()
    v = currentView()
    if v <> invalid then v.active = m.top.visible
end sub

sub onResumed()
    refreshContinueWatching()
    v = currentView()
    if v <> invalid then v.resumed = true
    if m.animeEntries <> invalid then updateAnimeBadge()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if m.inGear
        if key = "OK"
            m.top.navigate = { to: "settings", config: m.top.config }
        else if key = "down" or key = "back"
            setGear(false)
        end if
        return true
    end if
    if m.inTabs
        if key = "up"
            setGear(true)
            return true
        else if key = "left"
            selectTab(wrapTab(m.tabIndex - 1))
            return true
        else if key = "right"
            selectTab(wrapTab(m.tabIndex + 1))
            return true
        else if key = "down" or key = "OK"
            if m.cwGroup.visible
                focusCW()
            else
                focusContent()
            end if
            return true
        else if key = "options"
            setGear(true)
            return true
        else if key = "back"
            if m.top.canGoBack
                m.top.navigate = { to: "back" }
            else
                confirmExit()
            end if
            return true
        end if
        return false
    end if
    if m.inCW
        if key = "up" or key = "back"
            focusTabs()
            return true
        else if key = "down"
            focusContent()
            return true
        end if
        return false
    end if
    if key = "up" or key = "back"
        if m.cwGroup.visible
            focusCW()
        else
            focusTabs()
        end if
        return true
    end if
    return false
end function

sub confirmExit()
    m.exitDlg = CreateObject("roSGNode", "StandardMessageDialog")
    m.exitDlg.title = "Sair do TV Livre?"
    m.exitDlg.buttons = ["Continuar assistindo", "Sair"]
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
    m.tabsGroup.setFocus(true)
end sub

' ---------- Continue Watching ----------

sub refreshContinueWatching()
    recent = Recent_List()
    items = []
    root = CreateObject("roSGNode", "ContentNode")
    for each r in recent
        at = To_Int(r.at)
        if at <= 30 then continue for
        it = root.createChild("ContentNode")
        it.title = To_Str(r.title)
        kind = To_Str(r.kind)
        if kind = "grid"
            it.shortDescriptionLine1 = To_Str(r.info) + " - " + Fmt_Time(at)
        else
            it.shortDescriptionLine1 = "Parou em " + Fmt_Time(at)
        end if
        it.hdPosterUrl = To_Str(r.poster)
        dur = To_Int(r.duration)
        if dur > 60
            pct = Int(100 * at / dur)
        else
            pct = 25
            if at > 600 then pct = 35
            if at > 1800 then pct = 55
            if at > 3600 then pct = 75
        end if
        if pct > 95 then pct = 95
        if pct < 5 then pct = 5
        it.addFields({ progressPct: pct })
        items.Push(r)
        if items.Count() >= 8 then exit for
    end for
    m.cwItems = items
    m.cwGrid.content = root

    visible = items.Count() > 0
    m.cwGroup.visible = visible
    if visible
        m.content.translation = [0, 640]
    else
        m.content.translation = [0, 440]
    end if
end sub

sub onCWSelected()
    idx = m.cwGrid.itemSelected
    if idx < 0 or idx >= m.cwItems.Count() then return
    r = m.cwItems[idx]
    kind = To_Str(r.kind)
    if kind = "movie"
        m.top.navigate = {
            to: "play", urls: [To_Str(r.url)], title: To_Str(r.title),
            start: To_Int(r.at), id: To_Str(r.id),
            itemTitle: To_Str(r.title), poster: To_Str(r.poster),
            imdb: To_Str(r.imdb),
            extra: { kind: "movie", movieId: To_Str(r.movieId), url: To_Str(r.url), summary: To_Str(r.summary) }
        }
    else if kind = "grid"
        item = Grid_FindItem(To_Str(r.id))
        if item <> invalid
            m.top.navigate = { to: "gridDetail", item: item }
        end if
    else
        m.top.navigate = {
            to: "play", urls: [To_Str(r.file)], title: To_Str(r.title),
            start: To_Int(r.at), id: To_Str(r.id),
            itemTitle: To_Str(r.title), poster: To_Str(r.poster)
        }
    end if
end sub

' ---------- Clock ----------

sub updateClock()
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    m.clock.text = Pad2(dt.GetHours()) + ":" + Pad2(dt.GetMinutes())
end sub

' ---------- New anime episodes (AniList) ----------

sub checkAnime()
    if m.animeTask <> invalid then m.animeTask.unobserveField("entries")
    m.animeTask = CreateObject("roSGNode", "AniListTask")
    m.animeTask.daysAhead = 0
    m.animeTask.observeField("entries", "onAnimeEntries")
    m.animeTask.control = "run"
end sub

sub onAnimeEntries()
    m.animeEntries = m.animeTask.entries
    updateAnimeBadge()
end sub

sub updateAnimeBadge()
    lastSeen = Anime_LastSeen()
    now = Now_Seconds()
    n = 0
    for each e in m.animeEntries
        if e.airingAt > lastSeen and e.airingAt <= now then n++
    end for
    for i = 0 to m.sections.Count() - 1
        if m.sections[i].kind = "anime" and i < m.tabNodes.Count()
            t = m.tabNodes[i]
            t.badge.text = n.ToStr()
            w = t.badge.boundingRect().width + 16
            if w < 26 then w = 26
            t.badge.width = w
            t.badgeBg.width = w
            t.badge.visible = n > 0
            t.badgeBg.visible = n > 0
        end if
    end for
end sub

' ---------- App update check ----------

sub checkUpdate(url as String)
    if url = "" then return
    m.updTask = CreateObject("roSGNode", "HttpJsonTask")
    m.updTask.url = url
    m.updTask.observeField("result", "onUpdateInfo")
    m.updTask.control = "run"
end sub

sub onUpdateInfo()
    info = m.updTask.result
    latest = To_Str(info.version)
    if latest = "" then return
    current = CreateObject("roAppInfo").GetVersion()
    if Version_Compare(latest, current) <= 0 then return
    msg = To_Str(info.message)
    if msg = "" then msg = "Rode o deploy.ps1 no computador para instalar a nova versão."
    dlg = CreateObject("roSGNode", "StandardMessageDialog")
    dlg.title = "Nova versão disponível (" + latest + ")"
    dlg.message = [msg]
    dlg.buttons = ["OK"]
    dlg.observeField("buttonSelected", "closeDialog")
    m.top.getScene().dialog = dlg
end sub

sub closeDialog()
    dlg = m.top.getScene().dialog
    if dlg <> invalid then dlg.close = true
end sub
