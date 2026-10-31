' Weekly airing schedule from the public AniList GraphQL API (metadata only).
sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    now = Now_Seconds()
    vars = { s: now - m.top.daysBack * 86400, e: now + m.top.daysAhead * 86400, p: 1 }
    query = "query($s:Int,$e:Int,$p:Int){Page(page:$p,perPage:50){pageInfo{hasNextPage} airingSchedules(airingAt_greater:$s,airingAt_lesser:$e,sort:TIME){episode airingAt media{id title{romaji english} coverImage{large} isAdult genres description(asHtml:false) externalLinks{site type}}}}}"
    out = []
    while vars.p <= 6
        data = Http_PostJson("https://graphql.anilist.co", { query: query, variables: vars })
        if data = invalid or data.data = invalid or data.data.Page = invalid then exit while
        pg = data.data.Page
        if pg.airingSchedules <> invalid
            for each a in pg.airingSchedules
                e = toEntry(a)
                if e <> invalid then out.Push(e)
            end for
        end if
        if pg.pageInfo = invalid or not Is_True(pg.pageInfo.hasNextPage) then exit while
        vars.p = vars.p + 1
    end while
    m.top.entries = out
end sub

function toEntry(a as Object) as Dynamic
    md = a.media
    if md = invalid or Is_True(md.isAdult) then return invalid
    title = ""
    if md.title <> invalid
        title = To_Str(md.title.english)
        if title = "" then title = To_Str(md.title.romaji)
    end if
    links = []
    if md.externalLinks <> invalid
        for each l in md.externalLinks
            if To_Str(l["type"]) = "STREAMING" then links.Push(To_Str(l.site))
        end for
    end if
    genres = ""
    if md.genres <> invalid then genres = md.genres.Join(", ")
    cover = ""
    if md.coverImage <> invalid then cover = To_Str(md.coverImage.large)
    return {
        id: To_Str(md.id) + "-" + To_Str(a.episode),
        title: title,
        episode: To_Int(a.episode),
        airingAt: To_Int(a.airingAt),
        cover: cover,
        genres: genres,
        description: Strip_Html(md.description),
        links: links
    }
end function
