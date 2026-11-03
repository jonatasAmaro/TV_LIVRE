' Home = header + tab bar. Each catalog section is a tab whose screen is created on
' first visit and kept alive. Focus is either on the tab bar (this node) or inside
' the current tab; Up/Back from a tab returns to the bar.
sub init()
    m.tabsGroup = m.top.findNode("tabs")
    m.content = m.top.findNode("content")
    m.clock = m.top.findNode("clock")
    m.date = m.top.findNode("date")
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
    buildGear()
    refreshContinueWatching()
    showTab(0)
    focusContent()

    hours = To_Int(cfg.animeRefreshHours)
    if hours > 0 then m.animeTimer.duration = hours * 3600
    m.animeTimer.control = "start"
    checkAnime()
    checkUpdate(To_Str(cfg.versionUrl))
end sub

' ---------- Tab bar ----------

function tabLabel(s as Object) as String
    t = To_Str(s.tab)
    if t = "" then t = To_Str(s.title)
    return t
end function

sub buildTabs()
    x = 0
    for each s in m.sections
        x = addTextTab(s, x)
    end for
    refreshTabs()
end sub

' Adds one text tab at x and returns the x of the next tab.
function addTextTab(s as Object, x as Integer) as Integer
    g = m.tabsGroup.createChild("Group")
    g.translation = [x, 0]
    ' Selection box: same translucent block style as the channel list.
    sel = g.createChild("Rectangle")
    sel.color = "0x9B5DE5FF"
    sel.visible = false
    lbl = g.createChild("Label")
    font = CreateObject("roSGNode", "Font")
    font.uri = "font:BoldSystemFontFile"
    font.size = 28
    lbl.font = font
    lbl.color = "0xC8D0DCFF"
    lbl.text = tabLabel(s)
    lbl.translation = [24, 12]
    w = lbl.boundingRect().width + 48
    sel.width = w
    sel.height = 58
    badgeBg = g.createChild("Rectangle")
    badgeBg.color = "0xFF006EFF"
    badgeBg.height = 30
    badgeBg.translation = [w - 18, -14]
    badgeBg.visible = false
    badge = g.createChild("Label")
    bfont = CreateObject("roSGNode", "Font")
    bfont.uri = "font:BoldSystemFontFile"
    bfont.size = 20
    badge.font = bfont
    badge.color = "0xFFFFFFFF"
    badge.height = 30
    badge.horizAlign = "center"
    badge.vertAlign = "center"
    badge.translation = [w - 18, -14]
    badge.visible = false
    m.tabNodes.Push({ sel: sel, label: lbl, badge: badge, badgeBg: badgeBg })
    return x + w + 14
end function

' Gear in the header, last item after date and clock. Reached with Up from the tab bar.
sub buildGear()
    g = m.top.createChild("Group")
    g.translation = [1782, 42]
    m.gearSel = g.createChild("Rectangle")
    m.gearSel.color = "0x9B5DE5FF"
    m.gearSel.width = 58
    m.gearSel.height = 58
    m.gearSel.opacity = 0.85
    m.gearSel.visible = false
    m.gearIcon = g.createChild("Poster")
    m.gearIcon.uri = "pkg:/images/gear.png"
    m.gearIcon.width = 40
    m.gearIcon.height = 40
    m.gearIcon.translation = [9, 9]
    m.inGear = false
    refreshGear()
end sub

sub refreshGear()
    m.gearSel.visible = m.inGear
    if m.inGear
        m.gearIcon.blendColor = "0xFFFFFFFF"
    else
        m.gearIcon.blendColor = "0x9AA4B2FF"
    end if
end sub

sub setGear(on as Boolean)
    m.inGear = on
    refreshGear()
    refreshTabs()
end sub

sub refreshTabs()
    for i = 0 to m.tabNodes.Count() - 1
        t = m.tabNodes[i]
        selected = (i = m.tabIndex)
        t.sel.visible = selected
        ' Strong while the tab bar has focus, faint while browsing the tab below.
        if m.inTabs and not m.inGear
            t.sel.opacity = 0.85
        else
            t.sel.opacity = 0.35
        end if
        if selected
            t.label.color = "0xFFFFFFFF"
        else
            t.label.color = "0x9AA4B2FF"
        end if
    end for
end sub

' Left on the first tab goes to the last one and vice versa.
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
        ' Leaving the anime tab marks the listed episodes as seen.
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

    else
        m.top.navigate = nav
    end if
end sub

' The tab bar group holds focus (keys bubble from it to onKeyEvent here).
' Focusing this node itself would be ignored while a tab descendant has focus.
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

' Scene hides Home while another screen is pushed on top of it.
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
        ' Calculate progress percentage from saved duration; estimate if unknown
        dur = To_Int(r.duration)
        if dur > 60
            pct = Int(100 * at / dur)
        else
            ' No duration saved — rough estimate based on position
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
    ' Shift tab content down when CW row is visible
    if visible
        m.cwGroup.translation = [0, 200]
        adjustContentOffset(620)
    else
        adjustContentOffset(200)
    end if
end sub

sub adjustContentOffset(y as Integer)
    ' Each embedded tab view positions itself relative to the content group.
    ' The content group doesn't move, but the tabs built inside adapt via their
    ' own translation. We shift the content group.
    m.content.translation = [0, y - 200]
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
        ' Open the series screen; it will resume at the saved position.
        item = Grid_FindItem(To_Str(r.id))
        if item <> invalid
            m.top.navigate = { to: "gridDetail", item: item }
        end if
    else
        ' Archive item
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
    m.date.text = Fmt_LongDate(dt)
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
            w = t.badge.boundingRect().width + 20
            if w < 30 then w = 30
            t.badge.width = w
            t.badgeBg.width = w
            t.badge.visible = n > 0
            t.badgeBg.visible = n > 0
        end if
    end for
end sub

' ---------- App update check (optional, versionUrl in catalog.json) ----------

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
