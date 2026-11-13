package com.amarotv.tvlivre.ui

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.amarotv.tvlivre.R
import androidx.appcompat.app.AlertDialog
import com.amarotv.tvlivre.data.Catalog
import com.amarotv.tvlivre.data.CatalogLoader
import com.amarotv.tvlivre.data.Channel
import com.amarotv.tvlivre.data.ContentItem
import com.amarotv.tvlivre.data.Row
import com.amarotv.tvlivre.data.Section
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.bumptech.glide.Glide
import android.util.Log
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*
import kotlin.concurrent.thread
import org.json.JSONObject

class MainActivity : AppCompatActivity() {

    private lateinit var tabsContainer: LinearLayout
    private lateinit var contentGrid: RecyclerView
    private lateinit var heroBg: ImageView
    private lateinit var heroTitle: TextView
    private lateinit var heroDesc: TextView
    private lateinit var heroInfo: LinearLayout
    private lateinit var clock: TextView
    private lateinit var inlinePlayerView: PlayerView
    private var inlinePlayer: ExoPlayer? = null

    // TV AO VIVO views
    private lateinit var liveInfoBar: LinearLayout
    private lateinit var liveChannelName: TextView
    private lateinit var liveChannelDesc: TextView
    private lateinit var btnFullscreen: TextView
    private lateinit var btnChannelGrid: TextView

    // Channel grid overlay
    private lateinit var channelGridOverlay: LinearLayout
    private lateinit var channelListView: RecyclerView
    private lateinit var channelCount: TextView
    private lateinit var gridPreviewPlayerView: PlayerView
    private var gridPreviewPlayer: ExoPlayer? = null
    private lateinit var gridPreviewName: TextView
    private lateinit var gridPreviewDesc: TextView
    private lateinit var gridCategoryTabs: LinearLayout

    private lateinit var categoryTitle: TextView
    private lateinit var categoryArrow: TextView

    private var catalog: Catalog? = null
    private var sections = mutableListOf<Section>()
    private var currentTabIndex = 0
    private var liveChannels = listOf<Channel>()
    private var currentChannel: Channel? = null
    private val handler = Handler(Looper.getMainLooper())

    private var currentContentRows: List<Row> = emptyList()
    private var currentRowIndex = 0

    private val allowedTabs = listOf(
        "TV AO VIVO", "CANAIS 24 HS", "SÉRIES", "ANIMES", "DESENHOS", "FILMES", "APLICATIVOS"
    )

    data class ExternalApp(val name: String, val pkg: String, val color: Int)
    private val externalApps = listOf(
        ExternalApp("YouTube", "com.google.android.youtube.tv", Color.parseColor("#FF0000")),
        ExternalApp("Netflix", "com.netflix.mediaclient", Color.parseColor("#E50914")),
        ExternalApp("Disney+", "com.disney.disneyplus", Color.parseColor("#113CCF")),
        ExternalApp("Prime Video", "com.amazon.avod.thirdpartyclient", Color.parseColor("#00A8E1")),
        ExternalApp("Spotify", "com.spotify.tv.android", Color.parseColor("#1DB954"))
    )

    private val categories = listOf(
        "TODOS", "FAVORITOS", "Geral", "Entretenimento", "Filmes",
        "Jornalismo", "Series", "Infantil", "Educativo", "Religioso"
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        tabsContainer = findViewById(R.id.tabsContainer)
        contentGrid = findViewById(R.id.contentGrid)
        heroBg = findViewById(R.id.heroBg)
        heroTitle = findViewById(R.id.heroTitle)
        heroDesc = findViewById(R.id.heroDesc)
        heroInfo = findViewById(R.id.heroInfo)
        clock = findViewById(R.id.clock)
        inlinePlayerView = findViewById(R.id.inlinePlayer)

        // TV AO VIVO views
        liveInfoBar = findViewById(R.id.liveInfoBar)
        liveChannelName = findViewById(R.id.liveChannelName)
        liveChannelDesc = findViewById(R.id.liveChannelDesc)
        btnFullscreen = findViewById(R.id.btnFullscreen)
        btnChannelGrid = findViewById(R.id.btnChannelGrid)

        // Channel grid overlay
        channelGridOverlay = findViewById(R.id.channelGridOverlay)
        channelListView = findViewById(R.id.channelListView)
        channelCount = findViewById(R.id.channelCount)
        gridPreviewPlayerView = findViewById(R.id.gridPreviewPlayer)
        gridPreviewPlayerView.useController = false
        gridPreviewName = findViewById(R.id.gridPreviewName)
        gridPreviewDesc = findViewById(R.id.gridPreviewDesc)
        gridCategoryTabs = findViewById(R.id.gridCategoryTabs)

        categoryTitle = findViewById(R.id.categoryTitle)
        categoryArrow = findViewById(R.id.categoryArrow)

        contentGrid.layoutManager = LinearLayoutManager(this, LinearLayoutManager.HORIZONTAL, false)
        channelListView.layoutManager = LinearLayoutManager(this)

        findViewById<TextView>(R.id.exitBtn).setOnClickListener { finishAffinity() }

        btnFullscreen.setOnClickListener {
            currentChannel?.let { playChannel(it) }
        }

        btnChannelGrid.setOnClickListener { showChannelGrid() }

        startClockUpdater()
        loadCatalog()
    }

