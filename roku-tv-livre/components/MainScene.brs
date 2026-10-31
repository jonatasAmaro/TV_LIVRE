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

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back" and m.stack.Count() > 1
        popView()
        return true
    end if
    return false
end function
