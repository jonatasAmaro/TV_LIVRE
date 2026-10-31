sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.poster = m.top.findNode("poster")
    m.titleLbl = m.top.findNode("title")
    m.metaLbl = m.top.findNode("meta")
    m.desc = m.top.findNode("desc")
    m.actions = m.top.findNode("actions")
    m.epTitle = m.top.findNode("epTitle")
    m.episodes = m.top.findNode("episodes")
    m.info = invalid
    m.actionIds = []

    m.actions.observeField("itemSelected", "onAction")
    m.episodes.observeField("itemSelected", "onEpisode")
    m.top.observeField("focusedChild", "onFocusChange")
    m.top.observeField("resumed", "refreshActions")
end sub

sub onFocusChange()
    if m.top.hasFocus() then m.actions.setFocus(true)
end sub

sub onItem()
    it = m.top.item
    m.titleLbl.text = To_Str(it.title)
    m.poster.uri = To_Str(it.poster)
    m.backdrop.uri = To_Str(it.poster)
    m.metaLbl.text = "Carregando detalhes..."
    refreshActions()
    m.task = CreateObject("roSGNode", "ArchiveMetaTask")
    m.task.identifier = To_Str(it.id)
    m.task.observeField("result", "onMeta")
    m.task.control = "run"
end sub

sub onMeta()
    r = m.task.result
    m.info = r
    if not Is_True(r.ok)
        m.metaLbl.text = "Não foi possível carregar. Verifique a internet."
        return
    end if
    if r.title <> "" then m.titleLbl.text = r.title

    parts = []
    if r.year <> "" then parts.Push(r.year)
    n = r.files.Count()
    if n > 1 then parts.Push(n.ToStr() + " partes")
    lic = License_Label(r.license)
    if lic <> "" then parts.Push(lic)
    m.metaLbl.text = parts.Join("   •   ")
    if n = 0 then m.metaLbl.text = "Este item não tem vídeo em formato compatível com o Roku."

    m.desc.text = r.description
    if m.desc.text = "" then m.desc.text = "Sem descrição."

    if n > 1
        root = CreateObject("roSGNode", "ContentNode")
        i = 1
        for each f in r.files
            row = root.createChild("ContentNode")
            row.title = i.ToStr() + ".  " + f.title
            i++
        end for
        m.episodes.content = root
        m.episodes.visible = true
        m.epTitle.visible = true
        m.desc.maxLines = 6
    end if
    refreshActions()
end sub

sub refreshActions()
    it = m.top.item
    if it = invalid then return
    m.actionIds = []
    root = CreateObject("roSGNode", "ContentNode")
    if m.info <> invalid and m.info.files <> invalid and m.info.files.Count() > 0
        rec = Recent_Find(To_Str(it.id))
        if rec <> invalid and To_Int(rec.at) > 30
            addAction(root, "resume", "Continuar de " + Fmt_Time(To_Int(rec.at)))
        end if
        if m.info.files.Count() > 1
            addAction(root, "play", "Assistir desde a parte 1")
        else
            addAction(root, "play", "Assistir")
        end if
    end if
    if Fav_Has(To_Str(it.id))
        addAction(root, "fav", "Remover da Minha Lista")
    else
        addAction(root, "fav", "Adicionar à Minha Lista")
    end if
    m.actions.content = root
end sub

sub addAction(root as Object, id as String, label as String)
    n = root.createChild("ContentNode")
    n.title = "   " + label
    m.actionIds.Push(id)
end sub

sub onAction()
    a = m.actionIds[m.actions.itemSelected]
    if a = "play"
        playFile(0, 0)
    else if a = "resume"
        rec = Recent_Find(To_Str(m.top.item.id))
        idx = fileIndex(To_Str(rec.file))
        playFile(idx, To_Int(rec.at))
    else if a = "fav"
        it = m.top.item
        Fav_Toggle({ id: To_Str(it.id), title: m.titleLbl.text, poster: To_Str(it.poster) })
        refreshActions()
        m.actions.jumpToItem = m.actionIds.Count() - 1
    end if
end sub

sub onEpisode()
    idx = m.episodes.itemSelected
    start = 0
    rec = Recent_Find(To_Str(m.top.item.id))
    if rec <> invalid and To_Str(rec.file) = m.info.files[idx].key then start = To_Int(rec.at)
    playFile(idx, start)
end sub

function fileIndex(key as String) as Integer
    for i = 0 to m.info.files.Count() - 1
        if m.info.files[i].key = key then return i
    end for
    return 0
end function

sub playFile(idx as Integer, start as Integer)
    f = m.info.files[idx]
    title = m.titleLbl.text
    if m.info.files.Count() > 1 then title = title + "  -  " + f.title
    m.top.navigate = {
        to: "play",
        urls: f.urls,
        title: title,
        live: false,
        id: To_Str(m.top.item.id),
        file: f.key,
        start: start,
        poster: To_Str(m.top.item.poster),
        itemTitle: m.titleLbl.text
    }
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "right" and m.episodes.visible and m.actions.hasFocus()
        m.episodes.setFocus(true)
        return true
    else if key = "left" and m.episodes.hasFocus()
        m.actions.setFocus(true)
        return true
    end if
    return false
end function