    private fun startClockUpdater() {
        val fmt = SimpleDateFormat("HH:mm", Locale.getDefault())
        val tick = object : Runnable {
            override fun run() {
                clock.text = fmt.format(Date())
                handler.postDelayed(this, 30_000)
            }
        }
        tick.run()
    }

    private fun loadCatalog() {
        thread {
            val cat = CatalogLoader.load(this)
            runOnUiThread {
                catalog = cat
                buildTabs(cat)
                selectTab(0)
            }
        }
    }

    private fun buildTabs(cat: Catalog) {
        tabsContainer.removeAllViews()
        sections.clear()

        for (s in cat.sections) {
            val tab = s.tab.ifEmpty { s.title }
            if (allowedTabs.contains(tab)) sections.add(s)
        }
        sections.add(Section(tab = "APLICATIVOS"))

        for ((i, s) in sections.withIndex()) {
            val tv = TextView(this).apply {
                text = s.tab.ifEmpty { s.title }
                setTextColor(Color.WHITE)
                textSize = 16f
                typeface = Typeface.DEFAULT_BOLD
                setPadding(24, 8, 24, 8)
                setBackgroundResource(R.drawable.tab_background)
                isFocusable = true
                isFocusableInTouchMode = true
                gravity = Gravity.CENTER
                tag = i
                setOnFocusChangeListener { v, hasFocus ->
                    if (hasFocus) selectTab(v.tag as Int)
                }
                setOnClickListener { v -> selectTab(v.tag as Int) }
            }
            tabsContainer.addView(tv)
        }
    }

    private fun selectTab(index: Int) {
        if (sections.isEmpty()) return
        currentTabIndex = index

        for (i in 0 until tabsContainer.childCount) {
            tabsContainer.getChildAt(i).isSelected = (i == index)
        }

        // Hide channel grid overlay when switching tabs
        channelGridOverlay.visibility = View.GONE
        stopGridPreviewPlayer()

        val section = sections[index]
        val tabName = section.tab.ifEmpty { section.title }

        val isLiveTab = tabName == "TV AO VIVO" || tabName == "CANAIS 24 HS"
        if (!isLiveTab) stopInlinePlayer()

        when {
            tabName == "APLICATIVOS" -> showAppsTab()
            isLiveTab -> showLiveTab(section)
            else -> showContentTab(section)
        }
    }

    // ── TV AO VIVO ──

    private fun showLiveTab(section: Section) {
        liveInfoBar.visibility = View.VISIBLE
        heroInfo.visibility = View.GONE
        contentGrid.visibility = View.GONE
        categoryTitle.visibility = View.GONE
        categoryArrow.visibility = View.GONE
        currentContentRows = emptyList()

        liveChannels = section.channels ?: emptyList()

        // Load last watched channel or default to first
        val lastChannelName = getPreferences(Context.MODE_PRIVATE)
            .getString("last_channel", null)
        val channel = liveChannels.find { it.name == lastChannelName }
            ?: liveChannels.firstOrNull()

        channel?.let { showLiveChannel(it) }
    }

