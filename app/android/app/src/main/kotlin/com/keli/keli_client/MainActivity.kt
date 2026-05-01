package com.keli.keli_client

import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.keli.keli_client/core"
        private const val VPN_PERMISSION_REQUEST = 4242
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepare" -> handlePrepare(result)
                    "applyConfig" -> handleApplyConfig(call, result)
                    "connect" -> handleConnect(call, result)
                    "disconnect" -> handleDisconnect(result)
                    "status" -> handleStatus(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun handlePrepare(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            startActivityForResult(intent, VPN_PERMISSION_REQUEST)
            result.success(
                mapOf(
                    "prepared" to false,
                    "permissionRequired" to true,
                    "message" to "Android VPN permission requested"
                )
            )
            return
        }
        result.success(mapOf("prepared" to true, "message" to "Android VPN ready"))
    }

    private fun handleApplyConfig(call: MethodCall, result: MethodChannel.Result) {
        val config = call.argument<String>("config").orEmpty()
        filesDir.resolve("keli-sing-box.json").writeText(config)
        getSharedPreferences(KeliVpnService.PREFS, MODE_PRIVATE)
            .edit()
            .putString(KeliVpnService.KEY_STATUS, "configured")
            .putString(KeliVpnService.KEY_MESSAGE, "Config accepted by Android bridge")
            .apply()
        result.success(mapOf("applied" to true, "message" to "Config accepted"))
    }

    private fun handleConnect(call: MethodCall, result: MethodChannel.Result) {
        val permissionIntent = VpnService.prepare(this)
        if (permissionIntent != null) {
            startActivityForResult(permissionIntent, VPN_PERMISSION_REQUEST)
            result.success(
                mapOf(
                    "connected" to false,
                    "prepared" to false,
                    "permissionRequired" to true,
                    "message" to "Android VPN permission requested"
                )
            )
            return
        }

        val config = call.argument<String>("config").orEmpty()
        val nodeName = call.argument<String>("node_name").orEmpty()
        val serviceIntent = Intent(this, KeliVpnService::class.java).apply {
            action = KeliVpnService.ACTION_START
            putExtra(KeliVpnService.EXTRA_CONFIG, config)
            putExtra(KeliVpnService.EXTRA_NODE_NAME, nodeName)
        }
        startService(serviceIntent)
        result.success(
            mapOf(
                "connected" to false,
                "prepared" to true,
                "message" to "Android VPNService bridge is ready; sing-box Android runner is not bound yet"
            )
        )
    }

    private fun handleDisconnect(result: MethodChannel.Result) {
        stopService(Intent(this, KeliVpnService::class.java))
        getSharedPreferences(KeliVpnService.PREFS, MODE_PRIVATE)
            .edit()
            .putString(KeliVpnService.KEY_STATUS, "stopped")
            .putString(KeliVpnService.KEY_MESSAGE, "Android VPN stopped")
            .apply()
        result.success(mapOf("stopped" to true, "message" to "Android VPN stopped"))
    }

    private fun handleStatus(result: MethodChannel.Result) {
        val prefs = getSharedPreferences(KeliVpnService.PREFS, MODE_PRIVATE)
        result.success(
            mapOf(
                "running" to prefs.getBoolean(KeliVpnService.KEY_RUNNING, false),
                "status" to prefs.getString(KeliVpnService.KEY_STATUS, "idle"),
                "message" to prefs.getString(KeliVpnService.KEY_MESSAGE, "Android bridge idle")
            )
        )
    }
}
