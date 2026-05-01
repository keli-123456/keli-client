package com.keli.keli_client

interface KeliSingBoxRunner {
    fun start(config: String, nodeName: String)
    fun stop()
    fun status(): KeliSingBoxRunnerStatus
}

data class KeliSingBoxRunnerStatus(
    val running: Boolean,
    val status: String,
    val message: String
)

object KeliSingBoxRunnerFactory {
    private const val HIDDIFY_RUNNER_CLASS = "com.keli.keli_client.HiddifySingBoxRunner"

    fun hasEmbeddedCore(): Boolean {
        return runCatching { Class.forName(HIDDIFY_RUNNER_CLASS) }.isSuccess
    }

    fun create(service: KeliVpnService): KeliSingBoxRunner {
        return runCatching {
            val runnerClass = Class.forName(HIDDIFY_RUNNER_CLASS)
            val constructor = runnerClass.getConstructor(KeliVpnService::class.java)
            constructor.newInstance(service) as KeliSingBoxRunner
        }.getOrElse { UnavailableSingBoxRunner }
    }
}

private object UnavailableSingBoxRunner : KeliSingBoxRunner {
    override fun start(config: String, nodeName: String) {
        error("Android sing-box core is missing. Put hiddify-core.aar in android/app/libs and rebuild.")
    }

    override fun stop() = Unit

    override fun status(): KeliSingBoxRunnerStatus {
        return KeliSingBoxRunnerStatus(
            running = false,
            status = "missing-core",
            message = "Android sing-box core AAR is not bundled"
        )
    }
}