    private fun showLiveChannel(ch: Channel) {
        currentChannel = ch
        liveChannelName.text = ch.name
        liveChannelDesc.text = "Canal Ao Vivo | ${ch.category}"

        // Auto-play inline
        playInline(ch.url)

        // Save as last watched
        getPreferences(Context.MODE_PRIVATE).edit()
            .putString("last_channel", ch.name).apply()
    }

    private fun playInline(url: String) {
        heroBg.visibility = View.GONE
        inlinePlayerView.visibility = View.VISIBLE

        if (inlinePlayer == null) {
            inlinePlayer = ExoPlayer.Builder(this).build()
            inlinePlayerView.player = inlinePlayer
            inlinePlayerView.useController = false
        }
        inlinePlayer?.apply {
            setMediaItem(MediaItem.fromUri(url))
            prepare()
            playWhenReady = true
        }
    }

    private fun stopInlinePlayer() {
        inlinePlayer?.stop()
        inlinePlayerView.visibility = View.GONE
        heroBg.visibility = View.VISIBLE
    }

    private fun playChannel(ch: Channel, live: Boolean = true) {
        if (live) {
            PlayerActivity.liveChannels = liveChannels
            PlayerActivity.currentIndex = liveChannels.indexOf(ch).coerceAtLeast(0)
        }
        val intent = Intent(this, PlayerActivity::class.java)
        intent.putExtra("url", ch.url)
        intent.putExtra("title", ch.name)
        intent.putExtra("live", live)
        intent.putExtra("channelIndex", PlayerActivity.currentIndex)
        startActivity(intent)
    }

    private fun showChannelGrid() {
        channelGridOverlay.visibility = View.VISIBLE
        inlinePlayer?.pause()
        startGridPreviewPlayer()

        buildCategoryTabs()
        showFilteredChannels("TODOS")
    }

    private fun startGridPreviewPlayer() {
        if (gridPreviewPlayer == null) {
            gridPreviewPlayer = ExoPlayer.Builder(this).build()
            gridPreviewPlayerView.player = gridPreviewPlayer
        }
        currentChannel?.let { playGridPreview(it.url) }
    }

    private fun playGridPreview(url: String) {
        gridPreviewPlayer?.apply {
            setMediaItem(MediaItem.fromUri(url))
            prepare()
            playWhenReady = true
        }
    }

    private fun stopGridPreviewPlayer() {
        gridPreviewPlayer?.release()
        gridPreviewPlayer = null
    }

    private fun buildCategoryTabs() {
        gridCategoryTabs.removeAllViews()
        for (cat in categories) {
            val tv = TextView(this).apply {
                text = cat
                setTextColor(Color.WHITE)
                textSize = 13f
                typeface = Typeface.DEFAULT_BOLD
                setPadding(16, 6, 16, 6)
                setBackgroundResource(R.drawable.tab_background)
                isFocusable = true
                isFocusableInTouchMode = true
                val lp = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
                lp.marginEnd = 8
                layoutParams = lp
                setOnClickListener { showFilteredChannels(cat) }
                setOnFocusChangeListener { _, hasFocus ->
                    if (hasFocus) showFilteredChannels(cat)
                }
            }
            gridCategoryTabs.addView(tv)
        }
    }

    private fun showFilteredChannels(category: String) {
        val filtered = if (category == "TODOS") liveChannels
        else liveChannels.filter {
            it.category.contains(category, ignoreCase = true) ||
                it.group.contains(category, ignoreCase = true)
        }

        channelCount.text = "${filtered.size} canais"

        val currentIdx = currentChannel?.let { cur ->
            filtered.indexOfFirst { it.url == cur.url }
        } ?: -1

        channelListView.adapter = ChannelListAdapter(filtered, currentIdx) { ch ->
            channelGridOverlay.visibility = View.GONE
            stopGridPreviewPlayer()
            showLiveChannel(ch)
            playChannel(ch)
        }

        // Scroll to current channel, focus it, and show preview
        val focusIdx = if (currentIdx >= 0) currentIdx else 0
        if (filtered.isNotEmpty()) {
            channelListView.scrollToPosition(focusIdx)
            channelListView.post {
                channelListView.findViewHolderForAdapterPosition(focusIdx)
                    ?.itemView?.requestFocus()
            }
            updateGridPreview(filtered[focusIdx])
        }
    }

