package com.screenjournal.screen_time_journal

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Process
import java.io.File
import java.util.Calendar

/**
 * 使用情况统计读取、应用清单与图标缓存。
 */
object UsageStatsBridge {

    fun hasUsagePermission(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun usageManager(context: Context) =
        context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

    /**
     * 日桶统计：返回 [{package, dayStartMs, totalMs}]。
     * INTERVAL_DAILY 由系统按当地午夜切桶。
     */
    fun getDailyStats(context: Context, startMs: Long, endMs: Long): List<Map<String, Any>> {
        if (!hasUsagePermission(context)) return emptyList()
        val usm = usageManager(context)
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startMs, endMs)
            ?: return emptyList()
        // 同一天可能返回多个桶，按 (pkg, dayStart) 聚合
        val agg = LinkedHashMap<String, Long>()
        val keyOf = { pkg: String, t: Long ->
            val c = Calendar.getInstance().apply {
                timeInMillis = t
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            "$pkg|${c.timeInMillis}"
        }
        for (s in stats) {
            val total = s.totalTimeInForeground
            if (total <= 0) continue
            val key = keyOf(s.packageName, s.firstTimeStamp)
            agg[key] = (agg[key] ?: 0L) + total
        }
        return agg.entries.map { e ->
            val parts = e.key.split("|")
            mapOf(
                "package" to parts[0],
                "dayStartMs" to parts[1].toLong(),
                "totalMs" to e.value,
            )
        }
    }

    /**
     * 前台事件配对为使用片段：[{package, startMs, endMs}]。
     */
    fun getEvents(context: Context, startMs: Long, endMs: Long): List<Map<String, Any>> {
        if (!hasUsagePermission(context)) return emptyList()
        val usm = usageManager(context)
        val events = usm.queryEvents(startMs, endMs)
        val result = ArrayList<Map<String, Any>>()
        var currentPkg: String? = null
        var since = 0L
        val ev = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(ev)
            when (ev.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    val pkg = ev.packageName ?: continue
                    if (currentPkg != null && currentPkg != pkg && since > 0) {
                        result.add(fragment(currentPkg!!, since, ev.timeStamp.coerceAtMost(endMs)))
                    }
                    if (currentPkg != pkg) {
                        currentPkg = pkg
                        since = ev.timeStamp.coerceAtLeast(startMs)
                    }
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val pkg = ev.packageName
                    if (currentPkg != null && pkg == currentPkg && since > 0) {
                        result.add(fragment(currentPkg!!, since, ev.timeStamp.coerceAtMost(endMs)))
                        currentPkg = null
                        since = 0L
                    }
                }
            }
        }
        if (currentPkg != null && since > 0) {
            result.add(fragment(currentPkg!!, since, endMs))
        }
        // 合并相邻同包片段
        val merged = ArrayList<Map<String, Any>>()
        for (f in result) {
            val last = merged.lastOrNull()
            if (last != null && last["package"] == f["package"]) {
                val le = last["endMs"] as Long
                val fs = f["startMs"] as Long
                if (fs - le in 0..30_000) {
                    merged[merged.size - 1] = mapOf(
                        "package" to f["package"]!!,
                        "startMs" to last["startMs"]!!,
                        "endMs" to f["endMs"]!!,
                    )
                    continue
                }
            }
            merged.add(f)
        }
        return merged
    }

    private fun fragment(pkg: String, start: Long, end: Long): Map<String, Any> {
        val s = start.coerceAtLeast(0)
        val e = end.coerceAtLeast(s + 1000)
        return mapOf("package" to pkg, "startMs" to s, "endMs" to e)
    }

    /** 已安装应用清单，同时把图标刷新到 filesDir/icons。 */
    fun getInstalledApps(context: Context): List<Map<String, Any?>> {
        val pm = context.packageManager
        val apps = pm.getInstalledApplications(0)
        val iconDir = File(context.filesDir, "icons").apply { mkdirs() }
        return apps.map { ai ->
            var installMs: Long? = null
            try {
                val pi = pm.getPackageInfo(ai.packageName, 0)
                installMs = pi.firstInstallTime
            } catch (_: Exception) { }
            val iconPath = ensureIcon(context, ai.packageName, ai)
            mapOf(
                "package" to ai.packageName,
                "name" to (pm.getApplicationLabel(ai)?.toString() ?: ai.packageName),
                "isSystem" to ((ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                "installMs" to installMs,
                "iconPath" to iconPath,
            )
        }.sortedBy { it["name"] as String }
    }

    fun ensureIcon(context: Context, packageName: String): String? {
        return try {
            val ai = context.packageManager.getApplicationInfo(packageName, 0)
            ensureIcon(context, packageName, ai)
        } catch (_: Exception) {
            null
        }
    }

    private fun ensureIcon(context: Context, packageName: String, ai: ApplicationInfo): String? {
        return try {
            val file = File(context.filesDir, "icons/$packageName.png")
            // 缓存命中：已生成的图标直接复用，避免每次采集都重新压缩写盘（卡顿主因）
            if (file.exists() && file.length() > 0) return file.absolutePath
            val d = context.packageManager.getApplicationIcon(ai)
            val bmp = drawableToBitmap(d) ?: return null
            File(file.parentFile!!.absolutePath).mkdirs()
            file.outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
            file.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    private fun drawableToBitmap(d: Drawable): Bitmap? {
        if (d is BitmapDrawable) return d.bitmap
        val size = if (d.intrinsicWidth > 0) d.intrinsicWidth else 96
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        d.setBounds(0, 0, size, size)
        if (d is AdaptiveIconDrawable) {
            // 自适应图标需要先画背景再画前景
            d.background?.setBounds(0, 0, size, size)
            d.background?.draw(canvas)
            d.foreground?.setBounds(0, 0, size, size)
            d.foreground?.draw(canvas)
        } else {
            d.draw(canvas)
        }
        return bmp
    }

    fun appLabel(context: Context, pkg: String): String {
        return try {
            val pm = context.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (_: Exception) {
            pkg
        }
    }
}
