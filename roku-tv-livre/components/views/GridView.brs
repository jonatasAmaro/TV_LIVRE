sub init()
    m.grid = m.top.findNode("grid")
    m.rows = m.top.findNode("rows")
    m.titleLbl = m.top.findNode("title")
    m.subtitle = m.top.findNode("subtitle")
    m.status = m.top.findNode("status")
    m.searchBar = m.top.findNode("searchBar")
    m.searchBg = m.top.findNode("searchBg")
    m.searchRing = m.top.findNode("searchRing")
    m.searchLbl = m.top.findNode("searchLbl")
    m.bgGradient = m.top.findNode("bgGradient")
    m.dividers = m.top.findNode("dividers")
    m.bannerArea = m.top.findNode("bannerArea")
    m.bannerImg = m.top.findNode("bannerImg")
    m.bannerTitle = m.top.findNode("bannerTitle")
    m.bannerDesc = m.top.findNode("bannerDesc")
    m.bottomStrip = m.top.findNode("bottomStrip")
    m.arrowDown = m.top.findNode("arrowDown")
    m.items = []
    m.hasCategories = false
    m.hasSearch = false
    m.searchFocused = false
    m.sectionId = ""
    m.kb = invalid

    m.grid.observeField("itemSelected", "onItemSelected")
    m.grid.observeField("itemFocused", "onGridItemFocused")
    m.rows.observeField("rowItemSelected", "onRowItemSelected")
    m.rows.observeField("rowItemFocused", "onRowItemFocused")
    m.top.observeField("focusedChild", "onFocusChange")
end sub

sub onFocusChange()
    if not m.top.hasFocus() then return
    if m.searchFocused
        return
    else if m.hasCategories
        m.rows.setFocus(true)
    else if m.items.Count() > 0
        m.grid.setFocus(true)
    end if
end sub

sub focusSearch()
    m.searchFocused = true
    m.searchRing.visible = true
    if m.sectionId = "anime_tab"
        m.searchBg.color = "0xDBC8F0FF"
        m.searchLbl.text = chr(9654) + "  Buscar animes..."
    else if m.sectionId = "filmes"
        m.searchBg.color = "0xF5D6A8FF"
        m.searchLbl.text = chr(9654) + "  Buscar filmes..."
    else if m.sectionId = "desenhos_tab"
        m.searchBg.color = "0xFFE0B2FF"
        m.searchLbl.text = chr(9654) + "  Buscar desenhos..."
    else
        m.searchBg.color = "0xD4E6BAFF"
        m.searchLbl.text = chr(9654) + "  Buscar séries..."
    end if
    m.rows.setFocus(false)
    m.top.setFocus(true)
end sub

sub unfocusSearch()
    m.searchFocused = false
    m.searchRing.visible = false
    m.searchBg.color = "0xFFFFFFFF"
    if m.sectionId = "anime_tab"
        m.searchLbl.text = "Buscar animes..."
    else if m.sectionId = "filmes"
        m.searchLbl.text = "Buscar filmes..."
    else if m.sectionId = "desenhos_tab"
        m.searchLbl.text = "Buscar desenhos..."
    else
        m.searchLbl.text = "Buscar séries..."
    end if
    m.rows.setFocus(true)
end sub

sub onSection()
    s = m.top.section
    m.sectionId = To_Str(s.id)
    m.titleLbl.text = To_Str(s.title)
    m.subtitle.text = To_Str(s.subtitle)

    if m.sectionId = "series_tab"
        m.bgGradient.uri = "pkg:/images/bg_series_gradient.png"
        m.bgGradient.visible = true
    else if m.sectionId = "anime_tab"
        m.bgGradient.uri = "pkg:/images/bg_anime_gradient.png"
        m.bgGradient.visible = true
    else if m.sectionId = "filmes"
        m.bgGradient.uri = "pkg:/images/bg_movies_gradient.png"
        m.bgGradient.visible = true
    else if m.sectionId = "youtube"
        m.bgGradient.uri = "pkg:/images/bg_youtube_gradient.png"
        m.bgGradient.visible = true
    end if

    if m.top.embedded
        m.titleLbl.visible = false
        m.subtitle.visible = false
        m.bgGradient.visible = false
    else if m.sectionId = "series_tab" or m.sectionId = "anime_tab" or m.sectionId = "filmes" or m.sectionId = "youtube" or m.sectionId = "desenhos_tab"
        m.titleLbl.translation = [80, 36]
        m.subtitle.translation = [82, 106]
    end if

    m.hasSearch = (s.search <> invalid and s.search = true)
    m.hasCategories = (s.categories <> invalid and s.categories.Count() > 0)

    contentY = 250
    gap = 24
    if m.top.embedded
        m.searchBar.visible = false
        m.bannerArea.visible = false
        m.bottomStrip.visible = true
        m.bottomStrip.translation = [0, -10]
        m.arrowDown.translation = [930, 360]
        contentY = 20
    else if m.hasSearch
        m.searchBar.visible = true
        m.searchBar.translation = [80, 160]
        contentY = 260
        if m.sectionId = "series_tab"
            m.searchLbl.color = "0x556B2FCC"
            m.searchLbl.text = "Buscar séries..."
        else if m.sectionId = "anime_tab"
            m.searchLbl.color = "0x7B2D8ECC"
            m.searchRing.color = "0x7B2D8EFF"
            m.searchLbl.text = "Buscar animes..."
        else if m.sectionId = "filmes"
            m.searchLbl.color = "0xB85C1ECC"
            m.searchRing.color = "0xE67E22FF"
            m.searchLbl.text = "Buscar filmes..."
        else if m.sectionId = "desenhos_tab"
            m.searchLbl.color = "0xE65100CC"
            m.searchRing.color = "0xFF8F00FF"
            m.searchLbl.text = "Buscar desenhos..."
        end if
    end if

    if m.hasCategories
        m.grid.visible = false
        m.rows.visible = true
        m.rows.translation = [80, contentY]
        if m.top.embedded
            m.rows.numRows = 1
            m.rows.itemSize = [1760, 380]
            m.rows.rowItemSize = [[180, 310]]
            m.rows.rowItemSpacing = [[20, 0]]
            m.rows.itemSpacing = [0, 30]
        end if
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

    favRow = buildFavoritesRow()
    if favRow <> invalid and favRow.getChildCount() > 0
        root.appendChild(favRow)
    end if

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
    if m.allItems.Count() > 0 and m.top.embedded
        item = m.allItems[0]
        hero = {
            title: To_Str(item.title),
            description: To_Str(item.summary),
            meta: "",
            background: To_Str(item.banner)
        }
        if hero.background = "" then hero.background = To_Str(item.poster)
        m.top.navigate = { to: "hero", hero: hero }
    end if
    if m.top.embedded
        m.arrowDown.visible = (root.getChildCount() > 1)
    end if
    if m.top.hasFocus() then m.rows.setFocus(true)
    buildDividers(root.getChildCount())
