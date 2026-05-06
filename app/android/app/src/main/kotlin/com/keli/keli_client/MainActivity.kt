package com.keli.keli_client

import android.content.Intent
import android.net.Uri
import android.net.VpnService
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CORE_CHANNEL = "com.keli.keli_client/core"
        private const val SESSION_CHANNEL = "com.keli.keli_client/session"
        private const val PLATFORM_CHANNEL = "com.keli.keli_client/platform"
        private const val VPN_PERMISSION_REQUEST = 4242
    }

    private val sessionSecretStore by lazy { SessionSecretStore() }
    private var pendingVpnPermission: PendingVpnPermission? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CORE_CHANNEL)
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SESSION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "protect" -> handleProtectSessionSecret(call, result)
                    "unprotect" -> handleUnprotectSessionSecret(call, result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLATFORM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openUrl" -> handleOpenUrl(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != VPN_PERMISSION_REQUEST) {
            return
        }

        val pending = pendingVpnPermission ?: return
        pendingVpnPermission = null
        if (VpnService.prepare(this) != null) {
            pending.result.success(
                mapOf(
                    "connected" to false,
                    "prepared" to false,
                    "permissionRequired" to true,
                    "message" to "Android VPN permission denied"
                )
            )
            return
        }

        when (pending) {
            is PendingVpnPermission.Prepare -> {
                pending.result.success(
                    mapOf(
                        "prepared" to true,
                        "message" to "Android VPN ready"
                    )
                )
            }
            is PendingVpnPermission.Connect -> {
                pending.result.success(startVpnService(pending.request))
            }
        }
    }

    private fun handleProtectSessionSecret(call: MethodCall, result: MethodChannel.Result) {
        try {
            result.success(sessionSecretStore.protect(call.argument<String>("value").orEmpty()))
        } catch (error: Throwable) {
            result.error("SESSION_PROTECT_FAILED", error.message, null)
        }
    }

    private fun handleUnprotectSessionSecret(call: MethodCall, result: MethodChannel.Result) {
        try {
            result.success(sessionSecretStore.unprotect(call.argument<String>("value").orEmpty()))
        } catch (error: Throwable) {
            result.error("SESSION_UNPROTECT_FAILED", error.message, null)
        }
    }

    private fun handlePrepare(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            pendingVpnPermission?.result?.success(
                mapOf(
                    "connected" to false,
                    "prepared" to false,
                    "permissionRequired" to true,
                    "message" to "Android VPN permission superseded by a new request"
                )
            )
            pendingVpnPermission = PendingVpnPermission.Prepare(result)
            startActivityForResult(intent, VPN_PERMISSION_REQUEST)
            return
        }
        result.success(mapOf("prepared" to true, "message" to "Android VPN ready"))
    }

    private fun handleApplyConfig(call: MethodCall, result: MethodChannel.Result) {
        val config = call.argument<String>("config").orEmpty()
        val configFile = filesDir.resolve("keli-sing-box.json")
        configFile.writeText(config)
        getSharedPreferences(KeliVpnService.PREFS, MODE_PRIVATE)
            .edit()
            .putString(KeliVpnService.KEY_CONFIG_PATH, configFile.path)
            .putBoolean(KeliVpnService.KEY_RUNNING, false)
            .putString(KeliVpnService.KEY_STATUS, "configured")
            .putString(KeliVpnService.KEY_MESSAGE, "Config accepted by Android bridge")
            .apply()
        result.success(
            mapOf(
                "applied" to true,
                "configPath" to configFile.path,
                "coreEmbedded" to KeliSingBoxRunnerFactory.hasEmbeddedCore(),
                "message" to "Config accepted"
            )
        )
    }

    private fun handleConnect(call: MethodCall, result: MethodChannel.Result) {
        val permissionIntent = VpnService.prepare(this)
        if (permissionIntent != null) {
            pendingVpnPermission?.result?.success(
                mapOf(
                    "connected" to false,
                    "prepared" to false,
                    "permissionRequired" to true,
                    "message" to "Android VPN permission superseded by a new request"
                )
            )
            pendingVpnPermission = PendingVpnPermission.Connect(readVpnStartRequest(call), result)
            startActivityForResult(permissionIntent, VPN_PERMISSION_REQUEST)
            return
        }

        result.success(startVpnService(readVpnStartRequest(call)))
    }

    private fun handleOpenUrl(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url").orEmpty().trim()
        if (url.isBlank()) {
            result.success(false)
            return
        }
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addCategory(Intent.CATEGORY_BROWSABLE)
            }
            startActivity(intent)
            result.success(true)
        } catch (_: Throwable) {
            result.success(false)
        }
    }

    private fun readVpnStartRequest(call: MethodCall): VpnStartRequest {
        val prefs = getSharedPreferences(KeliVpnService.PREFS, MODE_PRIVATE)
        return VpnStartRequest(
            config = call.argument<String>("config").orEmpty(),
            configPath = call.argument<String>("config_path")
                ?: prefs.getString(KeliVpnService.KEY_CONFIG_PATH, null),
            nodeName = call.argument<String>("node_name").orEmpty()
        )
    }

    private fun startVpnService(request: VpnStartRequest): Map<String, Any?> {
        val coreEmbedded = KeliSingBoxRunnerFactory.hasEmbeddedCore()
        if (!coreEmbedded) {
            updateBridgeStatus(
                running = false,
                status = "missing-core",
                message = "Android sing-box core is missing. Put hiddify-core.aar in android/app/libs and rebuild."
            )
            return mapOf(
                "connected" to false,
                "prepared" to true,
                "coreEmbedded" to false,
                "message" to "Android sing-box core is missing. Put hiddify-core.aar in android/app/libs and rebuild."
            )
        }

        val configReady = request.config.isNotBlank() || request.configPath?.let {
            runCatching { java.io.File(it).length() > 0 }.getOrDefault(false)
        } == true
        if (!configReady) {
            updateBridgeStatus(
                running = false,
                status = "config-error",
                message = "Android sing-box config is empty"
            )
            return mapOf(
                "connected" to false,
                "started" to false,
                "prepared" to true,
                "coreEmbedded" to true,
                "configReady" to false,
                "message" to "Android sing-box config is empty"
            )
        }

        val serviceIntent = Intent(this, KeliVpnService::class.java).apply {
            action = KeliVpnService.ACTION_START
            putExtra(KeliVpnService.EXTRA_CONFIG, request.config)
            putExtra(KeliVpnService.EXTRA_CONFIG_PATH, request.configPath)
            putExtra(KeliVpnService.EXTRA_NODE_NAME, request.nodeName)
        }
        updateBridgeStatus(
            running = false,
            status = "starting",
            message = "Starting ${request.nodeName.ifBlank { "Keli Client" }}"
        )
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        } catch (error: Throwable) {
            val message = error.message ?: error::class.java.simpleName
            updateBridgeStatus(running = false, status = "error", message = message)
            return mapOf(
                "connected" to false,
                "started" to false,
                "prepared" to true,
                "coreEmbedded" to true,
                "configReady" to true,
                "message" to message
            )
        }
        return mapOf(
            "connected" to false,
            "started" to true,
            "prepared" to true,
            "coreEmbedded" to true,
            "configReady" to true,
            "message" to "Android sing-box VPN service starting"
        )
    }

    private fun handleDisconnect(result: MethodChannel.Result) {
        val intent = Intent(this, KeliVpnService::class.java).apply {
            action = KeliVpnService.ACTION_STOP
        }
        startService(intent)
        getSharedPreferences(KeliVpnService.PREFS, MODE_PRIVATE)
            .edit()
            .putString(KeliVpnService.KEY_STATUS, "stopped")
            .putString(KeliVpnService.KEY_MESSAGE, "Android VPN stopped")
            .apply()
        result.success(mapOf("stopped" to true, "message" to "Android VPN stopped"))
    }

    private fun handleStatus(result: MethodChannel.Result) {
        val prefs = getSharedPreferences(KeliVpnService.PREFS, MODE_PRIVATE)
        val configPath = prefs.getString(KeliVpnService.KEY_CONFIG_PATH, null)
        val configFile = configPath?.let { java.io.File(it) }
        val vpnPrepared = VpnService.prepare(this) == null
        val coreEmbedded = KeliSingBoxRunnerFactory.hasEmbeddedCore()
        result.success(
            mapOf(
                "coreEmbedded" to coreEmbedded,
                "vpnPrepared" to vpnPrepared,
                "permissionRequired" to !vpnPrepared,
                "running" to prefs.getBoolean(KeliVpnService.KEY_RUNNING, false),
                "status" to prefs.getString(KeliVpnService.KEY_STATUS, "idle"),
                "message" to prefs.getString(KeliVpnService.KEY_MESSAGE, "Android bridge idle"),
                "configPath" to configPath,
                "configExists" to (configFile?.exists() == true),
                "configBytes" to (configFile?.length() ?: 0L),
                "supportsLatencyTesting" to false,
                "nodeName" to prefs.getString(KeliVpnService.KEY_NODE_NAME, "")
            )
        )
    }

    private fun updateBridgeStatus(running: Boolean, status: String, message: String) {
        getSharedPreferences(KeliVpnService.PREFS, MODE_PRIVATE)
            .edit()
            .putBoolean(KeliVpnService.KEY_RUNNING, running)
            .putString(KeliVpnService.KEY_STATUS, status)
            .putString(KeliVpnService.KEY_MESSAGE, message)
            .apply()
    }

    private data class VpnStartRequest(
        val config: String,
        val configPath: String?,
        val nodeName: String
    )

    private sealed class PendingVpnPermission {
        abstract val result: MethodChannel.Result

        data class Prepare(
            override val result: MethodChannel.Result
        ) : PendingVpnPermission()

        data class Connect(
            val request: VpnStartRequest,
            override val result: MethodChannel.Result
        ) : PendingVpnPermission()
    }
}
