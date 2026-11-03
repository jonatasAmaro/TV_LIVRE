' Navigation stack: every screen is a BaseView that asks to move via its "navigate" field.
sub init()
    m.top.backgroundUri = ""
    m.top.backgroundColor = "0x0B0F1AFF"
    m.views = m.top.findNode("views")
    m.stack = []
    ' The launcher (wallpaper + app carousel) is the first screen; TV Livre opens from it.
    pushView(CreateObject("roSGNode", "LauncherView"))
    ' Online catalog refresh; TV Livre reads it the next time it opens.
    m.sync = CreateObject("roSGNode", "CatalogSyncTask")
    m.sync.observeField("result", "onCatalogSync")
    m.sync.control = "run"

    ' Screensaver after 5 min idle
    m.screenSaver = m.top.findNode("screenSaver")
    m.idleTimer = m.top.findNode("idleTimer")
    m.idleTimer.observeField("fire", "onIdleTimeout")
    m.ssActive = false
    resetIdleTimer()
end sub

sub onCatalogSync()
    print "[catalog] "; m.sync.result
end sub

sub pushView(v as Object)
    if m.stack.Count() > 0 then m.stack.Peek().visible = false
    v.observeField("navigate", "onNavigate")
    m.views.appendChild(v)
    m.stack.Push(v)
    v.setFocus(true)
end sub

sub popView()
    if m.stack.Count() <= 1 then return
    v = m.stack.Pop()
    v.unobserveField("navigate")
    v.closing = true
    m.views.removeChild(v)
    top = m.stack.Peek()
    top.visible = true
    top.setFocus(true)
    top.resumed = true
end sub

sub onNavigate(ev as Object)
    nav = ev.getData()
    if nav = invalid or nav.to = invalid then return
    target = nav.to
    if target = "back"
        popView()
    else if target = "tvlivre"
        v = CreateObject("roSGNode", "HomeView")
        v.canGoBack = true
        v.config = Cfg_Load()
        pushView(v)
    else if target = "liveGrid"
        v = CreateObject("roSGNode", "LiveGridView")
        v.epgUrl = To_Str(nav.epgUrl)
        if nav.startIndex <> invalid then v.startIndex = nav.startIndex
        if nav.viewTitle <> invalid then v.viewTitle = To_Str(nav.viewTitle)
        if nav.viewTheme <> invalid then v.viewTheme = To_Str(nav.viewTheme)
        v.channels = nav.channels
        pushView(v)
    else if target = "seriesGrid" or target = "animeGrid"
        v = CreateObject("roSGNode", "GridView")
        v.section = nav.section
        pushView(v)
    else if target = "youtubeGrid"
        v = CreateObject("roSGNode", "YouTubeGridView")
        v.channels = nav.channels
        pushView(v)
    else if target = "moviesGrid"
        sec = nav.section
        if sec.rows <> invalid and sec.categories = invalid
            sec.categories = sec.rows
            sec.search = true
        end if
        v = CreateObject("roSGNode", "GridView")
        v.section = sec
        pushView(v)
    else if target = "catalog"
        v = CreateObject("roSGNode", "CatalogView")
        v.section = nav.section
        pushView(v)
    else if target = "anime"
        pushView(CreateObject("roSGNode", "AnimeView"))
    else if target = "details"
        v = CreateObject("roSGNode", "DetailsView")
        v.item = nav.item
        pushView(v)
    else if target = "movieDetail"
        v = CreateObject("roSGNode", "MovieDetailView")
        v.item = nav.item
        pushView(v)
    else if target = "gridDetail"
        v = CreateObject("roSGNode", "GridDetailView")
        v.item = nav.item
        pushView(v)
    else if target = "settings"
        v = CreateObject("roSGNode", "SettingsView")
        v.config = nav.config
        pushView(v)
    else if target = "refreshAnime"
        m.stack[0].refreshAnime = true
    else if target = "play"
        v = CreateObject("roSGNode", "PlayerView")
        v.params = nav
        pushView(v)
    end if
end sub

sub resetIdleTimer()
    m.idleTimer.control = "stop"
    m.idleTimer.control = "start"
end sub

sub onIdleTimeout()
    if m.ssActive then return
    m.ssActive = true
    v = m.stack.Peek()
    if v <> invalid
        m.screenSaver.posterUri = To_Str(v.getField("poster"))
        m.screenSaver.title = To_Str(v.getField("title"))
    end if
    m.screenSaver.active = true
end sub

sub dismissScreenSaver()
    m.ssActive = false
    m.screenSaver.active = false
    resetIdleTimer()
    top = m.stack.Peek()
    if top <> invalid then top.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    resetIdleTimer()
    if m.ssActive
        dismissScreenSaver()
        return true
    end if
    if key = "back" and m.stack.Count() > 1
        popView()
        return true
    end if
    return false
end function
