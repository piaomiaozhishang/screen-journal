package com.screenjournal.screen_time_journal

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Locale

/**
 * 达到每日限额时的全屏遮挡提醒。
 * 受 Android 限制无法直接关闭其他应用，采用“全屏遮挡 + 无障碍回到桌面”。
 */
class LimitOverlayActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureWindow()

        val appName = intent.getStringExtra("appName") ?: "该应用"
        val usedMs = intent.getLongExtra("usedMs", 0L)
        val limitMs = intent.getLongExtra("limitMs", 0L)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(72, 72, 72, 72)
            setBackgroundColor(Color.parseColor("#FDECEA"))
        }

        val icon = TextView(this).apply {
            text = "\uD83D\uDED1"
            textSize = 56f
            gravity = Gravity.CENTER
        }
        val title = TextView(this).apply {
            text = "今日使用已达限额"
            setTextColor(Color.parseColor("#C62828"))
            textSize = 24f
            gravity = Gravity.CENTER
            paint.isFakeBoldText = true
            setPadding(0, 40, 0, 16)
        }
        val sub = TextView(this).apply {
            text = appName
            setTextColor(Color.parseColor("#B71C1C"))
            textSize = 20f
            gravity = Gravity.CENTER
            paint.isFakeBoldText = true
        }
        val detail = TextView(this).apply {
            text = String.format(
                Locale.getDefault(),
                "今日已用 %d 分钟 / 限额 %d 分钟",
                usedMs / 60000, limitMs / 60000
            )
            setTextColor(Color.parseColor("#7F4A45"))
            textSize = 14f
            gravity = Gravity.CENTER
            setPadding(0, 16, 0, 48)
        }
        val btn = Button(this).apply {
            text = "回到桌面"
            textSize = 17f
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#C62828"))
            setPadding(48, 28, 48, 28)
            setOnClickListener { goHomeAndFinish() }
        }
        val hint = TextView(this).apply {
            text = "屏记 · 为你的专注保驾护航"
            setTextColor(Color.parseColor("#A06660"))
            textSize = 12f
            gravity = Gravity.CENTER
            setPadding(0, 40, 0, 0)
        }
        root.addView(icon)
        root.addView(title)
        root.addView(sub)
        root.addView(detail)
        root.addView(btn)
        root.addView(hint)
        setContentView(root)

        // 3 秒后自动尝试回到桌面
        Handler(Looper.getMainLooper()).postDelayed({ goHomeAndFinish() }, 3000)
    }

    private fun configureWindow() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION)
    }

    private fun goHomeAndFinish() {
        // 优先无障碍全局动作
        LimitAccessibilityService.instance?.goHome()
        // 兜底：标准桌面 Intent
        try {
            val home = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(home)
        } catch (_: Exception) { }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                finishAndRemoveTask()
            } else {
                finish()
            }
        } catch (_: Exception) {
            finish()
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // 禁止返回键绕过限额提醒
        goHomeAndFinish()
    }
}