    private fun updateGridPreview(ch: Channel) {
        gridPreviewName.text = ch.name
        gridPreviewDesc.text = "Canal Ao Vivo • ${ch.category}"
        playGridPreview(ch.url)
    }

    // ── Other tabs ──

    private fun showAppsTab() {
        liveInfoBar.visibility = View.GONE
        heroInfo.visibility = View.VISIBLE
        contentGrid.visibility = View.VISIBLE
        categoryTitle.visibility = View.GONE
        categoryArrow.visibility = View.GONE
        currentContentRows = emptyList()

        heroTitle.text = "Aplicativos"
        heroDesc.text = "Seus aplicativos favoritos"
        heroBg.setImageDrawable(null)

        contentGrid.adapter = AppsAdapter(externalApps) { app -> launchApp(app.pkg) }
    }

    private fun launchApp(pkg: String) {
        val intent = packageManager.getLeanbackLaunchIntentForPackage(pkg)
            ?: packageManager.getLaunchIntentForPackage(pkg)
        if (intent != null) {
            startActivity(intent)
        } else {
            Toast.makeText(this, "App não instalado", Toast.LENGTH_SHORT).show()
        }
    }

    private fun showContentTab(section: Section) {
        liveInfoBar.visibility = View.GONE
        heroInfo.visibility = View.VISIBLE
        contentGrid.visibility = View.VISIBLE

        section.channels?.let { channels ->
            categoryTitle.visibility = View.GONE
            categoryArrow.visibility = View.GONE
            currentContentRows = emptyList()
            contentGrid.adapter = ChannelAdapter(channels) { ch -> playChannel(ch) }
            if (channels.isNotEmpty()) {
                heroTitle.text = channels[0].name
                heroDesc.text = channels[0].category
                if (channels[0].logo.isNotEmpty()) {
                    Glide.with(this).load(channels[0].logo).into(heroBg)
                }
            }
            return
        }

        currentContentRows = section.rows ?: section.categories ?: emptyList()
        currentRowIndex = 0

        if (currentContentRows.size > 1) {
            categoryTitle.visibility = View.VISIBLE
        } else {
            categoryTitle.visibility = View.GONE
        }

        showCategory(0)
    }

    private fun showCategory(index: Int) {
        if (currentContentRows.isEmpty()) return
        currentRowIndex = index.coerceIn(0, currentContentRows.size - 1)

        val row = currentContentRows[currentRowIndex]
        categoryTitle.text = row.title.ifEmpty { "Todos" }

        val items = row.items ?: emptyList()
        contentGrid.adapter = PosterAdapter(items) { item ->
            if (item.seasons != null && item.seasons.isNotEmpty()) {
                DetailActivity.currentItem = item
                startActivity(Intent(this, DetailActivity::class.java))
            } else if (item.url.isNotEmpty()) {
                PlayerActivity.episodeList = emptyList()
                val intent = Intent(this, PlayerActivity::class.java)
                intent.putExtra("url", item.url)
                intent.putExtra("title", item.title)
                intent.putExtra("live", false)
                startActivity(intent)
            } else if (item.saimoId.isNotEmpty()) {
                resolveSaimoMovie(item)
            }
        }

        if (items.isNotEmpty()) {
            val first = items[0]
            heroTitle.text = first.title
            heroDesc.text = first.description
            if (first.background.isNotEmpty()) {
                Glide.with(this).load(first.background).into(heroBg)
            } else if (first.poster.isNotEmpty()) {
                Glide.with(this).load(first.poster).into(heroBg)
            }
        }

        val total = currentContentRows.size
        if (total <= 1) {
            categoryArrow.visibility = View.GONE
        } else {
            categoryArrow.visibility = View.VISIBLE
            categoryArrow.text = if (currentRowIndex < total - 1) "▼" else "▲"
        }

        (contentGrid.layoutManager as? LinearLayoutManager)?.scrollToPosition(0)
    }

    override fun onPause() {
        super.onPause()
        inlinePlayer?.pause()
    }

