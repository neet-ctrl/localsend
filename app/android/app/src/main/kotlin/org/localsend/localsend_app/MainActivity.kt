package org.localsend.localsend_app

import android.annotation.SuppressLint
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel


private const val CHANNEL = "org.localsend.localsend_app/localsend"
private const val REQUEST_CODE_PICK_DIRECTORY = 1
private const val REQUEST_CODE_PICK_DIRECTORY_PATH = 2
private const val REQUEST_CODE_PICK_FILE = 3

private const val CALL_CHANNEL_ID   = "localsend_incoming_call"
private const val CALL_CHANNEL_NAME = "Incoming Calls"
private const val INCOMING_CALL_NOTIFICATION_ID = 1002

private const val CHAT_CHANNEL_ID   = "localsend_chat"
private const val CHAT_CHANNEL_NAME = "Chat Messages"
private const val CHAT_NOTIFICATION_ID = 1003

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var ringbackTone: ToneGenerator? = null
    private var methodChannel: MethodChannel? = null

    companion object {
        fun withNewEngine(): NewEngineIntentBuilder {
            return NewEngineIntentBuilder(MainActivity::class.java)
        }

        fun createDefaultIntent(launchContext: Context): Intent {
            return withNewEngine().build(launchContext)
        }
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        val cached = FlutterEngineCache.getInstance().get(HUB_ENGINE_ID)
        if (cached != null) return cached
        return super.provideFlutterEngine(context)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startHubService" -> {
                    HubForegroundService.start(applicationContext)
                    result.success(null)
                }

                "stopHubService" -> {
                    HubForegroundService.stop(applicationContext)
                    result.success(null)
                }

                "pickDirectory" -> {
                    pendingResult = result
                    openDirectoryPicker(onlyPath = false)
                }

                "pickFiles" -> {
                    pendingResult = result
                    openFilePicker()
                }

                "pickDirectoryPath" -> {
                    pendingResult = result
                    openDirectoryPicker(onlyPath = true)
                }

                "createDirectory" -> handleCreateDirectory(call, result)

                "openContentUri" -> {
                    openUri(context, call.argument<String>("uri")!!)
                    result.success(null)
                }

                "openGallery" -> {
                    openGallery()
                    result.success(null)
                }

                "isAnimationsEnabled" -> {
                    result.success(isAnimationsEnabled())
                }

                // ── Ringback tone (caller side) ─────────────────────────────
                "startRingback" -> {
                    try {
                        ringbackTone?.release()
                        ringbackTone = ToneGenerator(AudioManager.STREAM_VOICE_CALL, 80)
                        ringbackTone?.startTone(ToneGenerator.TONE_SUP_RINGTONE)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("TONE_ERROR", e.message, null)
                    }
                }

                "stopRingback" -> {
                    try {
                        ringbackTone?.stopTone()
                        ringbackTone?.release()
                        ringbackTone = null
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("TONE_ERROR", e.message, null)
                    }
                }

                // ── Call audio mode ──────────────────────────────────────────
                // MODE_IN_COMMUNICATION enables hardware AEC / NS and earpiece
                // routing that WebRTC requires.  Must be set BEFORE getUserMedia.
                // FLAG_KEEP_SCREEN_ON is toggled here so the screen stays on
                // during a call and turns off cleanly when it ends.
                "setCallAudioMode" -> {
                    try {
                        val active = call.argument<Boolean>("active") ?: false
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        if (active) {
                            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                            audioManager.isSpeakerphoneOn = false
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            audioManager.isSpeakerphoneOn = false
                            audioManager.mode = AudioManager.MODE_NORMAL
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("AUDIO_MODE_ERROR", e.message, null)
                    }
                }

                // ── Incoming call notification ───────────────────────────────
                // Shows a heads-up / full-screen notification so the user can
                // see who is calling and Accept or Decline without opening the
                // app manually.  On Android 10+ the full-screen intent also
                // wakes the screen and shows over the lock screen.
                "showIncomingCallNotification" -> {
                    try {
                        val callerName = call.argument<String>("callerName") ?: "Unknown"
                        val callType   = call.argument<String>("callType")   ?: "voice"
                        showIncomingCallNotification(callerName, callType)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("NOTIFICATION_ERROR", e.message, null)
                    }
                }

                "dismissCallNotification" -> {
                    try {
                        dismissCallNotification()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("NOTIFICATION_ERROR", e.message, null)
                    }
                }

                // ── Chat message notification ────────────────────────────────
                // Fires whenever a new Hub chat message arrives.  Shows a
                // standard IMPORTANCE_HIGH heads-up notification so the user
                // sees the message even when on another app or screen is locked.
                "showChatNotification" -> {
                    try {
                        val senderName = call.argument<String>("senderName") ?: "Unknown"
                        val message    = call.argument<String>("message")    ?: ""
                        showChatMessageNotification(senderName, message)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("NOTIFICATION_ERROR", e.message, null)
                    }
                }

                // ── Overlay permission (SYSTEM_ALERT_WINDOW) ─────────────────
                // Returns true/false whether the permission is already granted.
                "checkOverlayPermission" -> {
                    result.success(IncomingCallOverlay.canDrawOverlays(applicationContext))
                }

                // Opens the system Settings page where the user can grant the
                // "Display over other apps" permission.  Safe to call even if
                // already granted (settings page just shows the toggle as on).
                "requestOverlayPermission" -> {
                    try {
                        if (!IncomingCallOverlay.canDrawOverlays(applicationContext)) {
                            val intent = android.content.Intent(
                                android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                android.net.Uri.parse("package:$packageName"),
                            ).apply { addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK) }
                            startActivity(intent)
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("OVERLAY_ERROR", e.message, null)
                    }
                }

                // ── Overlay window ───────────────────────────────────────────
                // Shows a full-screen TYPE_APPLICATION_OVERLAY window on top of
                // every app (including lock screen) via SYSTEM_ALERT_WINDOW.
                "showCallOverlay" -> {
                    try {
                        val callerName = call.argument<String>("callerName") ?: "Unknown"
                        val callType   = call.argument<String>("callType")   ?: "voice"
                        IncomingCallOverlay.show(
                            applicationContext, callerName, callType,
                            onAccept = {
                                // Invoke directly back to Flutter (handler below)
                                methodChannel?.invokeMethod("notificationCallAction", "accept")
                            },
                            onDecline = {
                                methodChannel?.invokeMethod("notificationCallAction", "decline")
                            },
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("OVERLAY_ERROR", e.message, null)
                    }
                }

                "dismissCallOverlay" -> {
                    IncomingCallOverlay.dismiss()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        // Handle callAction that was delivered via intent BEFORE the engine
        // was ready (i.e. cold start from a notification tap).
        handleCallActionIntent(intent)
    }

    // ── onNewIntent: notification button tapped while app is already running ──
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleCallActionIntent(intent)
    }

    private fun handleCallActionIntent(intent: Intent?) {
        val action = intent?.getStringExtra("callAction") ?: return
        // Remove so we don't fire it again on the next resume
        intent.removeExtra("callAction")
        methodChannel?.invokeMethod("notificationCallAction", action)
    }

    // ── Incoming call notification helpers ────────────────────────────────────

    private fun createCallNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        if (nm.getNotificationChannel(CALL_CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CALL_CHANNEL_ID,
            CALL_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Incoming LocalSend voice and video calls"
            setShowBadge(true)
            enableVibration(true)
            enableLights(true)
        }
        nm.createNotificationChannel(channel)
    }

    private fun showIncomingCallNotification(callerName: String, callType: String) {
        createCallNotificationChannel()

        val nm = getSystemService(NotificationManager::class.java) ?: return

        // ── full-screen / heads-up intent → opens app ─────────────────────
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("callAction", "open")
        }
        val openPi = PendingIntent.getActivity(
            this, 10, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── Accept button ─────────────────────────────────────────────────
        val acceptIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("callAction", "accept")
        }
        val acceptPi = PendingIntent.getActivity(
            this, 11, acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── Decline button ────────────────────────────────────────────────
        val declineIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("callAction", "decline")
        }
        val declinePi = PendingIntent.getActivity(
            this, 12, declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = if (callType == "video") "Incoming Video Call" else "Incoming Voice Call"

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CALL_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle(title)
            .setContentText(callerName)
            .setContentIntent(openPi)
            .setFullScreenIntent(openPi, true)   // shows over lock screen / other apps
            .addAction(android.R.drawable.ic_menu_call,   "Accept",  acceptPi)
            .addAction(android.R.drawable.ic_menu_delete, "Decline", declinePi)
            .setOngoing(true)
            .setAutoCancel(false)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            builder.setCategory(Notification.CATEGORY_CALL)
        }

        nm.notify(INCOMING_CALL_NOTIFICATION_ID, builder.build())
    }

    private fun dismissCallNotification() {
        val nm = getSystemService(NotificationManager::class.java) ?: return
        nm.cancel(INCOMING_CALL_NOTIFICATION_ID)
    }

    // ── Chat notifications ────────────────────────────────────────────────────

    private fun createChatNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        if (nm.getNotificationChannel(CHAT_CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHAT_CHANNEL_ID,
            CHAT_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "LocalSend Hub chat messages"
            enableVibration(true)
        }
        nm.createNotificationChannel(channel)
    }

    private fun showChatMessageNotification(senderName: String, message: String) {
        createChatNotificationChannel()
        val nm = getSystemService(NotificationManager::class.java) ?: return

        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPi = PendingIntent.getActivity(
            this, 20, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHAT_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentTitle(senderName)
            .setContentText(message)
            .setContentIntent(openPi)
            .setAutoCancel(true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            builder.setCategory(Notification.CATEGORY_MESSAGE)
        }

        // Use a unique ID per sender so messages from different senders
        // don't overwrite each other.
        val notifId = CHAT_NOTIFICATION_ID + senderName.hashCode().and(0xFFFF)
        nm.notify(notifId, builder.build())
    }

    // ─────────────────────────────────────────────────────────────────────────

    private fun isAnimationsEnabled(): Boolean {
        return Settings.Global.getFloat(
            this.contentResolver,
            Settings.Global.ANIMATOR_DURATION_SCALE, 1.0f
        ) != 0.0f
    }

    private fun openDirectoryPicker(onlyPath: Boolean) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        startActivityForResult(
            intent,
            if (onlyPath) REQUEST_CODE_PICK_DIRECTORY_PATH else REQUEST_CODE_PICK_DIRECTORY
        )
    }

    private fun openFilePicker() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            putExtra("multi-pick", true)
            type = "*/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        startActivityForResult(intent, REQUEST_CODE_PICK_FILE)
    }

    @SuppressLint("WrongConstant")
    @Override
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode == Activity.RESULT_CANCELED) {
            pendingResult?.error("CANCELED", "Canceled", null)
            pendingResult = null
            return
        }

        if (resultCode != Activity.RESULT_OK || data == null) {
            pendingResult?.error("Error $resultCode", "Failed to access directory or file", null)
            pendingResult = null
            return
        }

        when (requestCode) {
            REQUEST_CODE_PICK_DIRECTORY -> {
                val uri: Uri? = data.data
                val takeFlags: Int =
                    data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                if (uri != null) {
                    contentResolver.takePersistableUriPermission(uri, takeFlags)

                    val files = mutableListOf<FileInfo>()
                    listFiles(uri, files)
                    val resultData = PickDirectoryResult(uri.toString(), files)
                    pendingResult?.success(resultData.toMap())
                    pendingResult = null
                } else {
                    pendingResult?.error("Error", "Failed to access directory", null)
                    pendingResult = null
                }
            }

            REQUEST_CODE_PICK_DIRECTORY_PATH -> {
                val uri: Uri? = data.data
                val takeFlags: Int =
                    data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                if (uri != null) {
                    contentResolver.takePersistableUriPermission(uri, takeFlags)
                    pendingResult?.success(uri.toString())
                    pendingResult = null
                } else {
                    pendingResult?.error("Error", "Failed to access directory", null)
                    pendingResult = null
                }
            }

            REQUEST_CODE_PICK_FILE -> {
                val uriList: List<Uri> = when {
                    data.clipData != null -> {
                        val clipData = data.clipData
                        val uris = mutableListOf<Uri>()
                        for (i in 0 until clipData!!.itemCount) {
                            uris.add(clipData.getItemAt(i).uri)
                        }
                        uris
                    }

                    data.data != null -> listOf(data.data!!)
                    else -> {
                        pendingResult?.error("Error", "Failed to access file", null)
                        return
                    }
                }

                val takeFlags: Int =
                    data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)

                val resultList = mutableListOf<FileInfo>()
                for (uri in uriList) {
                    contentResolver.takePersistableUriPermission(uri, takeFlags)
                    val documentFile = FastDocumentFile.fromDocumentUri(this, uri)
                    if (documentFile == null) {
                        pendingResult?.error("Error", "Failed to access file", null)
                        return
                    }
                    resultList.add(
                        FileInfo(
                            name = documentFile.name,
                            size = documentFile.size,
                            uri = uri.toString(),
                            lastModified = documentFile.lastModified,
                        )
                    )
                }

                pendingResult?.success(resultList.map { it.toMap() })
                pendingResult = null
            }
        }
    }

    private fun listFiles(uri: Uri, files: MutableList<FileInfo>) {
        val pickedDir: FastDocumentFile = FastDocumentFile.fromTreeUri(this, uri)

        for (file in pickedDir.listFiles()) {
            if (file.isDirectory) {
                listFiles(file.uri, files)
            } else if (file.isFile) {
                files.add(
                    FileInfo(
                        name = file.name,
                        size = file.size,
                        uri = file.uri.toString(),
                        lastModified = file.lastModified,
                    ),
                )
            }
        }
    }

    @SuppressLint("WrongConstant")
    private fun handleCreateDirectory(call: MethodCall, result: MethodChannel.Result) {
        val documentUri = Uri.parse(call.argument<String>("documentUri")!!)
        val directoryName = call.argument<String>("directoryName")!!

        if (folderExists(documentUri, directoryName)) {
            result.success(null)
            return
        }

        DocumentsContract.createDocument(
            context.contentResolver, documentUri, DocumentsContract.Document.MIME_TYPE_DIR,
            directoryName
        )

        result.success(null)
    }

    private fun folderExists(documentUri: Uri, folderName: String): Boolean {
        var cursor: Cursor? = null
        try {
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
                documentUri, DocumentsContract.getDocumentId(documentUri)
            )
            cursor = contentResolver.query(
                childrenUri,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE
                ),
                null, null, null,
            )

            if (cursor != null) {
                while (cursor.moveToNext()) {
                    val displayName = cursor.getString(0)
                    val mimeType = cursor.getString(1)
                    if (folderName == displayName && DocumentsContract.Document.MIME_TYPE_DIR == mimeType) {
                        return true
                    }
                }
            }
        } finally {
            cursor?.close()
        }
        return false
    }

    private fun openGallery() {
        val intent = Intent()
        intent.action = Intent.ACTION_VIEW
        intent.type = "image/*"
        startActivity(intent)
    }
}

data class PickDirectoryResult(
    val directoryUri: String,
    val files: List<FileInfo>,
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "directoryUri" to directoryUri,
            "files" to files.map { it.toMap() }
        )
    }
}

data class FileInfo(
    val name: String,
    val size: Long,
    val uri: String,
    val lastModified: Long
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "name" to name,
            "size" to size,
            "uri" to uri,
            "lastModified" to lastModified
        )
    }
}
