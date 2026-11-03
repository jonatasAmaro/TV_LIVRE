' Fetches metadata from Cinemeta (Stremio) for series or movies.
' Input: imdbId, kind ("series" or "movie")
' Output: result = {
'   description, rating, runtime, genres, cast, director,
'   background, logo, trailerYt,
'   episodes: { "S:E": { name, overview, thumbnail } }
' }
sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    imdb = m.top.imdbId
    kind = m.top.kind
    if imdb = "" or imdb = invalid
        m.top.result = {}
        return
    end if
    if kind = "" then kind = "series"

    url = "https://v3-cinemeta.strem.io/meta/" + kind + "/" + imdb + ".json"
    data = Http_GetJson(url)
    out = {}

    if data = invalid or data.meta = invalid
        m.top.result = out
        return
    end if

    meta = data.meta
    out.description = To_Str(meta.description)
    out.rating = To_Str(meta.imdbRating)
    out.runtime = To_Str(meta.runtime)
    out.background = To_Str(meta.background)
    out.logo = To_Str(meta.logo)
    out.year = To_Str(meta.releaseInfo)

    genres = meta.genres
    if genres <> invalid and type(genres) = "roArray"
        out.genres = genres.Join(", ")
    else
        out.genres = ""
    end if

    cast = meta.cast
    if cast <> invalid and type(cast) = "roArray"
        out.cast = cast.Join(", ")
    else
        out.cast = ""
    end if

    dirs = meta.director
    if dirs <> invalid and type(dirs) = "roArray" and dirs.Count() > 0
        out.director = dirs.Join(", ")
    else
        out.director = To_Str(meta.director)
    end if

    trailers = meta.trailers
    out.trailerYt = ""
    if trailers <> invalid and type(trailers) = "roArray" and trailers.Count() > 0
        out.trailerYt = To_Str(trailers[0].source)
    end if

    eps = {}
    videos = meta.videos
    if videos <> invalid and type(videos) = "roArray"
        for each v in videos
            s = To_Int(v.season)
            e = To_Int(v.episode)
            if e = 0 then e = To_Int(v.number)
            if s <= 0 or e <= 0 then continue for
            key = s.ToStr() + ":" + e.ToStr()
            entry = {}
            entry.name = To_Str(v.name)
            entry.overview = To_Str(v.overview)
            entry.thumbnail = To_Str(v.thumbnail)
            eps[key] = entry
        end for
    end if
    out.episodes = eps

    m.top.result = out
end sub