end sub

function buildFavoritesRow() as Dynamic
    favs = Fav_List()
    if favs.Count() = 0 then return invalid
    row = CreateObject("roSGNode", "ContentNode")
    row.title = "FAVORITOS"
    for each f in favs
        if To_Str(f.kind) = "grid"
            item = Grid_FindItem(To_Str(f.id))
            if item <> invalid
                n = row.createChild("ContentNode")
                n.title = To_Str(item.title)
                n.hdPosterUrl = To_Str(item.poster)
                n.addFields({ fit: true })
                m.allItems.Push(item)
            end if
        end if
    end for
    return row
end function

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

sub updateBanner(item as Object)
    bannerUrl = To_Str(item.banner)
    if bannerUrl = "" then bannerUrl = To_Str(item.poster)
    m.bannerImg.uri = bannerUrl
    m.bannerTitle.text = To_Str(item.title)
    summary = To_Str(item.summary)
    if summary = "" then summary = To_Str(item.description)
    m.bannerDesc.text = summary
end sub

sub onGridItemFocused()
    if not m.top.embedded then return
    idx = m.grid.itemFocused
    if idx < 0 or idx >= m.items.Count() then return
    item = m.items[idx]
    updateBanner(item)
end sub

sub onRowItemFocused()
    if not m.top.embedded then return
    sel = m.rows.rowItemFocused
    if sel = invalid or sel.Count() < 2 then return

    totalRows = m.rows.content.getChildCount()
    if sel[0] >= totalRows - 1
        m.arrowDown.uri = "pkg:/images/icon_arrow_up.png"
    else
        m.arrowDown.uri = "pkg:/images/icon_arrow_down.png"
    end if

    idx = 0
    for r = 0 to sel[0] - 1
        row = m.rows.content.getChild(r)
        idx = idx + row.getChildCount()
    end for
    idx = idx + sel[1]
    if idx >= 0 and idx < m.allItems.Count()
        item = m.allItems[idx]
        hero = {
            title: To_Str(item.title),
            description: To_Str(item.summary),
            meta: "",
            background: To_Str(item.banner)
        }
        if hero.background = "" then hero.background = To_Str(item.poster)
        m.top.navigate = { to: "hero", hero: hero }
    end if
end sub

sub onItemSelected()
    idx = m.grid.itemSelected
    if idx < 0 or idx >= m.items.Count() then return
    item = m.items[idx]
    target = "gridDetail"
    if m.sectionId = "filmes" then target = "movieDetail"
    m.top.navigate = { to: target, item: item }
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
        target = "gridDetail"
        if m.sectionId = "filmes" then target = "movieDetail"
        m.top.navigate = { to: target, item: item }
    end if
end sub

sub openKeyboard()
    kb = CreateObject("roSGNode", "StandardKeyboardDialog")
    if m.sectionId = "anime_tab"
        kb.title = "Buscar animes"
    else if m.sectionId = "filmes"
        kb.title = "Buscar filmes"
    else
        kb.title = "Buscar séries e animes"
    end if
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

sub buildDividers(rowCount as Integer)
    m.dividers.removeChildrenIndex(m.dividers.getChildCount(), 0)
    if m.top.embedded or rowCount < 2 then return
    rowsY = m.rows.translation[1]
    rowH = 370
    spacing = 60
    for i = 0 to rowCount - 2
        y = rowsY + (i + 1) * (rowH + spacing) - Cint(spacing / 2)
        line = m.dividers.createChild("Rectangle")
        line.translation = [100, y]
        line.width = 1720
        line.height = 1
        line.color = "0xFFFFFF44"
    end for
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.searchFocused
        if key = "OK"
            openKeyboard()
            return true
        else if key = "down"
            unfocusSearch()
            return true
        else if key = "up"
            unfocusSearch()
            m.top.navigate = { to: "tabs" }
            return true
        else if key = "back"
            unfocusSearch()
            m.top.navigate = { to: "tabs" }
            return true
        end if
        return true
    end if

    if m.top.embedded
        if key = "up"
            ri = m.rows.rowItemFocused
            if ri <> invalid and ri[0] = 0
                m.top.navigate = { to: "tabs" }
                return true
            end if
        end if
        if key = "back"
            m.top.navigate = { to: "tabs" }
            return true
        end if
    end if

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
