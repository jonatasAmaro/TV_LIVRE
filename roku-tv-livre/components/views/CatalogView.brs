' Row-based catalog used by every section except Animes:
' kind = live | youtube | archive | movies | favorites | search
sub init()
    m.rows = m.top.findNode("rows")
    m.status = m.top.findNode("status")
    m.title = m.top.findNode("title")
    m.subtitle = m.top.findNode("subtitle")
    m.root = CreateObject("roSGNode", "ContentNode")
    m.task = invalid
    m.kb = invalid
    m.kind = ""
    m.moviesSig = ""

    m.rows.observeField("rowItemSelected", "onItemSelected")
    m.top.observeField("focusedChild", "onFocusChange")
    m.top.observeField("resumed", "onResumed")
    m.top.observeField("closing", "onClosing")
    m.top.observeField("active", "onActive")
end sub

sub onFocusChange()
    if not m.top.hasFocus() then return
    if m.root.getChildCount() > 0
        m.rows.setFocus(true)
    else if m.kind = "search" and m.kb = invalid
        openKeyboard()
    end if
end sub

sub onSection()
    s = m.top.section
    m.kind = To_Str(s.kind)
    m.title.text = To_Str(s.title)
    m.subtitle.text = To_Str(s.subtitle)
    if m.top.embedded
        ' Home draws the header; the rows start right under the tab bar.
        m.title.visible = false
        m.subtitle.visible = false
        m.rows.translation = [80, 250]
        m.status.translation = [80, 560]
    end if
    if m.kind = "live" or m.kind = "youtube"
        loadLive(s.channels, m.kind)
        if m.kind = "youtube" then loadYouTubeThumbs(s.channels)
    else if m.kind = "archive"
        loadArchive(s.rows)
    else if m.kind = "movies"
        loadMovies(s.rows)
    else if m.kind = "favorites"
        loadFavorites()
    else if m.kind = "search"
        m.subtitle.text = "Pressione * para buscar de novo"
        if m.top.embedded
            showStatus("Aperte OK para buscar filmes, séries e desenhos")
        else
            m.status.text = ""
            openKeyboard()
        end if
    end if
end sub

sub onResumed()
    refreshRecent()
end sub

sub onActive()
    if m.top.active then refreshRecent()
end sub

' Watching something changes "Continuar assistindo"; Filmes rebuilds only when its row changed.
sub refreshRecent()
    if m.kind = "favorites"
        loadFavorites()
    else if m.kind = "movies" and recentSignature(recentMovies()) <> m.moviesSig
        loadMovies(m.top.section.rows)
    end if
end sub

' Card art = thumbnail of the channel's current live (or latest) broadcast.
sub loadYouTubeThumbs(channels as Object)
    m.thumbTask = CreateObject("roSGNode", "YouTubeTask")
    m.thumbTask.mode = "info"
    m.thumbTask.channels = channels
    m.thumbTask.observeField("result", "onYouTubeThumbs")
    m.thumbTask.control = "run"
end sub

sub onYouTubeThumbs()
    infos = m.thumbTask.result.infos
    if infos = invalid then return
    for r = 0 to m.root.getChildCount() - 1
        row = m.root.getChild(r)
        for c = 0 to row.getChildCount() - 1
            it = row.getChild(c)
            info = infos[it.itemId]
            if info <> invalid and info.videoId <> ""
                ' A new node makes the RowList redraw the card.
                fresh = CreateObject("roSGNode", "ContentNode")
                fresh.title = it.title
                fresh.shortDescriptionLine1 = it.shortDescriptionLine1
                fresh.hdPosterUrl = "https://i.ytimg.com/vi/" + info.videoId + "/hqdefault.jpg"
                fresh.addFields({ itype: it.itype, itemId: it.itemId, streamUrl: it.streamUrl, ytChannel: it.ytChannel })
                if Is_True(info.live)
                    fresh.shortDescriptionLine1 = "AO VIVO agora"
                    fresh.addFields({ isNew: true, badgeText: "AO VIVO" })
                end if
                row.replaceChild(fresh, c)
            end if
        end for
    end for
end sub

sub onClosing()
    if m.task <> invalid then m.task.control = "stop"
end sub

' ---------- Content ----------

sub resetRows()
    m.root = CreateObject("roSGNode", "ContentNode")
    m.rows.content = invalid
end sub

sub addRow(row as Object)
    m.root.appendChild(row)
    if m.rows.content = invalid then m.rows.content = m.root
    m.status.visible = false
    if m.top.hasFocus() then m.rows.setFocus(true)
end sub

sub showStatus(text as String)
    m.status.text = text
    m.status.visible = true
end sub

