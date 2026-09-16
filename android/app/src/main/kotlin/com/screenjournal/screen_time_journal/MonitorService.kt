package com.screenjournal.screen_time_journal

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Vibrator
import android.os.VibratorManager
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 前台服务：约每 20 秒用系统 UsageStats 刷新当日各应用时长，
 * 达到限额时弹出全屏提醒并（经无障碍服务）回到桌面。
 */
class MonitorService : Service() {

    companion object {
        const val ACTION_START = "com.screenjournal.START"
        const val ACTION_STOP = "com.screenjournal.STOP"
        private const val CHANNEL_ID = "screen_time_monitor"
        private const val NOTIF_ID = 1001
        const val PREFS = "screen_time_prefs"
        const val KEY_MONITOR_ENABLED = "monitor_enabled"
        private const val TICK_MS = 20_000L

        @Volatile
        var running = false
            private set

        fun start(context: Context) {
            val i = Intent(context, MonitorService::class.java).setAction(ACTION_START)
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putBoolean(KEY_MONITOR_ENABLED, true).apply()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(i)
            } else {
                context.startService(i)
            }
        }

        fun stop(context: Context) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putBoolean(KEY_MONITOR_ENABLED, false).apply()
            context.startService(
                Intent(context, MonitorService::class.java).setAction(ACTION_STOP)
            )
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val tick = object : Runnable {
        override fun run() {
            try {
                check()
            } catch (_: Exception) { }
            handler.postDelayed(this, TICK_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        startAsForeground()
        handler.removeCallbacks(tick)
        handler.post(tick)
        running = true
        return START_STICKY
    }

    private fun startAsForeground() {
        val pi = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName) ?: Intent(),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val n: Notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("屏记正在记录屏幕时间")
            .setContentText("后台统计运行中")
            .setSmallIcon(android.R.drawable.ic_menu_recent_history)
            .setOngoing(true)
            .setContentIntent(pi)
            .setPriority(Notification.PRIORITY_LOW)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF_ID, n)
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID, "屏幕时间监控", NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "保持屏幕时间统计与限额提醒在后台运行"
                setShowBadge(false)
            }
            (getSystemService(NotificationManager::class.java)).createNotificationChannel(ch)
        }
    }

    private fun dayStartMillis(): Long {
        val c = java.util.Calendar.getInstance()
        c.set(java.util.Calendar.HOUR_OF_DAY, 0)
        c.set(java.util.Calendar.MINUTE, 0)
        c.set(java.util.Calendar.SECOND, 0)
        c.set(java.util.Calendar.MILLISECOND, 0)
        return c.timeInMillis
    }

    private fun check() {
        if (!UsageStatsBridge.hasUsagePermission(this)) return
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val limitsRaw = prefs.getString("limits", null) ?: return
        val limits = try {
            JSONObject(limitsRaw)
        } catch (_: Exception) {
            return
        }
        if (limits.length() == 0) return

        val now = System.currentTimeMillis()
        val dayStart = dayStartMillis()
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_BEST, dayStart, now) ?: return
        val todayKey = SimpleDateFormat("yyyyMMdd", Locale.US).format(Date(now))
        val triggeredKey = "triggered_$todayKey"
        val triggered = JSONArray(prefs.getString(triggeredKey, "[]"))
        val triggeredSet = HashSet<String>().apply {
            for (i in 0 until triggered.length()) add(triggered.getString(i))
        }

        val totals = HashMap<String, Long>()
        for (s in stats) {
            totals[s.packageName] = (totals[s.packageName] ?: 0L) + s.totalTimeInForeground
        }

        val it = limits.keys()
        while (it.hasNext()) {
            val pkg = it.next()
            val limitMs = limits.optLong(pkg, 0L) * 60_000L
            if (limitMs <= 0) continue
            val used = totals[pkg] ?: 0L
            if (used >= limitMs && !triggeredSet.contains(pkg)) {
                triggeredSet.add(pkg)
                val arr = JSONArray()
                triggeredSet.forEach { p -> arr.put(p) }
                prefs.edit().putString(triggeredKey, arr.toString()).apply()
                fireLimit(pkg, used, limitMs)
            }
        }
    }

    private fun fireLimit(pkg: String, usedMs: Long, limitMs: Long) {
        try {
            val vib = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(VIBRATOR_SERVICE) as Vibrator
            }
            vib.vibrate(longArrayOf(0, 300, 200, 300), -1)
        } catch (_: Exception) { }

        val i = Intent(this, LimitOverlayActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            )
            putExtra("package", pkg)
            putExtra("appName", UsageStatsBridge.appLabel(this@MonitorService, pkg))
            putExtra("usedMs", usedMs)
            putExtra("limitMs", limitMs)
        }
        startActivity(i)
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        running = false
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // 从最近任务划掉后，利用 AlarmManager 尽快复活
        val am = getSystemService(AlarmManager::class.java)
        val restart = Intent(this, MonitorService::class.java).setAction(ACTION_START)
        val pi = PendingIntent.getService(
            this, 2, restart, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_ONE_SHOT
        )
        am.set(AlarmManager.RTC, System.currentTimeMillis() + 2000, pi)
        super.onTaskRemoved(rootIntent)
    }
}
