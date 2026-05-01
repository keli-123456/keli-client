package com.keli.keli_client

import android.content.Intent
import android.net.VpnService

class KeliVpnService : VpnService() {
    companion object {
        const val ACTION_START = "com.keli.keli_client.START_VPN"
        const val ACTION_STOP = "com.keli.keli_client.STOP_VPN"
        const val EXTRA_CONFIG = "config"
        const val EXTRA_NODE_NAME = "node_name"
        const val PREFS = "keli_vpn"
        const val KEY_RUNNING = "running"
        const val KEY_STATUS = "status"
        const val KEY_MESSAGE = "message"
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        if (intent?.action == ACTION_START) {
            val nodeName = intent.getStringExtra(EXTRA_NODE_NAME).orEmpty()
            getSharedPreferences(PREFS, MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_RUNNING, false)
                .putString(KEY_STATUS, "waiting-core")
                .putString(
                    KEY_MESSAGE,
                    "VPN permission is ready for $nodeName; sing-box Android runner is not bound yet"
                )
                .apply()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        getSharedPreferences(PREFS, MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_RUNNING, false)
            .putString(KEY_STATUS, "stopped")
            .putString(KEY_MESSAGE, "Android VPN service stopped")
            .apply()
        super.onDestroy()
    }
}
