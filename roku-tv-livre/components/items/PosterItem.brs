sub init()
    m.card = m.top.findNode("card")
    m.shadow = m.top.findNode("shadow")
    m.bg = m.top.findNode("bg")
    m.poster = m.top.findNode("poster")
    m.title = m.top.findNode("title")
    m.sub = m.top.findNode("sub")
    m.badge = m.top.findNode("badge")
    m.badgeBg = m.top.findNode("badgeBg")
    m.border = m.top.findNode("border")
    m.borderTop = m.top.findNode("borderTop")
    m.borderBottom = m.top.findNode("borderBottom")
    m.borderLeft = m.top.findNode("borderLeft")
    m.borderRight = m.top.findNode("borderRight")
    m.overlayBg = m.top.findNode("overlayBg")
    m.overlayHint = m.top.findNode("overlayHint")
end sub

sub layout()
    w = m.top.width
    h = m.top.height
    if w <= 0 or h <= 0 then return
    ph = h - 70
    m.shadow.width = w
    m.shadow.height = ph
    m.bg.width = w
    m.bg.height = ph
    m.poster.width = w
    m.poster.height = ph
    bw = 3
    m.borderTop.translation = [-bw, -bw]
    m.borderTop.width = w + 2 * bw
    m.borderTop.height = bw
    m.borderBottom.translation = [-bw, ph]
    m.borderBottom.width = w + 2 * bw
    m.borderBottom.height = bw
    m.borderLeft.translation = [-bw, -bw]
    m.borderLeft.width = bw
    m.borderLeft.height = ph + 2 * bw
    m.borderRight.translation = [w, -bw]
    m.borderRight.width = bw
    m.borderRight.height = ph + 2 * bw
    m.title.translation = [0, ph + 8]
    m.title.width = w
    m.sub.translation = [0, ph + 40]
    m.sub.width = w
    m.card.scaleRotateCenter = [w / 2, ph / 2]
    oH = 34
    m.overlayBg.translation = [0, ph - oH]
    m.overlayBg.width = w
    m.overlayBg.height = oH
    buildOverlayHint(w, ph, oH)
end sub

sub buildOverlayHint(w as Integer, ph as Integer, oH as Integer)
    m.overlayHint.removeChildrenIndex(m.overlayHint.getChildCount(), 0)
    badgeW = 36
    badgeH = 22
    txt = "Detalhes"
    txtW = Len(txt) * 10
    totalW = badgeW + 6 + txtW
    startX = Cint((w - totalW) / 2)
    yBase = ph - oH + Cint((oH - badgeH) / 2)
    r1 = CreateObject("roSGNode", "Rectangle")
    r1.translation = [startX, yBase]
    r1.width = badgeW
    r1.height = badgeH
    r1.color = "0xFFFFFF50"
    m.overlayHint.appendChild(r1)
    r2 = CreateObject("roSGNode", "Rectangle")
    r2.translation = [startX + 1, yBase + 1]
    r2.width = badgeW - 2
    r2.height = badgeH - 2
    r2.color = "0x222233FF"
    m.overlayHint.appendChild(r2)
    lbl = CreateObject("roSGNode", "Label")
    lbl.translation = [startX, yBase + 2]
    lbl.width = badgeW
    lbl.height = badgeH - 2
    lbl.horizAlign = "center"
    lbl.color = "0xFFFFFFFF"
    f = CreateObject("roSGNode", "Font")
    f.uri = "font:BoldSystemFontFile"
    f.size = 13
    lbl.font = f
    lbl.text = "OK"
    m.overlayHint.appendChild(lbl)
    txtLbl = CreateObject("roSGNode", "Label")
    txtLbl.translation = [startX + badgeW + 6, yBase + 2]
    txtLbl.width = txtW
    txtLbl.height = badgeH
    txtLbl.color = "0xDDE3EAFF"
    tf = CreateObject("roSGNode", "Font")
    tf.uri = "font:SystemFontFile"
    tf.size = 15
    txtLbl.font = tf
    txtLbl.text = txt
    m.overlayHint.appendChild(txtLbl)
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
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
    s = 1 + 0.10 * p
    m.card.scale = [s, s]
    m.shadow.opacity = 0.20 + 0.25 * p
    m.border.opacity = p
    focused = (p > 0.5)
    m.overlayBg.visible = focused
    m.overlayHint.visible = focused
end sub
