sub init()
    m.selected = 0
    m.count = 3
    m.rings = []
    m.names = []
    for i = 0 to m.count - 1
        m.rings.Push(m.top.findNode("ring" + i.ToStr()))
        m.names.Push(m.top.findNode("name" + i.ToStr()))
    end for
    updateFocus()
end sub

sub updateFocus()
    for i = 0 to m.count - 1
        if i = m.selected
            m.rings[i].visible = true
            m.names[i].color = "0xFFFFFFFF"
        else
            m.rings[i].visible = false
            m.names[i].color = "0xC8D0DCFF"
        end if
    end for
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "left"
        if m.selected > 0
            m.selected = m.selected - 1
            updateFocus()
        end if
        return true
    else if key = "right"
        if m.selected < m.count - 1
            m.selected = m.selected + 1
            updateFocus()
        end if
        return true
    else if key = "OK"
        m.top.navigate = { to: "tvlivre" }
        return true
    end if
    return false
end function
