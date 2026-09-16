package com.screenjournal.screen_time_journal

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

// image_picker / image_cropper 要求宿主 Activity 为 FlutterFragmentActivity，
// 否则在部分 Android 版本上调起相册/裁剪页会直接崩溃。
class MainActivity : FlutterFragmentActivity() {

    private val channelName = "com.screenjournal.app/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    handle(call.method, call.arguments, result)
                } catch (e: Exception) {
                    result.error("NATIVE_ERROR", e.message, null)
                }
            }
    }

    private fun handle(method: String, args: Any?, result: MethodChannel.Result) {
        when (method) {
            "getDeviceName" -> result.success("${Build.MANUFACTURER} ${Build.MODEL}")

            // 权限状态
            "hasUsagePermission" -> result.success(UsageStatsBridge.hasUsagePermission(this))
            "isIgnoringBattery" -> result.success(isIgnoringBattery())
            "canDrawOverlays" -> result.success(Settings.canDrawOverlays(this))
            "notificationsEnabled" -> result.success(areNotificationsEnabled())
            "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())

            // 跳转设置
            "requestUsagePermission" -> {
                startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                result.success(null)
            }
            "requestIgnoreBattery" -> {
                val i = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.parse("package:$packageName"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try { startActivity(i) } catch (_: Exception) {
                    startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                }
                result.success(null)
            }
            "requestOverlayPermission" -> {
                startActivity(Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                result.success(null)
            }
            "openAccessibilitySettings" -> {
                startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                result.success(null)
            }
            "openNotificationSettings" -> {
                openNotificationSettings()
                result.success(null)
            }
            "openAutoStartSettings" -> {
                openAutoStart()
                result.success(null)
            }

            // 数据
            "getInstalledApps" -> result.success(UsageStatsBridge.getInstalledApps(this))
            "ensureIcon" -> {
                val pkg = args as String
                result.success(UsageStatsBridge.ensureIcon(this, pkg))
            }
            "getDailyStats" -> {
                val m = args as Map<*, *>
                result.success(UsageStatsBridge.getDailyStats(
                    this, (m["start"] as Number).toLong(), (m["end"] as Number).toLong()))
            }
            "getEvents" -> {
                val m = args as Map<*, *>
                result.success(UsageStatsBridge.getEvents(
                    this, (m["start"] as Number).toLong(), (m["end"] as Number).toLong()))
            }

            // 监控服务 / 限额
            "startMonitor" -> {
                MonitorService.start(this)
                result.success(null)
            }
            "stopMonitor" -> {
                MonitorService.stop(this)
                result.success(null)
            }
            "isMonitorRunning" -> result.success(MonitorService.running)
            "pushLimits" -> {
                val map = args as? Map<*, *> ?: emptyMap<String, Int>()
                val json = JSONObject()
                for ((k, v) in map) {
                    json.put(k as String, (v as Number).toInt())
                }
                getSharedPreferences(MonitorService.PREFS, Context.MODE_PRIVATE)
                    .edit().putString("limits", json.toString()).apply()
                // 重置当日触发状态由日期键自然处理
                if (map.isNotEmpty()) MonitorService.start(this)
                result.success(null)
            }
            "minimizeToHome" -> {
                val ok = LimitAccessibilityService.instance?.goHome() ?: false
                if (!ok) {
                    startActivity(Intent(Intent.ACTION_MAIN)
                        .addCategory(Intent.CATEGORY_HOME)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun isIgnoringBattery(): Boolean {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    @Suppress("DEPRECATION")
    private fun areNotificationsEnabled(): Boolean {
        val nm = getSystemService(NotificationManager::class.java)
        return nm.areNotificationsEnabled()
    }

    private fun isAccessibilityEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabled = am.getEnabledAccessibilityServiceList(
            AccessibilityServiceInfo.FEEDBACK_ALL_MASK
        )
        val target = ComponentName(this, LimitAccessibilityService::class.java)
        return enabled.any { it.resolveInfo?.serviceInfo?.let { si ->
            si.packageName == target.packageName && si.name == target.className
        } == true }
    }

    private fun openNotificationSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } else {
            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.parse("package:$packageName"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    private fun openAutoStart() {
        val intents = listOf(
            Intent().setComponent(ComponentName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity")),
            Intent().setComponent(ComponentName(
                "com.coloros.safecenter",
                "com.coloros.safecenter.startupapp.StartupAppListActivity")),
            Intent().setComponent(ComponentName(
                "com.oppo.safe",
                "com.oppo.safe.permission.startup.StartupAppListActivity")),
            Intent().setComponent(ComponentName(
                "com.iqoo.relationmanager",
                "com.iqoo.relationmanager.autoboot.AutoBootListActivity")),
            Intent().setComponent(ComponentName(
                "com.vivo.permissionmanager",
                "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
            Intent().setComponent(ComponentName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")),
            Intent().setComponent(ComponentName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.optimize.process.ProtectActivity")),
            Intent().setComponent(ComponentName(
                "com.meizu.safe",
                "com.meizu.safe.security.SHOW_APPSEC")),
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.parse("package:$packageName")),
        )
        for (i in intents) {
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                if (packageManager.resolveActivity(i, 0) != null) {
                    startActivity(i)
                    return
                }
            } catch (_: Exception) { }
        }
        startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}
