' Shared subtitle helpers for PlayerView and GridDetailView.
' Requires: m.video (Video node), m.controls (PlayerControls), m.subTask, m.subTracks

sub fetchSubtitles(imdb as String, season as Integer, episode as Integer)
    if m.subTask <> invalid
        m.subTask.unobserveField("result")
    end if
    m.subTracks = []
    m.controls.subtitleTracks = []
    m.controls.subtitleIndex = -1
    t = CreateObject("roSGNode", "SubtitleTask")
    t.imdbId = imdb
    t.season = season
    t.episode = episode
    t.observeField("result", "onSubtitlesLoaded")
    t.control = "run"
    m.subTask = t
end sub

sub onSubtitlesLoaded()
    tracks = m.subTask.result
    if tracks = invalid then tracks = []
    m.subTracks = tracks
    m.controls.subtitleTracks = tracks

    ' Auto-select first PT-BR track if available
    for i = 0 to tracks.Count() - 1
        if tracks[i].lang = "pob"
            m.controls.subtitleIndex = i
            applySubtitle(i)
            return
        end if
    end for
end sub

sub onSubtitleChanged()
    applySubtitle(m.controls.subtitleIndex)
end sub

sub applySubtitle(idx as Integer)
    v = m.video
    if v = invalid or v.content = invalid then return

    if idx < 0 or m.subTracks.Count() = 0
        ' Turn off subtitles
        v.globalCaptionMode = "Off"
        return
    end if

    track = m.subTracks[idx]
    if track = invalid then return

    ' Configure the subtitle track on the content node
    subConfig = [{
        TrackName: track.label,
        Language: track.lang,
        Url: track.url
    }]
    v.content.SubtitleConfig = subConfig
    v.subtitleTrack = track.label
    v.globalCaptionMode = "On"
end sub
