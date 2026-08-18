package com.example.speed_app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "cloudreve/download_notifications"
        private const val UPLOAD_CHANNEL = "cloudreve/upload_notifications"
        private const val APP_EVENTS_CHANNEL = "cloudreve/app_events"
        private const val NOTIFICATION_CHANNEL_ID = "cloudreve_downloads"
        private const val UPLOAD_NOTIFICATION_CHANNEL_ID = "cloudreve_uploads"
        private const val PERMISSION_REQUEST_CODE = 4201
        private const val EXTRA_OPEN_DOWNLOADS = "open_downloads"
        private const val EXTRA_OPEN_UPLOADS = "open_uploads"
    }

    private var permissionRequested = false
    private var pendingOpenDownloads = false
    private var appEventsChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 冷启动：通知点击带来的导航请求先缓存，等 Dart 主动领取。
        if (intent?.getBooleanExtra(EXTRA_OPEN_DOWNLOADS, false) == true) {
            pendingOpenDownloads = true
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // App 已运行：直接通知 Dart 切换页面。
        if (intent.getBooleanExtra(EXTRA_OPEN_DOWNLOADS, false)) {
            appEventsChannel?.invokeMethod("open_downloads", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        val id = call.argument<Int>("id") ?: 0
                        val title = call.argument<String>("title") ?: "下载"
                        val text = call.argument<String>("text") ?: ""
                        val percent = call.argument<Int>("percent") ?: 0
                        showProgress(id, title, text, percent)
                        result.success(null)
                    }
                    "finish" -> {
                        val id = call.argument<Int>("id") ?: 0
                        val title = call.argument<String>("title") ?: "下载"
                        val text = call.argument<String>("text") ?: ""
                        finish(id, title, text)
                        result.success(null)
                    }
                    "cancel" -> {
                        val id = call.argument<Int>("id") ?: 0
                        NotificationManagerCompat.from(this).cancel(id)
                        result.success(null)
                    }
                    "startService" -> {
                        val title = call.argument<String>("title") ?: "下载中"
                        val text = call.argument<String>("text") ?: ""
                        val percent = call.argument<Int>("percent") ?: 0
                        DownloadForegroundService.start(this, title, text, percent)
                        result.success(null)
                    }
                    "updateService" -> {
                        val title = call.argument<String>("title") ?: "下载中"
                        val text = call.argument<String>("text") ?: ""
                        val percent = call.argument<Int>("percent") ?: 0
                        DownloadForegroundService.update(this, title, text, percent)
                        result.success(null)
                    }
                    "stopService" -> {
                        DownloadForegroundService.stop(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPLOAD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        val id = call.argument<Int>("id") ?: 0
                        val title = call.argument<String>("title") ?: "上传"
                        val text = call.argument<String>("text") ?: ""
                        val percent = call.argument<Int>("percent") ?: 0
                        showUploadProgress(id, title, text, percent)
                        result.success(null)
                    }
                    "finish" -> {
                        val id = call.argument<Int>("id") ?: 0
                        val title = call.argument<String>("title") ?: "上传"
                        val text = call.argument<String>("text") ?: ""
                        finishUpload(id, title, text)
                        result.success(null)
                    }
                    "cancel" -> {
                        val id = call.argument<Int>("id") ?: 0
                        NotificationManagerCompat.from(this).cancel(id)
                        result.success(null)
                    }
                    "startService" -> {
                        val title = call.argument<String>("title") ?: "上传中"
                        val text = call.argument<String>("text") ?: ""
                        val percent = call.argument<Int>("percent") ?: 0
                        requestPermissionIfNeeded()
                        UploadForegroundService.start(this, title, text, percent)
                        result.success(null)
                    }
                    "updateService" -> {
                        val title = call.argument<String>("title") ?: "上传中"
                        val text = call.argument<String>("text") ?: ""
                        val percent = call.argument<Int>("percent") ?: 0
                        UploadForegroundService.update(this, title, text, percent)
                        result.success(null)
                    }
                    "stopService" -> {
                        UploadForegroundService.stop(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        appEventsChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_EVENTS_CHANNEL)
        appEventsChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingEvent" -> {
                    val pending =
                        if (pendingOpenDownloads) {
                            pendingOpenDownloads = false
                            "open_downloads"
                        } else {
                            null
                        }
                    result.success(pending)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "下载任务",
                NotificationManager.IMPORTANCE_LOW,
            )
            manager.createNotificationChannel(channel)
        }
    }

    private fun canNotify(): Boolean {
        return Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= 33 &&
            !permissionRequested &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            permissionRequested = true
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                PERMISSION_REQUEST_CODE,
            )
        }
    }

    private fun contentIntent(id: Int): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        // 点击通知后由 Dart 侧切换到下载页（事件名与具体页面解耦）。
        intent.putExtra(EXTRA_OPEN_DOWNLOADS, true)
        return PendingIntent.getActivity(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun showProgress(id: Int, title: String, text: String, percent: Int) {
        if (!canNotify()) {
            requestPermissionIfNeeded()
            return
        }
        ensureChannel()
        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setProgress(100, percent.coerceIn(0, 100), false)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(contentIntent(id))
        NotificationManagerCompat.from(this).notify(id, builder.build())
    }

    private fun finish(id: Int, title: String, text: String) {
        if (!canNotify()) return
        ensureChannel()
        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setProgress(0, 0, false)
            .setOngoing(false)
            .setAutoCancel(true)
            .setContentIntent(contentIntent(id))
        NotificationManagerCompat.from(this).notify(id, builder.build())
    }

    private fun ensureUploadChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                UPLOAD_NOTIFICATION_CHANNEL_ID,
                "上传任务",
                NotificationManager.IMPORTANCE_LOW,
            )
            manager.createNotificationChannel(channel)
        }
    }

    private fun uploadContentIntent(id: Int): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        intent.putExtra(EXTRA_OPEN_UPLOADS, true)
        return PendingIntent.getActivity(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun showUploadProgress(id: Int, title: String, text: String, percent: Int) {
        if (!canNotify()) {
            requestPermissionIfNeeded()
            return
        }
        ensureUploadChannel()
        val builder = NotificationCompat.Builder(this, UPLOAD_NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setProgress(100, percent.coerceIn(0, 100), false)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(uploadContentIntent(id))
        NotificationManagerCompat.from(this).notify(id, builder.build())
    }

    private fun finishUpload(id: Int, title: String, text: String) {
        if (!canNotify()) return
        ensureUploadChannel()
        val builder = NotificationCompat.Builder(this, UPLOAD_NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setProgress(0, 0, false)
            .setOngoing(false)
            .setAutoCancel(true)
            .setContentIntent(uploadContentIntent(id))
        NotificationManagerCompat.from(this).notify(id, builder.build())
    }
}