    override fun onResume() {
        super.onResume()
        if (inlinePlayerView.visibility == View.VISIBLE) {
            inlinePlayer?.playWhenReady = true
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        inlinePlayer?.release()
        inlinePlayer = null
        stopGridPreviewPlayer()
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            if (channelGridOverlay.visibility == View.VISIBLE) {
                channelGridOverlay.visibility = View.GONE
                stopGridPreviewPlayer()
                inlinePlayer?.playWhenReady = true
                return true
            }
            showExitDialog()
            return true
        }

        val focused = currentFocus

        // ── Tab navigation: manual LEFT/RIGHT between tabs ──
        if (focused != null && focused.parent == tabsContainer) {
            if (keyCode == KeyEvent.KEYCODE_DPAD_LEFT || keyCode == KeyEvent.KEYCODE_DPAD_RIGHT) {
                val idx = focused.tag as? Int ?: return super.onKeyDown(keyCode, event)
                val next = if (keyCode == KeyEvent.KEYCODE_DPAD_RIGHT) idx + 1 else idx - 1
                if (next in 0 until tabsContainer.childCount) {
                    val nextTab = tabsContainer.getChildAt(next)
                    nextTab?.requestFocus()
                    val sv = tabsContainer.parent as? HorizontalScrollView
                    sv?.post { sv.smoothScrollTo((nextTab?.left ?: 0) - 48, 0) }
                }
                return true
            }
            // DOWN from tab → first content item
            if (keyCode == KeyEvent.KEYCODE_DPAD_DOWN && contentGrid.visibility == View.VISIBLE) {
                contentGrid.post {
                    (contentGrid.layoutManager as? LinearLayoutManager)?.scrollToPosition(0)
                    contentGrid.post { contentGrid.getChildAt(0)?.requestFocus() }
                }
                return true
            }
        }

        // ── Content grid navigation ──
        if (contentGrid.hasFocus() && contentGrid.visibility == View.VISIBLE) {
            // UP → previous category or back to tab
            if (keyCode == KeyEvent.KEYCODE_DPAD_UP) {
                if (currentContentRows.size > 1 && currentRowIndex > 0) {
                    showCategory(currentRowIndex - 1)
                    contentGrid.post { contentGrid.getChildAt(0)?.requestFocus() }
                    return true
                }
                tabsContainer.getChildAt(currentTabIndex)?.requestFocus()
                return true
            }
            // DOWN → next category
            if (keyCode == KeyEvent.KEYCODE_DPAD_DOWN && currentContentRows.size > 1
                && currentRowIndex < currentContentRows.size - 1
            ) {
                showCategory(currentRowIndex + 1)
                contentGrid.post { contentGrid.getChildAt(0)?.requestFocus() }
                return true
            }
            // LEFT/RIGHT → block escape at edges
            if (keyCode == KeyEvent.KEYCODE_DPAD_RIGHT || keyCode == KeyEvent.KEYCODE_DPAD_LEFT) {
                val pos = focused?.let { contentGrid.getChildAdapterPosition(it) } ?: -1
                val count = contentGrid.adapter?.itemCount ?: 0
                if (keyCode == KeyEvent.KEYCODE_DPAD_RIGHT && pos >= count - 1) return true
                if (keyCode == KeyEvent.KEYCODE_DPAD_LEFT && pos <= 0) return true
            }
        }

        return super.onKeyDown(keyCode, event)
    }

    private fun showExitDialog() {
        AlertDialog.Builder(this)
            .setMessage("Deseja realmente sair do aplicativo?")
            .setPositiveButton("Sim") { _, _ -> finishAffinity() }
            .setNegativeButton("Não") { d, _ -> d.dismiss() }
            .setCancelable(true)
            .show()
    }

    // ── Adapters ──

