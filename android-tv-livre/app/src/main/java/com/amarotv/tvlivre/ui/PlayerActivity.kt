package com.amarotv.tvlivre.ui

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.amarotv.tvlivre.R
import com.amarotv.tvlivre.data.Channel
import com.amarotv.tvlivre.data.Episode
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLDecoder
import kotlin.concurrent.thread

class PlayerActivity : AppCompatActivity() {

    private lateinit var player: ExoPlayer
    private lateinit var playerView: PlayerView
    private lateinit var channelInfoBar: LinearLayout
    private lateinit var channelInfoTitle: TextView
    private lateinit var channelInfoDesc: TextView
    private var isLive = false
    private val handler = Handler(Looper.getMainLooper())
    private val hideInfoRunnable = Runnable { channelInfoBar.visibility = View.GONE }

    companion object {
        var liveChannels: List<Channel> = emptyList()
        var currentIndex: Int = 0

        var episodeList: List<Episode> = emptyList()
        var episodeIndex: Int = 0
        var saimoId: String = ""
        var tmdbId: String = ""
        var seriesTitle: String = ""
        var seasonIndex: Int = 0
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_player)

        playerView = findViewById(R.id.playerView)
        channelInfoBar = findViewById(R.id.channelInfoBar)
        channelInfoTitle = findViewById(R.id.channelInfoTitle)
        channelInfoDesc = findViewById(R.id.channelInfoDesc)

        player = ExoPlayer.Builder(this).build()
        playerView.player = player

        isLive = intent.getBooleanExtra("live", false)
        playerView.useController = !isLive

        val url = intent.getStringExtra("url") ?: return finish()
        val format = intent.getStringExtra("format") ?: ""
        playUrl(url, format)

        if (isLive && liveChannels.isNotEmpty()) {
            showChannelInfo()
        }

        if (!isLive && episodeList.isNotEmpty()) {
            showEpisodeInfo()
            player.addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(state: Int) {
                    if (state == Player.STATE_ENDED) switchEpisode(1)
                }
            })
        }
    }

    private fun playUrl(url: String, format: String = "") {
        val item = if (format == "hls" || url.contains(".m3u8") || url.contains("master.txt")) {
            MediaItem.Builder().setUri(url).setMimeType(MimeTypes.APPLICATION_M3U8).build()
        } else {
            MediaItem.fromUri(unwrapProxy(url))
        }
        player.setMediaItem(item)
        player.prepare()
        player.playWhenReady = true
    }

    private fun unwrapProxy(url: String): String {
        if (!url.contains("roku-proxy") && !url.contains("kairou.space/api/proxy")) return url
        val match = Regex("[?&]url=([^&]+)").find(url) ?: return url
        return try { URLDecoder.decode(match.groupValues[1], "UTF-8") } catch (_: Exception) { url }
    }

    // ── Live channel info ──

    private fun showChannelInfo() {
        if (!isLive || liveChannels.isEmpty()) return
        val ch = liveChannels[currentIndex]
        val num = currentIndex + 1
        channelInfoTitle.text = "$num - ${ch.name}"
        channelInfoDesc.text = ch.category.ifEmpty { "Canal Ao Vivo" }

        channelInfoBar.visibility = View.VISIBLE
        handler.removeCallbacks(hideInfoRunnable)
        handler.postDelayed(hideInfoRunnable, 4000)
    }

    private fun switchChannel(delta: Int) {
        if (!isLive || liveChannels.isEmpty()) return

        currentIndex = (currentIndex + delta).let { i ->
            when {
                i < 0 -> liveChannels.size - 1
                i >= liveChannels.size -> 0
                else -> i
            }
        }

        val ch = liveChannels[currentIndex]
        playUrl(ch.url)
        showChannelInfo()
    }

    // ── VOD episode info ──

    private fun showEpisodeInfo() {
        if (episodeList.isEmpty()) return
        val ep = episodeList[episodeIndex]
        val num = episodeIndex + 1
        val total = episodeList.size
        channelInfoTitle.text = "Ep $num/$total - ${ep.title.ifEmpty { "Episódio $num" }}"
        channelInfoDesc.text = if (num < total) "Próximo: ${episodeList[num].title.ifEmpty { "Episódio ${num + 1}" }}" else "Último episódio"

        channelInfoBar.visibility = View.VISIBLE
        handler.removeCallbacks(hideInfoRunnable)
        handler.postDelayed(hideInfoRunnable, 5000)
    }

    private fun switchEpisode(delta: Int) {
        if (episodeList.isEmpty()) return
        val newIdx = episodeIndex + delta
        if (newIdx < 0 || newIdx >= episodeList.size) {
            Toast.makeText(this, if (delta > 0) "Último episódio" else "Primeiro episódio", Toast.LENGTH_SHORT).show()
            return
        }
        episodeIndex = newIdx
        val ep = episodeList[episodeIndex]

        if (ep.source == "saimo" && saimoId.isNotEmpty() && ep.url.isEmpty()) {
            val endpoint = "https://tv-livre-catalog.jonatas-amaro2.workers.dev/saimo?id=$saimoId&season=${seasonIndex + 1}&episode=${episodeIndex + 1}"
            resolveAndPlay(endpoint, episodeIndex)
        } else if (ep.source == "kairou" && tmdbId.isNotEmpty() && ep.url.isEmpty()) {
            val encoded = java.net.URLEncoder.encode(seriesTitle, "UTF-8")
            val endpoint = "https://tv-livre-catalog.jonatas-amaro2.workers.dev/kairou?tmdbId=$tmdbId&season=${seasonIndex + 1}&episode=${episodeIndex + 1}&title=$encoded"
            resolveAndPlay(endpoint, episodeIndex)
        } else {
            playUrl(ep.url, ep.format)
        }
        showEpisodeInfo()
    }

    private fun resolveAndPlay(endpoint: String, epIdx: Int) {
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
                    if (url.isNotEmpty()) {
                        episodeList[epIdx].url = url
                        episodeList[epIdx].format = format
                        runOnUiThread { playUrl(url, format) }
                        return@thread
                    }
                }
                runOnUiThread { Toast.makeText(this, "Erro ao carregar stream", Toast.LENGTH_SHORT).show() }
            } catch (_: Exception) {
                runOnUiThread { Toast.makeText(this, "Erro ao carregar stream", Toast.LENGTH_SHORT).show() }
            }
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (isLive) {
            when (keyCode) {
                KeyEvent.KEYCODE_BACK -> { finish(); return true }
                KeyEvent.KEYCODE_DPAD_UP -> { showChannelInfo(); return true }
                KeyEvent.KEYCODE_DPAD_RIGHT,
                KeyEvent.KEYCODE_CHANNEL_UP -> { switchChannel(1); return true }
                KeyEvent.KEYCODE_DPAD_LEFT,
                KeyEvent.KEYCODE_CHANNEL_DOWN -> { switchChannel(-1); return true }
            }
        } else {
            when (keyCode) {
                KeyEvent.KEYCODE_BACK -> { finish(); return true }
                KeyEvent.KEYCODE_CHANNEL_UP -> { switchEpisode(1); return true }
                KeyEvent.KEYCODE_CHANNEL_DOWN -> { switchEpisode(-1); return true }
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onPause() {
        super.onPause()
        player.pause()
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(hideInfoRunnable)
        player.release()
    }
}
