sub init()
    m.bg = m.top.findNode("bg")
    m.ring = m.top.findNode("ring")
    m.lbl = m.top.findNode("lbl")
    m.check = m.top.findNode("check")
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
    m.lbl.text = c.title
    watched = false
    if c.doesExist("WATCHED") then watched = (c.WATCHED.ToStr() = "true")
    m.check.visible = watched
    if watched
        m.bg.color = "0x1A2A40FF"
    end if
end sub

sub onFocus()
    ' Used both in a MarkupGrid (gridHasFocus) and in a RowList (rowListHasFocus).
    hasFocus = m.top.gridHasFocus or m.top.rowListHasFocus
    p = m.top.focusPercent
    if not hasFocus then p = 0
    m.ring.opacity = p
    if p > 0.5
        m.bg.color = "0x9B5DE5FF"
        m.lbl.color = "0xFFFFFFFF"
    else
        m.bg.color = "0x2A3A5CFF"
        m.lbl.color = "0xFFFFFFFF"
    end if
end sub
