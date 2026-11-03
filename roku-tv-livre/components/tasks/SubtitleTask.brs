' Fetches subtitle list from OpenSubtitles v3 (Stremio addon).
' Input: imdbId, season (0 for movies), episode (0 for movies)
' Output: result = array of { lang, label, url }
sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    imdb = m.top.imdbId
    if imdb = "" or imdb = invalid
        m.top.result = []
        return
    end if

    season = m.top.season
    episode = m.top.episode

    if season > 0 and episode > 0
        url = "https://opensubtitles-v3.strem.io/subtitles/series/" + imdb + ":" + season.ToStr() + ":" + episode.ToStr() + ".json"
    else
        url = "https://opensubtitles-v3.strem.io/subtitles/movie/" + imdb + ".json"
    end if

    data = Http_GetJson(url)
    subs = []
    if data = invalid or data.subtitles = invalid
        m.top.result = subs
        return
    end if

    ' Prioritize: pob (PT-BR) first, then por (PT-PT), then eng, then others.
    ' Keep max 2 per language to avoid huge lists.
    langCount = {}
    langOrder = ["pob", "por", "eng", "spa"]

    ' First pass: collect prioritized languages
    for each s in data.subtitles
        lang = To_Str(s.lang)
        if lang = "" then lang = "und"
        found = false
        for each lo in langOrder
            if lang = lo then found = true
        end for
        if not found then continue for
        c = 0
        if langCount[lang] <> invalid then c = langCount[lang]
        if c >= 2 then continue for
        langCount[lang] = c + 1
        entry = { lang: lang, url: To_Str(s.url), label: subLabel(lang, c + 1) }
        subs.Push(entry)
    end for

    m.top.result = subs
end sub

function subLabel(lang as String, idx as Integer) as String
    names = {
        pob: "Português (BR)",
        por: "Português (PT)",
        eng: "English",
        spa: "Español"
    }
    label = names[lang]
    if label = invalid then label = UCase(lang)
    if idx > 1 then label = label + " " + idx.ToStr()
    return label
end function
