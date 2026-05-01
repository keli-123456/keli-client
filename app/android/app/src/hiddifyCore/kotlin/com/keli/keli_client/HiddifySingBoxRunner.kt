package com.keli.keli_client

import android.net.IpPrefix
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.system.OsConstants
import android.util.Base64
import com.hiddify.core.libbox.CommandServer
import com.hiddify.core.libbox.CommandServerHandler
import com.hiddify.core.libbox.ConnectionOwner
import com.hiddify.core.libbox.InterfaceUpdateListener
import com.hiddify.core.libbox.Libbox
import com.hiddify.core.libbox.LocalDNSTransport
import com.hiddify.core.libbox.NetworkInterfaceIterator
import com.hiddify.core.libbox.Notification
import com.hiddify.core.libbox.OverrideOptions
import com.hiddify.core.libbox.PlatformInterface
import com.hiddify.core.libbox.RoutePrefix
import com.hiddify.core.libbox.RoutePrefixIterator
import com.hiddify.core.libbox.SetupOptions
import com.hiddify.core.libbox.StringIterator
import com.hiddify.core.libbox.SystemProxyStatus
import com.hiddify.core.libbox.TunOptions
import com.hiddify.core.libbox.WIFIState
import java.io.File
import java.net.Inet6Address
import java.net.InetAddress
import java.net.InterfaceAddress
import java.security.KeyStore
import java.util.Locale
import com.hiddify.core.libbox.NetworkInterface as LibboxNetworkInterface

