package com.screenjournal.screen_time_journal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** 开机后若用户曾开启监控，则自动恢复前台服务。 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_LOCKED_BOOT_COMPLETED
        ) {
            val enabled = context.getSharedPreferences(MonitorService.PREFS, Context.MODE_PRIVATE)
                .getBoolean(MonitorService.KEY_MONITOR_ENABLED, false)
            if (enabled) MonitorService.start(context)
        }
    }
}
