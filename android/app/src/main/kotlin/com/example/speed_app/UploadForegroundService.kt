package com.example.speed_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * 上传守护前台服务：上传期间让应用进程保持前台优先级，
 * 锁屏 / 后台时网络不会被系统挂起。
 */
class UploadForegroundService : Service() {
    companion object {
        const val SERVICE_NOTIFICATION_ID = 120002
        private const val CHANNEL_ID = "cloudreve_upload_service"

        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val EXTRA_PERCENT = "percent"

        fun start(context: Context, title: String, text: String, percent: Int) {
            try {
                val intent = Intent(context, UploadForegroundService::class.java)
                    .putExtra(EXTRA_TITLE, title)
                    .putExtra(EXTRA_TEXT, text)
                    .putExtra(EXTRA_PERCENT, percent)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (_: Exception) {
                // 系统限制后台启动前台服务时忽略：仍有 wakelock，
                // 回到前台后会自动重试失败任务。
            }
        }

        fun update(context: Context, title: String, text: String, percent: Int) {
            try {
                NotificationManagerCompat.from(context)
                    .notify(
                        SERVICE_NOTIFICATION_ID,
                        buildNotification(context, title, text, percent),
                    )
            } catch (_: Exception) {
                // 无通知权限 / 系统限制时忽略。
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, UploadForegroundService::class.java))
        }

        private fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val manager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "上传任务",
                    NotificationManager.IMPORTANCE_LOW,
                )
                manager.createNotificationChannel(channel)
            }
        }

        private fun buildNotification(
            context: Context,
            title: String,
            text: String,
            percent: Int,
        ): Notification {
            ensureChannel(context)
            val launch = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
            launch?.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            launch?.putExtra("open_uploads", true)
            val pending = PendingIntent.getActivity(
                context,
                SERVICE_NOTIFICATION_ID,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(text)
                .setProgress(100, percent.coerceIn(0, 100), false)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(pending)
                .build()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "上传中"
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: ""
        val percent = intent?.getIntExtra(EXTRA_PERCENT, 0) ?: 0
        startForeground(
            SERVICE_NOTIFICATION_ID,
            buildNotification(this, title, text, percent),
        )
        return START_STICKY
    }

    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(Service.STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }
}