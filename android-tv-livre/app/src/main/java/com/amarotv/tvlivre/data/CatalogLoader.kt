package com.amarotv.tvlivre.data

import android.content.Context
import com.google.gson.Gson
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

object CatalogLoader {

    private const val CATALOG_URL =
        "https://tv-livre-catalog.jonatas-amaro2.workers.dev/catalog.json"
    private const val CACHE_FILE = "catalog_cache.json"
    private val gson = Gson()

    fun load(ctx: Context): Catalog {
        val remote = fetchRemote()
        if (remote != null) {
            ctx.openFileOutput(CACHE_FILE, Context.MODE_PRIVATE).use {
                it.write(gson.toJson(remote).toByteArray())
            }
            return remote
        }
        return loadCache(ctx) ?: Catalog()
    }

    private fun fetchRemote(): Catalog? = try {
        val conn = URL(CATALOG_URL).openConnection() as HttpURLConnection
        conn.connectTimeout = 8000
        conn.readTimeout = 8000
        InputStreamReader(conn.inputStream).use { reader ->
            gson.fromJson(reader, Catalog::class.java)
        }
    } catch (_: Exception) {
        null
    }

    private fun loadCache(ctx: Context): Catalog? = try {
        ctx.openFileInput(CACHE_FILE).use { stream ->
            InputStreamReader(stream).use { reader ->
                gson.fromJson(reader, Catalog::class.java)
            }
        }
    } catch (_: Exception) {
        null
    }
}
