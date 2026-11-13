package com.amarotv.tvlivre.data

import com.google.gson.annotations.SerializedName

data class Catalog(
    val sections: List<Section> = emptyList(),
    val epgUrl: String = "",
    val catalogUrl: String = ""
)

data class Section(
    val tab: String = "",
    val title: String = "",
    val type: String = "",
    val theme: String = "",
    val rows: List<Row>? = null,
    val categories: List<Row>? = null,
    val channels: List<Channel>? = null,
    val search: Boolean = false
)

data class Row(
    val title: String = "",
    val items: List<ContentItem>? = null,
    val channels: List<Channel>? = null
)

data class Channel(
    @SerializedName("title") val name: String = "",
    val url: String = "",
    val logo: String = "",
    @SerializedName("info") val category: String = "",
    val group: String = "",
    @SerializedName("epg_id") val epgId: String = ""
)

data class ContentItem(
    val title: String = "",
    val poster: String = "",
    val background: String = "",
    val description: String = "",
    val genre: String = "",
    val year: String = "",
    val rating: String = "",
    val duration: String = "",
    val type: String = "",
    val seasons: List<Season>? = null,
    val url: String = "",
    val sources: List<Source>? = null,
    val saimoId: String = "",
    val saimoFonte: String = "",
    val tokyUrl: String = "",
    val tmdbId: String = ""
)

data class Season(
    val number: Int = 1,
    val episodes: List<Episode> = emptyList()
)

data class Episode(
    val number: Int = 1,
    val title: String = "",
    var url: String = "",
    val sources: List<Source>? = null,
    val source: String = "",
    var format: String = ""
)

data class Source(
    val url: String = "",
    val quality: String = "",
    val label: String = ""
)
