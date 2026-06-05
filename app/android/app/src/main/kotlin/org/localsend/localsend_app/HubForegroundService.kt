package org.localsend.localsend_app

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

private const val SVC_CHANNEL = "org.localsend.localsend_app/localsend"

const val HUB_ENGINE_ID = "localsend_hub_bg_engine"
const val HUB_NOTIFICATION_ID = 1001
const val HUB_CHANNEL_ID = "localsend_hub_channel"

class HubForegroundService : Service() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                HUB_NOTIFICATION_ID,
                buildNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            )
        } else {
            startForeground(HUB_NOTIFICATION_ID, buildNotification())
        }
        ensureFlutterEngine()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        // Keep the engine alive for the activity to reuse; only remove on explicit stop
        super.onDestroy()
    }

    private fun ensureFlutterEngine() {
        val existing = FlutterEngineCache.getInstance().get(HUB_ENGINE_ID)
        if (existing != null && existing.dartExecutor.isExecutingDart) return

        val loader = FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) {
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
        }

        val engine = FlutterEngine(applicationContext)
        GeneratedPluginRegistrant.registerWith(engine)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "main")
        )
        FlutterEngineCache.getInstance().put(HUB_ENGINE_ID, engine)

        // Set up a MethodChannel handler for overlay and permission calls so
        // they work even when MainActivity is not running (app fully backgrounded).
        // When MainActivity becomes active it overrides this handler with its own.
        setupOverlayChannel(engine)
    }

    /**
     * Registers a lightweight MethodChannel handler on the Flutter engine so
     * that overlay calls (showCallOverlay / dismissCallOverlay / permission
     * checks) work even when MainActivity is not in the foreground.
     *
     * MainActivity's configureFlutterEngine() sets its own handler which
     * overrides this one while the Activity is alive — that is intentional.
     */
    private fun setupOverlayChannel(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, SVC_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkOverlayPermission" -> {
                        result.success(IncomingCallOverlay.canDrawOverlays(applicationContext))
                    }

                    // Cannot open Settings from a Service — return quietly.
                    "requestOverlayPermission" -> result.success(null)

                    "showCallOverlay" -> {
                        val callerName = call.argument<String>("callerName") ?: "Unknown"
                        val callType   = call.argument<String>("callType")   ?: "voice"
                        IncomingCallOverlay.show(
                            applicationContext, callerName, callType,
                            onAccept = {
                                // Bring MainActivity to the front with the
                                // accept action — onNewIntent fires the call.
                                applicationContext.startActivity(
                                    Intent(applicationContext, MainActivity::class.java).apply {
                                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                                Intent.FLAG_ACTIVITY_SINGLE_TOP
                                        putExtra("callAction", "accept")
                                    }
                                )
                            },
                            onDecline = {
                                // Invoke back to Dart on this engine directly.
                                MethodChannel(
                                    engine.dartExecutor.binaryMessenger, SVC_CHANNEL
                                ).invokeMethod("notificationCallAction", "decline")
                            },
                        )
                        result.success(null)
                    }

                    "dismissCallOverlay" -> {
                        IncomingCallOverlay.dismiss()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                HUB_CHANNEL_ID,
                "LocalSend Hub",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps LocalSend Hub active for LAN communication"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, HUB_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("LocalSend Hub Active")
            .setContentText("Discoverable on LAN — ready for calls, chat & files")
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .setContentIntent(openIntent)
            .setOngoing(true)
            .build()
    }

    companion object {
        fun start(context: Context) {
            val intent = Intent(context, HubForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, HubForegroundService::class.java))
        }
    }
}
