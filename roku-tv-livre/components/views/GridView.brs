sub init()
    m.grid = m.top.findNode("grid")
    m.titleLbl = m.top.findNode("title")
    m.subtitle = m.top.findNode("subtitle")
    m.status = m.top.findNode("status")
    m.items = []

    m.grid.observeField("itemSelected", "onItemSelected")
    m.top.observeField("focusedChild", "onFocusChange")
end sub

sub onFocusChange()
    if m.top.hasFocus() and m.items.Count() > 0
        m.grid.setFocus(true)
    end if
end sub

sub onSection()
    s = m.top.section
    m.titleLbl.text = To_Str(s.title)
    m.subtitle.text = To_Str(s.subtitle)
    if m.top.embedded
        m.titleLbl.visible = false
        m.subtitle.visible = false
        m.grid.translation = [80, 250]
    end if
    m.items = s.items
    loadGrid()
end sub

sub loadGrid()
    root = CreateObject("roSGNode", "ContentNode")
    for each item in m.items
        n = root.createChild("ContentNode")
        n.title = To_Str(item.title)
        n.hdPosterUrl = To_Str(item.poster)
        n.addFields({ fit: true })
    end for
    m.grid.content = root
    if m.items.Count() = 0
        m.status.text = "Nenhum item configurado."
        m.status.visible = true
    end if
end sub

sub onItemSelected()
    idx = m.grid.itemSelected
    if idx < 0 or idx >= m.items.Count() then return
    item = m.items[idx]
    m.top.navigate = { to: "gridDetail", item: item }
end sub
