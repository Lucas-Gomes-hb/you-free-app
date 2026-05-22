package com.example.youfree

import android.app.PendingIntent
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.graphics.Rect
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Rational
import android.app.PictureInPictureParams
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    private var pipChannel: MethodChannel? = null
    private var isPlaying = false

    companion object {
        private const val ACTION_PIP_CONTROL = "com.example.youfree.pip.CONTROL"
        private const val EXTRA_CONTROL_TYPE = "control_type"
        private const val CONTROL_PLAY_PAUSE = 1
    }

    private val pipActionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != ACTION_PIP_CONTROL) return
            if (intent.getIntExtra(EXTRA_CONTROL_TYPE, -1) == CONTROL_PLAY_PAUSE) {
                // Delegate entirely to Flutter — don't flip local state here to avoid desync
                pipChannel?.invokeMethod("pipPlayPause", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.youfree/pip")
        pipChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        @Suppress("UNCHECKED_CAST")
                        enterPip(call.arguments as? Map<String, Int>)
                        result.success(null)
                    } else {
                        result.error("UNSUPPORTED", "PiP requires Android 8+", null)
                    }
                }
                "updatePipState" -> {
                    isPlaying = call.arguments as? Boolean ?: false
                    // Always update params — isInPictureInPictureMode may be false while the
                    // notification shade is open as an overlay, so we can't gate on it.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) updatePipParams()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun buildPipActions(): List<RemoteAction> {
        val intent = Intent(ACTION_PIP_CONTROL).apply {
            setPackage(packageName)
            putExtra(EXTRA_CONTROL_TYPE, CONTROL_PLAY_PAUSE)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this, CONTROL_PLAY_PAUSE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val iconRes = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        val title = if (isPlaying) "Pausar" else "Reproduzir"
        return listOf(RemoteAction(Icon.createWithResource(this, iconRes), title, title, pendingIntent))
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun updatePipParams() {
        setPictureInPictureParams(
            PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .setActions(buildPipActions())
                .build()
        )
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun enterPip(bounds: Map<String, Int>?) {
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
            .setActions(buildPipActions())
        if (bounds != null) {
            builder.setSourceRectHint(Rect(
                bounds["left"] ?: 0, bounds["top"] ?: 0,
                bounds["right"] ?: 0, bounds["bottom"] ?: 0,
            ))
        }
        enterPictureInPictureMode(builder.build())
    }

    override fun onResume() {
        super.onResume()
        // onPictureInPictureModeChanged sets exitingPip = true; onResume fires when expanded
        if (exitingPip) {
            exitingPip = false
            pipChannel?.invokeMethod("pipExpanded", null)
        }
    }

    private var exitingPip = false

    override fun onStart() {
        super.onStart()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(pipActionReceiver, IntentFilter(ACTION_PIP_CONTROL), RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(pipActionReceiver, IntentFilter(ACTION_PIP_CONTROL))
        }
    }

    override fun onStop() {
        super.onStop()
        try { unregisterReceiver(pipActionReceiver) } catch (_: Exception) {}
    }

    override fun onPictureInPictureModeChanged(isInPipMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPipMode, newConfig)
        if (!isInPipMode) exitingPip = true
        pipChannel?.invokeMethod("pipModeChanged", isInPipMode)
    }
}
