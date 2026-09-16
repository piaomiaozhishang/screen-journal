package com.screenjournal.screen_time_journal

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent

/**
 * 仅用于限额触发时执行“回到桌面”全局动作，不监听、不收集任何界面内容。
 * 无障碍服务一经启用即可执行 GLOBAL_ACTION_HOME，无需额外标志。
 */
class LimitAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        var instance: LimitAccessibilityService? = null
            private set
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 不处理任何事件
    }

    override fun onInterrupt() { }

    fun goHome(): Boolean = performGlobalAction(GLOBAL_ACTION_HOME)

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }
}