' One row per channel "group" (order of first appearance in catalog.json).
' itype "live" plays the HLS url here; "youtube" hands the channel to the YouTube app.
sub loadLive(channels as Object, itype as String)
    resetRows()
    rows = {}
    order = []
    defaultGroup = "Canais oficiais ao vivo"
    if itype = "youtube" then defaultGroup = "Canais do YouTube   (OK abre o ao vivo no app do YouTube)"
    for each ch in channels
        group = To_Str(ch.group)
        if group = "" then group = defaultGroup
        row = rows[group]
        if row = invalid
            row = CreateObject("roSGNode", "ContentNode")
            row.title = group
            rows[group] = row
            order.Push(row)
        end if
        it = row.createChild("ContentNode")
        it.title = To_Str(ch.title)
        it.shortDescriptionLine1 = To_Str(ch.info)
        it.hdPosterUrl = To_Str(ch.logo)
        it.addFields({ itype: itype, itemId: To_Str(ch.id), streamUrl: To_Str(ch.url), ytChannel: To_Str(ch.channelId) })
    end for
    for each row in order
        addRow(row)
    end for
end sub

' Rows of portrait cards written in catalog.json:
' rows = [{ title, items: [{ id, title, year, poster, url, summary }] }].
' OK opens the movie's details screen, whose Assistir plays "url".
sub loadMovies(rows as Object)
    resetRows()
    m.rows.itemSize = [1840, 370]
    m.rows.itemSpacing = [0, 60]
    m.rows.rowItemSize = [[200, 370]]
    m.rows.rowItemSpacing = [[24, 0]]
    m.rows.numRows = 2
    if rows = invalid then rows = []
    recent = recentMovies()
    m.moviesSig = recentSignature(recent)
    if recent.Count() > 0
        row = CreateObject("roSGNode", "ContentNode")
        row.title = "Continuar assistindo"
        for each r in recent
            addRecentCard(row, r)
        end for
        addRow(row)
    end if
    for each r in rows
        row = CreateObject("roSGNode", "ContentNode")
        row.title = To_Str(r.title)
        if r.items <> invalid
            for each mv in r.items
                it = row.createChild("ContentNode")
                it.title = To_Str(mv.title)
                it.shortDescriptionLine1 = To_Str(mv.year)
                it.hdPosterUrl = To_Str(mv.poster)
                it.addFields({ itype: "movie", itemId: To_Str(mv.id), streamUrl: To_Str(mv.url), summary: To_Str(mv.summary), fit: true })
            end for
        end if
        if row.getChildCount() > 0 then addRow(row)
    end for
    if m.root.getChildCount() = 0 then showStatus("Nenhum filme configurado.")
end sub

sub loadArchive(rows as Object)
    if m.task <> invalid then m.task.control = "stop"
    resetRows()
    showStatus("Carregando...")
    m.task = CreateObject("roSGNode", "ArchiveRowsTask")
    m.task.rows = rows
    m.task.observeField("row", "onRow")
    m.task.observeField("done", "onDone")
    m.task.control = "run"
end sub

sub onRow()
    row = m.task.row
    if row <> invalid then addRow(row)
end sub

sub onDone()
    if m.root.getChildCount() = 0 then showStatus("Nada encontrado. Verifique a conexão com a internet.")
end sub

sub loadFavorites()
    resetRows()
    recent = CreateObject("roSGNode", "ContentNode")
    recent.title = "Continuar assistindo"
    for each r in Recent_List()
        if To_Int(r.at) > 30 then addRecentCard(recent, r)
    end for
    favs = CreateObject("roSGNode", "ContentNode")
    favs.title = "Minha Lista"
    for each f in Fav_List()
        it = favs.createChild("ContentNode")
        it.title = To_Str(f.title)
        it.hdPosterUrl = To_Str(f.poster)
        ' Series cards (kind "grid") open the series screen; the rest are Archive items.
        if To_Str(f.kind) = "grid"
            it.addFields({ itype: "grid", itemId: To_Str(f.id), fit: true })
        else
            it.addFields({ itype: "archive", itemId: To_Str(f.id) })
        end if
    end for
    if recent.getChildCount() > 0 then addRow(recent)
    if favs.getChildCount() > 0 then addRow(favs)
    if m.root.getChildCount() = 0
        showStatus("Sua lista está vazia." + Chr(10) + "Abra um filme e escolha 'Adicionar à Minha Lista'.")
        m.top.setFocus(true)
    end if
end sub

' Card for a "recent" entry: Archive item, movie (kind "movie") or series (kind "grid").
sub addRecentCard(row as Object, r as Object)
    it = row.createChild("ContentNode")
    it.title = To_Str(r.title)
    it.shortDescriptionLine1 = "Parou em " + Fmt_Time(To_Int(r.at))
    it.hdPosterUrl = To_Str(r.poster)
    kind = To_Str(r.kind)
    if kind = "movie"
        it.addFields({ itype: "movie", itemId: To_Str(r.movieId), streamUrl: To_Str(r.url), summary: To_Str(r.summary), fit: true })
    else if kind = "grid"
        it.shortDescriptionLine1 = To_Str(r.info) + " - " + Fmt_Time(To_Int(r.at))
        it.addFields({ itype: "grid", itemId: To_Str(r.id), fit: true })
    else
        it.addFields({ itype: "archive", itemId: To_Str(r.id) })
    end if
end sub

' Movies left halfway, for the top row of Filmes; the signature tells if it changed.
function recentMovies() as Object
    out = []
    for each r in Recent_List()
        if To_Str(r.kind) = "movie" and To_Int(r.at) > 30 then out.Push(r)
    end for
    return out
