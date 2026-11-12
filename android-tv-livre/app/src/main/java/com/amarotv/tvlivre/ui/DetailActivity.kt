package com.amarotv.tvlivre.ui

import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.amarotv.tvlivre.R
import com.amarotv.tvlivre.data.ContentItem
import com.amarotv.tvlivre.data.Episode
import com.bumptech.glide.Glide
import androidx.media3.common.MimeTypes
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLDecoder
import kotlin.concurrent.thread

class DetailActivity : AppCompatActivity() {

    companion object {
        var currentItem: ContentItem? = null
    }

    private lateinit var seasonSpinner: Spinner
    private lateinit var episodeNumbers: LinearLayout
    private lateinit var episodeNameLabel: TextView
    private lateinit var episodeCountLabel: TextView
    private lateinit var previewLoading: TextView
    private var previewPlayer: ExoPlayer? = null
    private var selectedSeason = 0
    private var selectedEpisode = 0
    private var currentEpisodes: List<Episode> = emptyList()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_detail)

        val item = currentItem ?: return finish()

        seasonSpinner = findViewById(R.id.seasonSpinner)
        episodeNumbers = findViewById(R.id.episodeNumbers)
        episodeNameLabel = findViewById(R.id.episodeNameLabel)
        episodeCountLabel = findViewById(R.id.episodeCountLabel)
        previewLoading = findViewById(R.id.previewLoading)

        // Title + meta
        findViewById<TextView>(R.id.detailTitle).text = item.title
        val meta = listOfNotNull(
            item.genre.ifEmpty { null },
            item.year.ifEmpty { null },
            item.rating.ifEmpty { null },
            item.duration.ifEmpty { null }
        ).joinToString(" | ")
        findViewById<TextView>(R.id.detailMeta).text = meta.ifEmpty { "${item.seasons?.size ?: 0} temporadas" }

        // Poster
        if (item.poster.isNotEmpty()) {
            Glide.with(this).load(item.poster).into(findViewById(R.id.detailPoster))
        }

        // Preview player
        val playerView = findViewById<PlayerView>(R.id.detailPreviewPlayer)
        previewPlayer = ExoPlayer.Builder(this).build()
        playerView.player = previewPlayer
        playerView.useController = false

        previewPlayer?.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                if (state == Player.STATE_READY) previewLoading.visibility = View.GONE
            }
        })

        setupSeasonSelector(item)
        selectSeason(0, item)
    }

    private fun setupSeasonSelector(item: ContentItem) {
        val seasons = item.seasons ?: return
        val names = seasons.mapIndexed { i, _ -> "Temporada ${i + 1}" }
        val adapter = ArrayAdapter(this, R.layout.spinner_item, names)
        adapter.setDropDownViewResource(R.layout.spinner_dropdown_item)
        seasonSpinner.adapter = adapter
        seasonSpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: android.view.View?, pos: Int, id: Long) {
                selectSeason(pos, item)
            }
            override fun onNothingSelected(parent: AdapterView<*>?) {}
        }
    }

    private fun selectSeason(index: Int, item: ContentItem) {
        val seasons = item.seasons ?: return
        if (index >= seasons.size) return
        selectedSeason = index

        currentEpisodes = seasons[index].episodes
        episodeCountLabel.text = "${currentEpisodes.size} episódio(s)"

        buildEpisodeNumbers(item)

        if (currentEpisodes.isNotEmpty()) {
            selectEpisodePreview(0)
        }
    }

    private fun buildEpisodeNumbers(item: ContentItem) {
        episodeNumbers.removeAllViews()
        for ((i, ep) in currentEpisodes.withIndex()) {
            val tv = TextView(this).apply {
                text = "${i + 1}"
                setTextColor(Color.parseColor("#222222"))
                textSize = 15f
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
                minimumWidth = 48
                minimumHeight = 48
                setPadding(8, 8, 8, 8)
                setBackgroundColor(Color.parseColor("#4488AACC"))
                isFocusable = true
                isFocusableInTouchMode = true
                val lp = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
                lp.marginEnd = 6
                layoutParams = lp
                tag = i

                setOnFocusChangeListener { v, hasFocus ->
                    if (hasFocus) {
                        v.setBackgroundColor(Color.parseColor("#FFD700"))
                        (v as TextView).setTextColor(Color.parseColor("#222222"))
                        episodeNameLabel.text = ep.title.ifEmpty { "Episódio ${i + 1}" }
                        episodeNameLabel.visibility = View.VISIBLE
                    } else {
                        v.setBackgroundColor(Color.parseColor("#4488AACC"))
                        (v as TextView).setTextColor(Color.parseColor("#222222"))
                    }
                }

                setOnClickListener {
                    selectedEpisode = i
                    playFullscreen(item)
                }
            }
            episodeNumbers.addView(tv)
        }
    }

    private fun resolveWorkerUrl(endpoint: String, callback: (String?, String?) -> Unit) {
        thread {
            try {
                val conn = URL(endpoint).openConnection() as HttpURLConnection
                conn.connectTimeout = 15000
                conn.readTimeout = 15000
                val body = conn.inputStream.bufferedReader().readText()
                val json = JSONObject(body)
                if (json.optBoolean("ok")) {
                    val url = json.optString("url", "")
                    val format = json.optString("format", "")
                    runOnUiThread { callback(url.ifEmpty { null }, format) }
                } else {
                    runOnUiThread { callback(null, null) }
                }
            } catch (_: Exception) {
                runOnUiThread { callback(null, null) }
            }
        }
    }

    private fun resolveEpisodeUrl(ep: Episode, seasonIdx: Int, epIdx: Int, callback: (String) -> Unit) {
        val item = currentItem ?: return

        if (ep.source == "saimo" && item.saimoId.isNotEmpty()) {
            val endpoint = "https://tv-livre-catalog.jonatas-amaro2.workers.dev/saimo?id=${item.saimoId}&season=${seasonIdx + 1}&episode=${epIdx + 1}"
            resolveWorkerUrl(endpoint) { url, format ->
                if (url != null) {
                    ep.url = url
                    ep.format = format ?: ""
                    callback(url)
                } else {
                    Toast.makeText(this, "Erro ao carregar stream", Toast.LENGTH_SHORT).show()
                }
            }
            return
        }

        if (ep.source == "kairou" && item.tmdbId.isNotEmpty()) {
            val encoded = java.net.URLEncoder.encode(item.title, "UTF-8")
            val endpoint = "https://tv-livre-catalog.jonatas-amaro2.workers.dev/kairou?tmdbId=${item.tmdbId}&season=${seasonIdx + 1}&episode=${epIdx + 1}&title=$encoded"
            resolveWorkerUrl(endpoint) { url, format ->
                if (url != null) {
                    ep.url = url
                    ep.format = format ?: ""
                    callback(url)
                } else {
                    Toast.makeText(this, "Erro ao carregar stream", Toast.LENGTH_SHORT).show()
                }
            }
            return
        }

        val finalUrl = unwrapRokuProxy(ep.url)
        callback(finalUrl)
    }

    private fun unwrapRokuProxy(url: String): String {
        if (!url.contains("roku-proxy")) return url
        val match = Regex("[?&]url=([^&]+)").find(url) ?: return url
        return try { URLDecoder.decode(match.groupValues[1], "UTF-8") } catch (_: Exception) { url }
    }

    private fun selectEpisodePreview(index: Int) {
        if (index >= currentEpisodes.size) return
        selectedEpisode = index
        val ep = currentEpisodes[index]
        previewLoading.text = "Carregando EP ${index + 1}..."
        previewLoading.visibility = View.VISIBLE

        resolveEpisodeUrl(ep, selectedSeason, index) { url ->
            previewPlayer?.apply {
                setMediaItem(buildMediaItem(url, ep.format))
                prepare()
                playWhenReady = true
            }
        }
    }

    private fun buildMediaItem(url: String, format: String): MediaItem {
        if (format == "hls" || url.contains(".m3u8") || url.contains("master.txt")) {
            return MediaItem.Builder().setUri(url).setMimeType(MimeTypes.APPLICATION_M3U8).build()
        }
        return MediaItem.fromUri(url)
    }

    private fun playFullscreen(item: ContentItem) {
        previewPlayer?.pause()
        val ep = currentEpisodes[selectedEpisode]

        resolveEpisodeUrl(ep, selectedSeason, selectedEpisode) { url ->
            PlayerActivity.episodeList = currentEpisodes
            PlayerActivity.episodeIndex = selectedEpisode
            PlayerActivity.saimoId = item.saimoId
            PlayerActivity.tmdbId = item.tmdbId
            PlayerActivity.seriesTitle = item.title
            PlayerActivity.seasonIndex = selectedSeason
            val intent = Intent(this, PlayerActivity::class.java)
            intent.putExtra("url", url)
            intent.putExtra("format", ep.format)
            intent.putExtra("title", "${item.title} - ${ep.title.ifEmpty { "Ep ${selectedEpisode + 1}" }}")
            intent.putExtra("live", false)
            startActivity(intent)
        }
    }

    override fun onResume() {
        super.onResume()
        if (currentEpisodes.isNotEmpty()) {
            selectEpisodePreview(selectedEpisode)
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            finish()
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onPause() {
        super.onPause()
        previewPlayer?.pause()
    }

    override fun onDestroy() {
        super.onDestroy()
        previewPlayer?.release()
        previewPlayer = null
    }
}