class HiddifySingBoxRunner(
    private val service: KeliVpnService
) : KeliSingBoxRunner, CommandServerHandler, PlatformInterface {
    private var commandServer: CommandServer? = null
    private var tunDescriptor: ParcelFileDescriptor? = null
    private var currentConfig: String = ""
    private var currentNodeName: String = ""
    private var running: Boolean = false
    private var lastMessage: String = "idle"

    override fun start(config: String, nodeName: String) {
        if (config.isBlank()) {
            error("Android sing-box config is empty")
        }
        initializeLibbox()
        currentConfig = config
        currentNodeName = nodeName
        val server = commandServer ?: CommandServer(this, this).also {
            it.start()
            commandServer = it
        }
        server.startOrReloadService(config, OverrideOptions().apply {
            autoRedirect = false
        })
        running = true
        lastMessage = "sing-box started for $nodeName"
    }

    override fun stop() {
        running = false
        lastMessage = "sing-box stopped"
        runCatching { tunDescriptor?.close() }
        tunDescriptor = null
        runCatching { commandServer?.closeService() }
        runCatching { commandServer?.close() }
        commandServer = null
    }

    override fun status(): KeliSingBoxRunnerStatus {
        return KeliSingBoxRunnerStatus(
            running = running,
            status = if (running) "running" else "stopped",
            message = lastMessage
        )
    }

    override fun serviceStop() {
        stop()
    }

    override fun serviceReload() {
        val config = currentConfig
        if (config.isNotBlank()) {
            commandServer?.startOrReloadService(config, OverrideOptions().apply {
                autoRedirect = false
            })
        }
    }

    override fun getSystemProxyStatus(): SystemProxyStatus {
        return SystemProxyStatus().apply {
            available = false
            enabled = false
        }
    }

    override fun setSystemProxyEnabled(isEnabled: Boolean) {
        serviceReload()
    }

    override fun writeDebugMessage(message: String?) {
        lastMessage = message ?: lastMessage
    }

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun autoDetectInterfaceControl(fd: Int) {
        service.protect(fd)
    }

    override fun openTun(options: TunOptions): Int {
        if (VpnService.prepare(service) != null) {
            error("android: missing vpn permission")
        }

        val builder = service.Builder()
            .setSession("Keli Client")
            .setMtu(options.getMTU())

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        for (address in collectPrefixes(options.getInet4Address())) {
            builder.addAddress(address.address(), address.prefix())
        }
        for (address in collectPrefixes(options.getInet6Address())) {
            builder.addAddress(address.address(), address.prefix())
        }

        if (options.getAutoRoute()) {
            options.getDNSServerAddress()?.value?.takeIf { it.isNotBlank() }?.let {
                builder.addDnsServer(it)
            }
            configureRoutes(builder, options)
        }

        runCatching { builder.addDisallowedApplication(service.packageName) }

        if (options.isHTTPProxyEnabled() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setHttpProxy(
                ProxyInfo.buildDirectProxy(
                    options.getHTTPProxyServer(),
                    options.getHTTPProxyServerPort(),
                    collectStrings(options.getHTTPProxyBypassDomain())
                )
            )
        }

        val descriptor = builder.establish()
            ?: error("android: the application is not prepared or VPN was revoked")
        tunDescriptor = descriptor
        return descriptor.fd
    }

    override fun useProcFS(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destinationAddress: String,
        destinationPort: Int
    ): ConnectionOwner {
        return ConnectionOwner().apply {
            userId = 0
            userName = ""
            androidPackageName = ""
        }
    }

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) = Unit

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) = Unit

    override fun getInterfaces(): NetworkInterfaceIterator {
        val interfaces = java.net.NetworkInterface.getNetworkInterfaces()
            ?.toList()
            .orEmpty()
            .filter { !it.isLoopback }
            .map { networkInterface ->
                LibboxNetworkInterface().apply {
                    name = networkInterface.name
                    index = networkInterface.index
                    type = Libbox.InterfaceTypeOther
                    metered = false
                    runCatching { mtu = networkInterface.mtu }
                    addresses = StringArray(
                        networkInterface.interfaceAddresses
                            .mapNotNull { it.toPrefix() }
                            .iterator()
                    )
                    flags = runCatching {
                        if (networkInterface.isUp) {
                            OsConstants.IFF_UP or OsConstants.IFF_RUNNING
                        } else {
                            0
                        }
                    }.getOrDefault(0)
                    dnsServer = StringArray(emptyList<String>().iterator())
                }
            }
        return InterfaceArray(interfaces.iterator())
    }

    override fun underNetworkExtension(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun clearDNSCache() = Unit

    override fun readWIFIState(): WIFIState? = null

    override fun localDNSTransport(): LocalDNSTransport? = null

    override fun systemCertificates(): StringIterator {
        val certificates = mutableListOf<String>()
        runCatching {
            val keyStore = KeyStore.getInstance("AndroidCAStore")
            keyStore.load(null, null)
            val aliases = keyStore.aliases()
            while (aliases.hasMoreElements()) {
                val cert = keyStore.getCertificate(aliases.nextElement())
                certificates.add(
                    "-----BEGIN CERTIFICATE-----\n" +
                        Base64.encodeToString(cert.encoded, Base64.NO_WRAP) +
                        "\n-----END CERTIFICATE-----"
                )
            }
        }
        return StringArray(certificates.iterator())
    }

    override fun sendNotification(notification: Notification) {
        lastMessage = notification.body ?: notification.title ?: lastMessage
    }

    private fun initializeLibbox() {
        val baseDir = service.filesDir.also { it.mkdirs() }
        val workingDir = (service.getExternalFilesDir(null) ?: baseDir).also { it.mkdirs() }
        val tempDir = service.cacheDir.also { it.mkdirs() }
        Libbox.setLocale(Locale.getDefault().toLanguageTag().replace("-", "_"))
        Libbox.setup(
            SetupOptions().apply {
                basePath = baseDir.path
                workingPath = workingDir.path
                tempPath = tempDir.path
                fixAndroidStack = true
                logMaxLines = 1200
                debug = false
            }
        )
        Libbox.redirectStderr(File(workingDir, "sing-box-stderr.log").path)
    }

    private fun configureRoutes(builder: VpnService.Builder, options: TunOptions) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val inet4Routes = collectPrefixes(options.getInet4RouteAddress())
            if (inet4Routes.isNotEmpty()) {
                inet4Routes.forEach { builder.addRoute(it.toIpPrefix()) }
            } else if (collectPrefixes(options.getInet4Address()).isNotEmpty()) {
                builder.addRoute("0.0.0.0", 0)
            }

            val inet6Routes = collectPrefixes(options.getInet6RouteAddress())
            if (inet6Routes.isNotEmpty()) {
                inet6Routes.forEach { builder.addRoute(it.toIpPrefix()) }
            } else if (collectPrefixes(options.getInet6Address()).isNotEmpty()) {
                builder.addRoute("::", 0)
            }

            collectPrefixes(options.getInet4RouteExcludeAddress()).forEach {
                builder.excludeRoute(it.toIpPrefix())
            }
            collectPrefixes(options.getInet6RouteExcludeAddress()).forEach {
                builder.excludeRoute(it.toIpPrefix())
            }
            return
        }

        collectPrefixes(options.getInet4RouteRange()).forEach {
            builder.addRoute(it.address(), it.prefix())
        }
        collectPrefixes(options.getInet6RouteRange()).forEach {
            builder.addRoute(it.address(), it.prefix())
        }
    }

    private fun collectPrefixes(iterator: RoutePrefixIterator): List<RoutePrefix> {
        val values = mutableListOf<RoutePrefix>()
        while (iterator.hasNext()) {
            values.add(iterator.next())
        }
        return values
    }

    private fun collectStrings(iterator: StringIterator): List<String> {
        val values = mutableListOf<String>()
        while (iterator.hasNext()) {
            values.add(iterator.next())
        }
        return values
    }

    private fun RoutePrefix.toIpPrefix(): IpPrefix {
        return IpPrefix(InetAddress.getByName(address()), prefix())
    }

    private fun InterfaceAddress.toPrefix(): String? {
        val host = if (address is Inet6Address) {
            Inet6Address.getByAddress(address.address).hostAddress
        } else {
            address.hostAddress
        }
        return host?.let { "$it/$networkPrefixLength" }
    }

    private class InterfaceArray(
        private val iterator: Iterator<LibboxNetworkInterface>
    ) : NetworkInterfaceIterator {
        override fun hasNext(): Boolean = iterator.hasNext()
        override fun next(): LibboxNetworkInterface = iterator.next()
    }

    private class StringArray(
        private val iterator: Iterator<String>
    ) : StringIterator {
        override fun len(): Int = 0
        override fun hasNext(): Boolean = iterator.hasNext()
        override fun next(): String = iterator.next()
    }
}
