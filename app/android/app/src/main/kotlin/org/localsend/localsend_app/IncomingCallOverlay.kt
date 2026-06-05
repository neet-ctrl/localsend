package org.localsend.localsend_app

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Full-screen incoming-call overlay that appears on top of every app and the
 * lock screen using TYPE_APPLICATION_OVERLAY + SYSTEM_ALERT_WINDOW permission.
 *
 * Must be shown/dismissed on the main thread — call [show] and [dismiss] from
 * a MethodChannel handler (which runs on the main thread) or wrap in
 * Handler(Looper.getMainLooper()).post { ... }.
 */
object IncomingCallOverlay {

    private var windowManager: WindowManager? = null
    private var overlayRoot: View? = null
    private var onAcceptAction: (() -> Unit)? = null
    private var onDeclineAction: (() -> Unit)? = null

    // ── Permission check ──────────────────────────────────────────────────────

    fun canDrawOverlays(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                Settings.canDrawOverlays(context)

    // ── Show ──────────────────────────────────────────────────────────────────

    fun show(
        context: Context,
        callerName: String,
        callType: String,
        onAccept: () -> Unit,
        onDecline: () -> Unit,
    ) {
        if (!canDrawOverlays(context)) return

        // Always run on main thread
        Handler(Looper.getMainLooper()).post {
            // Dismiss any previous overlay first
            dismissInternal()

            onAcceptAction = onAccept
            onDeclineAction = onDecline

            val wm = context.applicationContext
                .getSystemService(Context.WINDOW_SERVICE) as WindowManager
            windowManager = wm

            val root = buildOverlayView(context.applicationContext, callerName, callType)
            overlayRoot = root

            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE

            @Suppress("DEPRECATION") // FLAG_SHOW_WHEN_LOCKED deprecated as Activity flag, still valid on WindowManager
            val flags =
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                type,
                flags,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.START
            }

            try {
                wm.addView(root, params)
            } catch (e: Exception) {
                overlayRoot = null
                windowManager = null
            }
        }
    }

    // ── Dismiss ───────────────────────────────────────────────────────────────

    fun dismiss() {
        Handler(Looper.getMainLooper()).post { dismissInternal() }
    }

    private fun dismissInternal() {
        try {
            overlayRoot?.let { windowManager?.removeView(it) }
        } catch (_: Exception) {
        }
        overlayRoot = null
        windowManager = null
        onAcceptAction = null
        onDeclineAction = null
    }

    // ── Build UI programmatically ─────────────────────────────────────────────

    private fun buildOverlayView(ctx: Context, callerName: String, callType: String): View {
        val isVideo = callType == "video"

        // Root — full screen dark navy with slight transparency
        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(Color.argb(245, 10, 16, 38))
        }

        // ── Top spacer ────────────────────────────────────────────────────────
        root.addView(View(ctx), LinearLayout.LayoutParams(1, 0).apply { weight = 1f })

        // ── Icon circle ───────────────────────────────────────────────────────
        val iconFrame = FrameLayout(ctx).apply {
            val size = dpToPx(ctx, 96)
            layoutParams = LinearLayout.LayoutParams(size, size)
            background = buildCircleDrawable(Color.parseColor("#1A2A5A"))
        }

        val icon = ImageView(ctx).apply {
            val res = if (isVideo)
                android.R.drawable.ic_menu_camera
            else
                android.R.drawable.ic_menu_call
            setImageResource(res)
            setColorFilter(Color.parseColor("#00BCD4"))
            val pad = dpToPx(ctx, 24)
            setPadding(pad, pad, pad, pad)
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
        }
        iconFrame.addView(icon)
        root.addView(iconFrame)

        // ── Call type label ───────────────────────────────────────────────────
        root.addView(TextView(ctx).apply {
            text = if (isVideo) "Incoming Video Call" else "Incoming Voice Call"
            textSize = 14f
            setTextColor(Color.parseColor("#00BCD4"))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dpToPx(ctx, 20) }
        })

        // ── Caller name ───────────────────────────────────────────────────────
        root.addView(TextView(ctx).apply {
            text = callerName
            textSize = 30f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setTypeface(null, Typeface.BOLD)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = dpToPx(ctx, 16)
                bottomMargin = dpToPx(ctx, 8)
                leftMargin = dpToPx(ctx, 32)
                rightMargin = dpToPx(ctx, 32)
            }
        })

        // ── "is calling you…" sub-text ────────────────────────────────────────
        root.addView(TextView(ctx).apply {
            text = "is calling you…"
            textSize = 14f
            setTextColor(Color.parseColor("#8899BB"))
            gravity = Gravity.CENTER
        })

        // ── Bottom spacer ─────────────────────────────────────────────────────
        root.addView(View(ctx), LinearLayout.LayoutParams(1, 0).apply { weight = 1.5f })

        // ── Action buttons ────────────────────────────────────────────────────
        val btnRow = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dpToPx(ctx, 72) }
        }

        btnRow.addView(buildRoundButton(ctx, "Decline", android.R.drawable.ic_menu_delete, Color.parseColor("#C62828")) {
            onDeclineAction?.invoke()
            dismissInternal()
        })

        // Gap between buttons
        btnRow.addView(View(ctx), LinearLayout.LayoutParams(dpToPx(ctx, 80), 1))

        btnRow.addView(buildRoundButton(ctx, "Accept",
            if (isVideo) android.R.drawable.ic_menu_camera else android.R.drawable.ic_menu_call,
            Color.parseColor("#2E7D32")) {
            onAcceptAction?.invoke()
            dismissInternal()
        })

        root.addView(btnRow)

        return root
    }

    private fun buildRoundButton(
        ctx: Context,
        label: String,
        iconRes: Int,
        bgColor: Int,
        onClick: () -> Unit,
    ): LinearLayout {
        val col = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }

        val size = dpToPx(ctx, 72)
        val circle = FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(size, size)
            background = buildCircleDrawable(bgColor)
            isClickable = true
            isFocusable = true
            setOnClickListener { onClick() }
        }

        val iv = ImageView(ctx).apply {
            setImageResource(iconRes)
            setColorFilter(Color.WHITE)
            val pad = dpToPx(ctx, 18)
            setPadding(pad, pad, pad, pad)
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
        }
        circle.addView(iv)
        col.addView(circle)

        col.addView(TextView(ctx).apply {
            text = label
            textSize = 12f
            setTextColor(Color.parseColor("#AABBCC"))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dpToPx(ctx, 10) }
        })

        return col
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun dpToPx(ctx: Context, dp: Int): Int =
        (dp * ctx.resources.displayMetrics.density + 0.5f).toInt()

    private fun buildCircleDrawable(color: Int): android.graphics.drawable.GradientDrawable =
        android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.OVAL
            setColor(color)
        }
}
