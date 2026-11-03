sub init()
    m.card = m.top.findNode("card")
    m.shadow = m.top.findNode("shadow")
    m.bg = m.top.findNode("bg")
    m.poster = m.top.findNode("poster")
    m.title = m.top.findNode("title")
    m.sub = m.top.findNode("sub")
    m.border = m.top.findNode("border")
    m.bTop = m.top.findNode("bTop")
    m.bBot = m.top.findNode("bBot")
    m.bLeft = m.top.findNode("bLeft")
    m.bRight = m.top.findNode("bRight")
end sub

sub layout()
    w = m.top.width
    h = m.top.height
    if w <= 0 or h <= 0 then return
    m.shadow.width = w
    m.shadow.height = h
    m.bg.width = w
    m.bg.height = h
    m.title.translation = [204, 20]
    m.title.width = w - 220
    m.sub.translation = [204, 52]
    m.sub.width = w - 220
    bw = 3
    m.bTop.translation = [-bw, -bw]
    m.bTop.width = w + 2 * bw
    m.bTop.height = bw
    m.bBot.translation = [-bw, h]
    m.bBot.width = w + 2 * bw
    m.bBot.height = bw
    m.bLeft.translation = [-bw, -bw]
    m.bLeft.width = bw
    m.bLeft.height = h + 2 * bw
    m.bRight.translation = [w, -bw]
    m.bRight.width = bw
    m.bRight.height = h + 2 * bw
    m.card.scaleRotateCenter = [w / 2, h / 2]
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
    m.poster.uri = c.hdPosterUrl
    m.title.text = c.title
    m.sub.text = c.shortDescriptionLine1
end sub

sub onFocus()
    p = 0
    hasFocus = false
    if m.top.hasField("gridHasFocus") and m.top.gridHasFocus then hasFocus = true
    if hasFocus then p = m.top.focusPercent
    s = 1 + 0.04 * p
    m.card.scale = [s, s]
    m.shadow.opacity = 0.08 + 0.25 * p
    m.border.opacity = p
end sub
