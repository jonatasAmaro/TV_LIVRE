sub init()
    m.grid = m.top.findNode("grid")
    m.rows = m.top.findNode("rows")
    m.titleLbl = m.top.findNode("title")
    m.subtitle = m.top.findNode("subtitle")
    m.status = m.top.findNode("status")
    m.searchBar = m.top.findNode("searchBar")
    m.searchLbl = m.top.findNode("searchLbl")
    m.items = []
    m.hasCategories = false
    m.hasSearch = false
    m.kb = invalid

    m.grid.observeField("itemSelected", "onItemSelected")
    m.rows.observeField("rowItemSelected", "onRowItemSelected")
    m.top.observeField("focusedChild", "onFocusChange")
end sub

sub onFocusChange()
    if not m.top.hasFocus() then return
    if m.hasCategories
        m.rows.setFocus(true)
    else if m.items.Count() > 0
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
    end if

    m.hasSearch = (s.search <> invalid and s.search = true)
    m.hasCategories = (s.categories <> invalid and s.categories.Count() > 0)

    contentY = 250
    if m.hasSearch
        m.searchBar.visible = true
        m.searchBar.translation = [80, 200]
        contentY = 290
    end if

    if m.hasCategories
        m.grid.visible = false
        m.rows.visible = true
        m.rows.translation = [80, contentY]
        loadCategories(s.categories)
    else
        m.rows.visible = false
        m.grid.visible = true
        m.grid.translation = [80, contentY]
        m.items = s.items
        if m.items = invalid then m.items = []
        loadGrid()
    end if
end sub

sub loadCategories(categories as Object)
    root = CreateObject("roSGNode", "ContentNode")
    m.allItems = []
    for each cat in categories
        row = CreateObject("roSGNode", "ContentNode")
        row.title = To_Str(cat.title)
        catItems = cat.items
        if catItems = invalid then catItems = []
        for each item in catItems
            n = row.createChild("ContentNode")
            n.title = To_Str(item.title)
            n.hdPosterUrl = To_Str(item.poster)
            n.addFields({ fit: true })
            m.allItems.Push(item)
        end for
        if row.getChildCount() > 0 then root.appendChild(row)
    end for
    m.rows.content = root
    if root.getChildCount() = 0
        m.status.text = "Nenhum item configurado."
        m.status.visible = true
    end if
    if m.top.hasFocus() then m.rows.setFocus(true)
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

sub onRowItemSelected()
    sel = m.rows.rowItemSelected
    rowIdx = sel[0]
    colIdx = sel[1]
    idx = 0
    for r = 0 to rowIdx - 1
        row = m.rows.content.getChild(r)
        idx = idx + row.getChildCount()
    end for
    idx = idx + colIdx
    if idx >= 0 and idx < m.allItems.Count()
        item = m.allItems[idx]
        m.top.navigate = { to: "gridDetail", item: item }
    end if
end sub

sub openKeyboard()
    kb = CreateObject("roSGNode", "StandardKeyboardDialog")
    kb.title = "Buscar séries e animes"
    kb.buttons = ["Buscar", "Cancelar"]
    kb.observeField("buttonSelected", "onKbButton")
    kb.observeField("wasClosed", "onKbClosed")
    m.kb = kb
    m.top.getScene().dialog = kb
end sub

sub onKbButton()
    idx = m.kb.buttonSelected
    query = m.kb.text.Trim()
    m.kb.close = true
    if idx = 0 and query <> ""
        filterItems(query)
    end if
end sub

sub onKbClosed()
    m.kb = invalid
    if m.hasCategories
        m.rows.setFocus(true)
    else
        m.grid.setFocus(true)
    end if
end sub

sub filterItems(query as String)
    q = LCase(query)
    s = m.top.section
    if m.hasCategories and s.categories <> invalid
        filtered = []
        for each cat in s.categories
            if cat.items <> invalid
                for each item in cat.items
                    if Instr(1, LCase(To_Str(item.title)), q) > 0
                        filtered.Push(item)
                    end if
                end for
            end if
        end for
        root = CreateObject("roSGNode", "ContentNode")
        row = CreateObject("roSGNode", "ContentNode")
        row.title = "Resultados: " + query
        m.allItems = []
        for each item in filtered
            n = row.createChild("ContentNode")
            n.title = To_Str(item.title)
            n.hdPosterUrl = To_Str(item.poster)
            n.addFields({ fit: true })
            m.allItems.Push(item)
        end for
        root.appendChild(row)
        m.rows.content = root
        if filtered.Count() = 0
            m.status.text = "Nenhum resultado para '" + query + "'."
            m.status.visible = true
        else
            m.status.visible = false
        end if
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "options" and m.hasSearch
        openKeyboard()
        return true
    end if
    if key = "play" and m.hasSearch
        openKeyboard()
        return true
    end if
    return false
end function
