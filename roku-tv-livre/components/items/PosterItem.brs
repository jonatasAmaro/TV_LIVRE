sub init()
    m.card = m.top.findNode("card")
    m.ring = m.top.findNode("ring")
    m.bg = m.top.findNode("bg")
    m.poster = m.top.findNode("poster")
    m.title = m.top.findNode("title")
    m.sub = m.top.findNode("sub")
    m.badge = m.top.findNode("badge")
    m.badgeBg = m.top.findNode("badgeBg")
end sub

sub layout()
    w = m.top.width
    h = m.top.height
    if w <= 0 or h <= 0 then return
    ph = h - 70
    m.ring.width = w + 10
    m.ring.height = ph + 10
    m.bg.width = w
    m.bg.height = ph
    m.poster.width = w
    m.poster.height = ph
    m.title.translation = [0, ph + 8]
    m.title.width = w
    m.sub.translation = [0, ph + 40]
    m.sub.width = w
    m.card.scaleRotateCenter = [w / 2, ph / 2]
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
    ' "fit": show the whole image inside the card instead of cropping it to fill.
    if c.hasField("fit") and c.fit
        m.poster.loadDisplayMode = "scaleToFit"
    else
        m.poster.loadDisplayMode = "scaleToZoom"
    end if
    m.poster.uri = c.hdPosterUrl
    m.title.text = c.title
    m.sub.text = c.shortDescriptionLine1
    isNew = false
    if c.hasField("isNew") then isNew = c.isNew
    m.badge.text = "NOVO"
    if c.hasField("badgeText") then m.badge.text = c.badgeText
    m.badge.visible = isNew
    m.badgeBg.visible = isNew
end sub

sub onFocus()
    p = 0
    hasFocus = m.top.rowListHasFocus
    if m.top.hasField("gridHasFocus") and m.top.gridHasFocus then hasFocus = true
    rfp = m.top.rowFocusPercent
    if rfp = 0 and hasFocus then rfp = 1
    if hasFocus then p = m.top.focusPercent * rfp
    s = 1 + 0.05 * p
    m.card.scale = [s, s]
    m.ring.opacity = p
end sub
