package com.keli.keli_client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build

class KeliVpnService : VpnService() {
    companion object {
        const val ACTION_START = "com.keli.keli_client.START_VPN"
        const val ACTION_STOP = "com.keli.keli_client.STOP_VPN"
        const val EXTRA_CONFIG = "config"
        const val EXTRA_CONFIG_PATH = "config_path"
        const val EXTRA_NODE_NAME = "node_name"
        const val PREFS = "keli_vpn"
        const val KEY_CONFIG_PATH = "config_path"
        const val KEY_RUNNING = "running"
        const val KEY_STATUS = "status"
        const val KEY_MESSAGE = "message"

        private const val CHANNEL_ID = "keli_vpn"
        private const val NOTIFICATION_ID = 17021
    }

    private var runner: KeliSingBoxRunner? = null

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
        runner = KeliSingBoxRunnerFactory.create(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopVpn("stopped", "Android VPN stopped", finishSelf = true)
                return START_NOT_STICKY
            }

            ACTION_START -> {
                val nodeName = intent.getStringExtra(EXTRA_NODE_NAME).orEmpty()
                val config = resolveConfig(intent)
                startForeground(
                    NOTIFICATION_ID,
                    buildNotification("正在连接", nodeName.ifBlank { "Keli Client" })
                )
                startVpn(config, nodeName)
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopVpn("stopped", "Android VPN service stopped", finishSelf = false)
        super.onDestroy()
    }

    override fun onRevoke() {
        stopVpn("revoked", "Android VPN permission revoked", finishSelf = true)
        super.onRevoke()
    }

    private fun startVpn(config: String, nodeName: String) {
        updateStatus(running = false, status = "starting", message = "Starting $nodeName")
        try {
            val activeRunner = runner ?: KeliSingBoxRunnerFactory.create(this).also { runner = it }
            activeRunner.start(config, nodeName)
            updateStatus(running = true, status = "running", message = "Connected to $nodeName")
            val notification = buildNotification("已连接", nodeName.ifBlank { "Keli Client" })
            getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification)
        } catch (error: Throwable) {
            updateStatus(
                running = false,
                status = "error",
                message = error.message ?: error::class.java.simpleName
            )
            stopSelf()
        }
    }

    private fun stopVpn(status: String, message: String, finishSelf: Boolean) {
        runCatching { runner?.stop() }
        runner = null
        updateStatus(running = false, status = status, message = message)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        if (finishSelf) {
            stopSelf()
        }
    }

    private fun resolveConfig(intent: Intent): String {
        val directConfig = intent.getStringExtra(EXTRA_CONFIG)
        if (!directConfig.isNullOrBlank()) {
            return directConfig
        }
        val path = intent.getStringExtra(EXTRA_CONFIG_PATH)
            ?: getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY_CONFIG_PATH, null)
        if (!path.isNullOrBlank()) {
            return runCatching { java.io.File(path).readText() }.getOrDefault("")
        }
        return ""
    }

    private fun updateStatus(running: Boolean, status: String, message: String) {
        getSharedPreferences(PREFS, MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_RUNNING, running)
            .putString(KEY_STATUS, status)
            .putString(KEY_MESSAGE, message)
            .apply()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Keli VPN",
            NotificationManager.IMPORTANCE_LOW
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(title: String, body: String): Notification {
        val activityIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            activityIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