    // Channel list for grid overlay (numbered list like Roku)
    inner class ChannelListAdapter(
        private val channels: List<Channel>,
        private val selectedIndex: Int = -1,
        private val onClick: (Channel) -> Unit
    ) : RecyclerView.Adapter<ChannelListAdapter.VH>() {

        inner class VH(val root: LinearLayout) : RecyclerView.ViewHolder(root) {
            val number: TextView = root.getChildAt(0) as TextView
            val name: TextView = root.getChildAt(1) as TextView
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
            val root = LinearLayout(parent.context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                layoutParams = RecyclerView.LayoutParams(
                    RecyclerView.LayoutParams.MATCH_PARENT,
                    RecyclerView.LayoutParams.WRAP_CONTENT
                )
                setPadding(8, 6, 8, 6)
                isFocusable = true
                isFocusableInTouchMode = true
                setBackgroundColor(Color.TRANSPARENT)
            }
            val num = TextView(parent.context).apply {
                layoutParams = LinearLayout.LayoutParams(40, LinearLayout.LayoutParams.WRAP_CONTENT)
                setTextColor(Color.parseColor("#AAFFFFFF"))
                textSize = 13f
            }
            val name = TextView(parent.context).apply {
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                setTextColor(Color.WHITE)
                textSize = 14f
                maxLines = 1
                setPadding(8, 0, 0, 0)
            }
            root.addView(num)
            root.addView(name)
            return VH(root)
        }

        override fun onBindViewHolder(holder: VH, position: Int) {
            val ch = channels[position]
            holder.number.text = "${position + 1}"
            holder.name.text = ch.name

            holder.root.setOnClickListener { onClick(ch) }
            holder.root.setOnFocusChangeListener { v, hasFocus ->
                if (hasFocus) {
                    v.setBackgroundColor(Color.parseColor("#55FFFFFF"))
                    holder.name.typeface = Typeface.DEFAULT_BOLD
                    updateGridPreview(ch)
                } else {
                    v.setBackgroundColor(Color.TRANSPARENT)
                    holder.name.typeface = Typeface.DEFAULT
                }
            }
        }

        override fun getItemCount() = channels.size
    }

    inner class AppsAdapter(
        private val apps: List<ExternalApp>,
        private val onClick: (ExternalApp) -> Unit
    ) : RecyclerView.Adapter<AppsAdapter.VH>() {

        inner class VH(val root: LinearLayout) : RecyclerView.ViewHolder(root) {
            val icon: ImageView = root.getChildAt(0) as ImageView
            val label: TextView = root.getChildAt(1) as TextView
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
            val root = LinearLayout(parent.context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                layoutParams = RecyclerView.LayoutParams(200, 220).apply { marginEnd = 24 }
                isFocusable = true
                isFocusableInTouchMode = true
                setBackgroundResource(R.drawable.tab_background)
                setPadding(16, 16, 16, 16)
            }
            val icon = ImageView(parent.context).apply {
                layoutParams = LinearLayout.LayoutParams(120, 120)
                scaleType = ImageView.ScaleType.FIT_CENTER
            }
            val label = TextView(parent.context).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
                setTextColor(Color.WHITE)
                textSize = 14f
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
            }
            root.addView(icon)
            root.addView(label)
            return VH(root)
        }

        override fun onBindViewHolder(holder: VH, position: Int) {
            val app = apps[position]
            holder.label.text = app.name
            holder.root.setOnClickListener { onClick(app) }
            try {
                val appIcon = packageManager.getApplicationIcon(app.pkg)
                holder.icon.setImageDrawable(appIcon)
            } catch (_: PackageManager.NameNotFoundException) {
                holder.icon.setColorFilter(app.color)
            }
        }

