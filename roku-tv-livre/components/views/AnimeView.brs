' Weekly anime release calendar. Metadata only: AniList lists the official
' services (Crunchyroll, Netflix...) where each episode can be watched.
sub init()
    m.rows = m.top.findNode("rows")
    m.status = m.top.findNode("status")
    m.rowData = []
    m.dlg = invalid
    m.lastSeen = Anime_LastSeen()

    m.rows.observeField("rowItemSelected", "onItemSelected")
    m.top.observeField("focusedChild", "onFocusChange")
    m.top.observeField("closing", "onClosing")
    m.top.observeField("embedded", "onEmbedded")
    load()
end sub

sub onEmbedded()
    if not m.top.embedded then return
    m.top.findNode("title").visible = false
    m.top.findNode("subtitle").visible = false
    m.rows.translation = [80, 250]
    m.status.translation = [80, 560]
end sub

sub onFocusChange()
    if m.top.hasFocus() and m.rows.content <> invalid then m.rows.setFocus(true)
end sub

sub load()
    m.status.text = "Procurando episódios novos..."
    m.status.visible = true
    m.task = CreateObject("roSGNode", "AniListTask")
    m.task.observeField("entries", "onEntries")
    m.task.control = "run"
end sub

sub onEntries()
    now = Now_Seconds()
    today = []
    week = []
    soon = []
    for each e in m.task.entries
        if e.airingAt > now
            soon.Push(e)
        else if now - e.airingAt <= 86400
            today.Push(e)
        else
            week.Push(e)
        end if
    end for

    root = CreateObject("roSGNode", "ContentNode")
    m.rowData = []
    addRow(root, "Saíram nas últimas 24 horas", Arr_Reverse(today), now)
    addRow(root, "Últimos 7 dias", Arr_Reverse(week), now)
    addRow(root, "Próximos episódios", soon, now)

    if root.getChildCount() = 0
        m.status.text = "Não foi possível carregar o calendário. Verifique a internet."
        return
    end if
    m.status.visible = false
    m.rows.content = root
    if m.top.hasFocus() then m.rows.setFocus(true)
end sub

sub addRow(root as Object, title as String, list as Object, now as Integer)
    if list.Count() = 0 then return
    row = root.createChild("ContentNode")
    row.title = title + "  (" + list.Count().ToStr() + ")"
    for each e in list
        it = row.createChild("ContentNode")
        it.title = e.title
        it.shortDescriptionLine1 = "Ep. " + e.episode.ToStr() + "  •  " + Fmt_LocalDate(e.airingAt)
        it.hdPosterUrl = e.cover
        it.addFields({ isNew: (e.airingAt > m.lastSeen and e.airingAt <= now) })
    end for
    m.rowData.Push(list)
end sub

sub onItemSelected()
    sel = m.rows.rowItemSelected
    e = m.rowData[sel[0]][sel[1]]
    where = "Ainda sem serviço oficial listado no AniList."
    if e.links.Count() > 0 then where = "Onde assistir: " + e.links.Join(", ")
    desc = e.description
    if Len(desc) > 450 then desc = Left(desc, 450) + "..."
    msg = [Fmt_LocalDate(e.airingAt) + "   •   " + e.genres, where]
    if desc <> "" then msg.Push(desc)

    m.dlg = CreateObject("roSGNode", "StandardMessageDialog")
    m.dlg.title = e.title + "  -  Episódio " + e.episode.ToStr()
    m.dlg.message = msg
    m.dlg.buttons = ["Fechar"]
    m.dlg.observeField("buttonSelected", "closeDialog")
    m.dlg.observeField("wasClosed", "onDialogClosed")
    m.top.getScene().dialog = m.dlg
end sub

sub closeDialog()
    if m.dlg <> invalid then m.dlg.close = true
end sub

sub onDialogClosed()
    m.dlg = invalid
    m.rows.setFocus(true)
end sub

sub onClosing()
    ' Everything listed up to now counts as "seen" for the home badge.
    Store_Set("animeSeen", Now_Seconds())
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press and key = "options"
        load()
        return true
    end if
    return false
end function
