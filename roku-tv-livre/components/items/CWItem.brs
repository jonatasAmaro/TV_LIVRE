sub init()
    m.poster = m.top.findNode("poster")
    m.ring = m.top.findNode("ring")
    m.pbarFill = m.top.findNode("pbarFill")
    m.titleLbl = m.top.findNode("title")
    m.infoLbl = m.top.findNode("info")
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
    m.poster.uri = c.hdPosterUrl
    m.titleLbl.text = c.title

    ' Info line: "T2 EP 5 - 12:30" or "Parou em 1:23:45"
    m.infoLbl.text = c.shortDescriptionLine1

    ' Progress bar: progressPct is 0-100 stored as a custom field
    pct = 0
    if c.hasField("progressPct") then pct = c.progressPct
    if pct > 100 then pct = 100
    if pct < 0 then pct = 0
    m.pbarFill.width = Int(190 * pct / 100)
end sub

sub onFocus()
    m.ring.visible = (m.top.focusPercent > 0.5)
end sub