        override fun getItemCount() = apps.size
    }

    inner class PosterAdapter(
        private val items: List<ContentItem>,
        private val onClick: (ContentItem) -> Unit
    ) : RecyclerView.Adapter<PosterAdapter.VH>() {

        inner class VH(val root: FrameLayout) : RecyclerView.ViewHolder(root) {
            val poster: ImageView = root.getChildAt(0) as ImageView
            val title: TextView = root.getChildAt(1) as TextView
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
            val root = FrameLayout(parent.context).apply {
                layoutParams = RecyclerView.LayoutParams(160, 240).apply { marginEnd = 16 }
                isFocusable = true
                isFocusableInTouchMode = true
                setBackgroundResource(R.drawable.tab_background)
            }
            val img = ImageView(parent.context).apply {
                layoutParams = FrameLayout.LayoutParams(160, 200)
                scaleType = ImageView.ScaleType.CENTER_CROP
            }
            val txt = TextView(parent.context).apply {
                layoutParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    Gravity.BOTTOM
                )
                setTextColor(Color.WHITE)
                textSize = 12f
                maxLines = 2
                setPadding(4, 0, 4, 4)
            }
            root.addView(img)
            root.addView(txt)
            return VH(root)
        }

        override fun onBindViewHolder(holder: VH, position: Int) {
            val item = items[position]
            holder.title.text = item.title
            if (item.poster.isNotEmpty()) {
                Glide.with(holder.poster).load(item.poster).into(holder.poster)
            }
            holder.root.setOnClickListener { onClick(item) }
            holder.root.setOnFocusChangeListener { _, hasFocus ->
                if (hasFocus) {
                    heroTitle.text = item.title
                    heroDesc.text = item.description
                    when {
                        item.background.isNotEmpty() -> Glide.with(this@MainActivity).load(item.background).into(heroBg)
                        item.poster.isNotEmpty() -> Glide.with(this@MainActivity).load(item.poster).into(heroBg)
                        else -> heroBg.setImageDrawable(null)
                    }
                }
            }
        }

        override fun getItemCount() = items.size
    }

    inner class ChannelAdapter(
        private val channels: List<Channel>,
        private val onClick: (Channel) -> Unit
    ) : RecyclerView.Adapter<ChannelAdapter.VH>() {

        inner class VH(val root: FrameLayout) : RecyclerView.ViewHolder(root) {
            val logo: ImageView = root.getChildAt(0) as ImageView
            val name: TextView = root.getChildAt(1) as TextView
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
            val root = FrameLayout(parent.context).apply {
                layoutParams = RecyclerView.LayoutParams(180, 140).apply { marginEnd = 16 }
                isFocusable = true
                isFocusableInTouchMode = true
                setBackgroundResource(R.drawable.tab_background)
            }
            val img = ImageView(parent.context).apply {
                layoutParams = FrameLayout.LayoutParams(180, 100)
                scaleType = ImageView.ScaleType.FIT_CENTER
                setPadding(8, 8, 8, 8)
            }
            val txt = TextView(parent.context).apply {
                layoutParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    Gravity.BOTTOM
                )
                setTextColor(Color.WHITE)
                textSize = 11f
                maxLines = 1
                gravity = Gravity.CENTER
                setPadding(4, 0, 4, 4)
            }
            root.addView(img)
            root.addView(txt)
            return VH(root)
        }

        override fun onBindViewHolder(holder: VH, position: Int) {
            val ch = channels[position]
            holder.name.text = ch.name
            if (ch.logo.isNotEmpty()) {
                Glide.with(holder.logo).load(ch.logo).into(holder.logo)
            }
            holder.root.setOnClickListener { onClick(ch) }
            holder.root.setOnFocusChangeListener { _, hasFocus ->
                if (hasFocus) {
                    heroTitle.text = ch.name
                    heroDesc.text = ch.category
                }
            }
        }

        override fun getItemCount() = channels.size
    }

    private fun resolveSaimoMovie(item: ContentItem) {
        Toast.makeText(this, "Carregando ${item.title}...", Toast.LENGTH_SHORT).show()
        thread {
            try {
                val fonteParam = if (item.saimoFonte.isNotEmpty()) "&fonte=${item.saimoFonte}" else ""
                val endpoint = "https://tv-livre-catalog.jonatas-amaro2.workers.dev/saimo?id=${item.saimoId}&tipo=filmes$fonteParam"
                val conn = URL(endpoint).openConnection() as HttpURLConnection
                conn.connectTimeout = 15000
                conn.readTimeout = 15000
                val body = conn.inputStream.bufferedReader().readText()
                val json = JSONObject(body)
                if (json.optBoolean("ok")) {
                    val url = json.optString("url", "")
                    val format = json.optString("format", "")
                    runOnUiThread {
                        PlayerActivity.episodeList = emptyList()
                        val intent = Intent(this, PlayerActivity::class.java)
                        intent.putExtra("url", url)
                        intent.putExtra("format", format)
                        intent.putExtra("title", item.title)
                        intent.putExtra("live", false)
                        startActivity(intent)
                    }
                } else {
                    runOnUiThread { Toast.makeText(this, "Stream indisponível", Toast.LENGTH_SHORT).show() }
                }
            } catch (e: Exception) {
                Log.e("TVLivre", "resolveSaimoMovie error: ${e.message}", e)
                runOnUiThread { Toast.makeText(this, "Erro ao carregar stream", Toast.LENGTH_SHORT).show() }
            }
        }
    }
}