end function

function recentSignature(list as Object) as String
    sig = ""
    for each r in list
        sig = sig + To_Str(r.id) + "@" + To_Str(r.at) + ";"
    end for
    return sig
end function

' ---------- Search ----------

sub openKeyboard()
    kb = CreateObject("roSGNode", "StandardKeyboardDialog")
    kb.title = "Buscar filmes, séries e desenhos"
    kb.message = ["Dica: títulos costumam estar em inglês (ex.: chaplin, zorro, popeye)"]
    kb.buttons = ["Buscar", "Cancelar"]
    kb.observeField("buttonSelected", "onKbButton")
    kb.observeField("wasClosed", "onKbClosed")
    m.kb = kb
    m.top.getScene().dialog = kb
end sub

sub onKbButton()
    idx = m.kb.buttonSelected
    text = CreateObject("roRegex", "[()\[\]{}:\x22\\^~*?!+\-/]", "").ReplaceAll(m.kb.text, " ").Trim()
    m.kb.close = true
    if idx = 0 and text <> ""
        m.title.text = "Busca: " + text
        coll = "(collection:feature_films OR collection:classic_tv OR collection:classic_cartoons OR collection:animationandcartoons)"
        q = "(title:(" + text + ") OR subject:(" + text + ") OR description:(" + text + ")) AND " + coll
        loadArchive([{ title: "Resultados", q: q }])
    end if
end sub

sub onKbClosed()
    m.kb = invalid
    if m.root.getChildCount() > 0
        m.rows.setFocus(true)
    else if m.top.embedded
        ' Back to the tab bar; results (if any) show up when they arrive.
        m.top.navigate = { to: "tabs" }
    else if m.task = invalid
        m.top.navigate = { to: "back" }
    else
        m.top.setFocus(true)
    end if
end sub

' ---------- Selection ----------

sub onItemSelected()
    sel = m.rows.rowItemSelected
    item = m.rows.content.getChild(sel[0]).getChild(sel[1])
    if item.itype = "live"
        m.top.navigate = { to: "play", urls: [item.streamUrl], title: item.title, live: true }
    else if item.itype = "youtube"
        openYouTube(item)
    else if item.itype = "movie"
        playMovie(item)
    else if item.itype = "grid"
        series = Grid_FindItem(item.itemId)
        if series <> invalid then m.top.navigate = { to: "gridDetail", item: series }
    else
        m.top.navigate = { to: "details", item: { id: item.itemId, title: item.title, poster: item.hdPosterUrl } }
    end if
end sub

sub playMovie(item as Object)
    m.top.navigate = { to: "movieDetail", item: { id: item.itemId, title: item.title, poster: item.hdPosterUrl, url: item.streamUrl, summary: item.summary } }
end sub

' ---------- YouTube (official app via deep link) ----------

sub openYouTube(item as Object)
    m.ytTitle = item.title
    showStatus("Procurando a transmissão ao vivo de " + item.title + "...")
    runYouTubeTask({ mode: "live", channelId: item.ytChannel })
end sub

sub runYouTubeTask(params as Object)
    m.ytTask = CreateObject("roSGNode", "YouTubeTask")
    m.ytTask.setFields(params)
    m.ytTask.observeField("result", "onYouTubeResult")
    m.ytTask.control = "run"
end sub

sub onYouTubeResult()
    r = m.ytTask.result
    m.status.visible = false
    if Is_True(r.launched) then return
    if Is_True(r.live) or r.latestId = invalid or r.latestId = ""
        showDialog("Não consegui abrir o YouTube", ["Abra o app do YouTube pela tela inicial da Roku e procure por " + m.ytTitle + "."], ["OK"])
        m.ytLatest = invalid
    else
        m.ytLatest = r.latestId
        msg = []
        if r.nextTitle <> invalid and r.nextTitle <> "" then msg.Push("Próxima transmissão: " + r.nextTitle)
        msg.Push("Mais recente: " + r.latestTitle)
        showDialog(m.ytTitle + " não está ao vivo agora", msg, ["Assistir o mais recente", "Cancelar"])
    end if
end sub

sub showDialog(title as String, message as Object, buttons as Object)
    m.dlg = CreateObject("roSGNode", "StandardMessageDialog")
    m.dlg.title = title
    m.dlg.message = message
    m.dlg.buttons = buttons
    m.dlg.observeField("buttonSelected", "onDialogButton")
    m.dlg.observeField("wasClosed", "onDialogClosed")
    m.top.getScene().dialog = m.dlg
end sub

sub onDialogButton()
    idx = m.dlg.buttonSelected
    m.dlg.close = true
    if idx = 0 and m.ytLatest <> invalid
        runYouTubeTask({ mode: "launch", videoId: m.ytLatest, mediaType: "movie" })
        m.ytLatest = invalid
    end if
end sub

sub onDialogClosed()
    m.rows.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press and key = "options" and m.kind = "search"
        openKeyboard()
        return true
    end if
    return false
end function
