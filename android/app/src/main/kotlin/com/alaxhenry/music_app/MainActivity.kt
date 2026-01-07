package com.alaxhenry.music_app

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.yourapp/music_control"
    private val EVENT_CHANNEL = "com.yourapp/music_events"
    private var eventSink: EventChannel.EventSink? = null

    private var mediaSessionManager: MediaSessionManager? = null
    private var activeController: MediaController? = null
    private val TAG = "MusicApp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Log.d(TAG, "🚀 Configuring Flutter engine")

        // Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNowPlayingInfo" -> {
                    Log.d(TAG, "📱 getNowPlayingInfo called")
                    val info = getNowPlayingInfo()
                    if (info != null) {
                        Log.d(TAG, "✅ Returning track info: ${info["title"]}")
                    } else {
                        Log.w(TAG, "⚠️ No track info available")
                    }
                    result.success(info)
                }
                "togglePlayPause" -> {
                    Log.d(TAG, "⏯️ togglePlayPause called")
                    togglePlayPause()
                    result.success(null)
                }
                "nextTrack" -> {
                    Log.d(TAG, "⏭️ nextTrack called")
                    nextTrack()
                    result.success(null)
                }
                "previousTrack" -> {
                    Log.d(TAG, "⏮️ previousTrack called")
                    previousTrack()
                    result.success(null)
                }
                "seek" -> {
                    val seconds = call.argument<Double>("seconds")
                    if (seconds != null) {
                        seek((seconds * 1000).toLong())
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "seconds is required", null)
                    }
                }
                "setPlaybackSpeed" -> {
                    val speed = call.argument<Double>("speed")
                    if (speed != null) {
                        val success = setPlaybackSpeed(speed.toFloat())
                        if (success) {
                            result.success(true)
                        } else {
                            result.error("UNSUPPORTED", "setPlaybackSpeed not supported", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "speed is required", null)
                    }
                }
                "checkNotificationPermission" -> {
                    val hasPermission = isNotificationListenerEnabled()
                    Log.d(TAG, "🔐 Permission check: $hasPermission")
                    result.success(hasPermission)
                }
                "requestNotificationPermission" -> {
                    Log.d(TAG, "📲 Opening notification settings")
                    requestNotificationPermission()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Event Channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    Log.d(TAG, "📡 Event channel listener attached")
                    eventSink = events
                    setupMediaSessionManager()
                }

                override fun onCancel(arguments: Any?) {
                    Log.d(TAG, "📡 Event channel listener detached")
                    eventSink = null
                }
            }
        )
    }

    private fun setupMediaSessionManager() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try {
                mediaSessionManager = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager

                val componentName = ComponentName(this, MusicNotificationListener::class.java)

                // Active sessions 변경 리스너
                mediaSessionManager?.addOnActiveSessionsChangedListener({ controllers ->
                    Log.d(TAG, "🎵 Active sessions changed: ${controllers?.size ?: 0} controllers")
                    if (controllers != null && controllers.isNotEmpty()) {
                        activeController = controllers[0]
                        setupControllerCallback(activeController!!)
                        sendMusicInfoToFlutter()
                    }
                }, componentName)

                // 현재 활성 세션 가져오기
                val controllers = mediaSessionManager?.getActiveSessions(componentName)
                Log.d(TAG, "🎵 Initial active sessions: ${controllers?.size ?: 0}")
                
                if (controllers != null && controllers.isNotEmpty()) {
                    activeController = controllers[0]
                    setupControllerCallback(activeController!!)
                    
                    val packageName = activeController?.packageName
                    Log.d(TAG, "🎵 Active controller: $packageName")
                    
                    // 즉시 정보 전송
                    sendMusicInfoToFlutter()
                } else {
                    Log.w(TAG, "⚠️ No active media sessions found")
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "❌ Notification listener permission not granted: ${e.message}")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error setting up media session manager: ${e.message}")
            }
        }
    }

    private fun setupControllerCallback(controller: MediaController) {
        Log.d(TAG, "🔧 Setting up controller callback for ${controller.packageName}")
        
        controller.registerCallback(object : MediaController.Callback() {
            override fun onMetadataChanged(metadata: MediaMetadata?) {
                super.onMetadataChanged(metadata)
                Log.d(TAG, "🎵 Metadata changed")
                sendMusicInfoToFlutter()
            }

            override fun onPlaybackStateChanged(state: PlaybackState?) {
                super.onPlaybackStateChanged(state)
                Log.d(TAG, "▶️ Playback state changed: ${state?.state}")
                sendMusicInfoToFlutter()
            }
        })
    }

    private fun getNowPlayingInfo(): Map<String, Any?>? {
        val controller = activeController
        
        if (controller == null) {
            Log.w(TAG, "⚠️ No active controller")
            return null
        }

        val metadata = controller.metadata
        if (metadata == null) {
            Log.w(TAG, "⚠️ No metadata available")
            return null
        }

        val playbackState = controller.playbackState

        val info = mutableMapOf<String, Any?>()

        // 곡 정보
        info["title"] = metadata.getString(MediaMetadata.METADATA_KEY_TITLE) ?: "Unknown"
        info["artist"] = metadata.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: "Unknown Artist"
        info["album"] = metadata.getString(MediaMetadata.METADATA_KEY_ALBUM) ?: "Unknown Album"

        // 재생 시간
        val duration = metadata.getLong(MediaMetadata.METADATA_KEY_DURATION)
        info["duration"] = duration / 1000.0

        val currentTime = playbackState?.position ?: 0L
        info["currentTime"] = currentTime / 1000.0

        // 앨범 아트
        val bitmap = metadata.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
            ?: metadata.getBitmap(MediaMetadata.METADATA_KEY_ART)

        if (bitmap != null) {
            try {
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.JPEG, 85, stream)
                val byteArray = stream.toByteArray()
                info["thumbnail"] = byteArray
                Log.d(TAG, "✅ Thumbnail: ${byteArray.size} bytes")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error compressing thumbnail: ${e.message}")
            }
        } else {
            Log.w(TAG, "⚠️ No album art available")
        }

        // 재생 상태
        val isPlaying = playbackState?.state == PlaybackState.STATE_PLAYING
        info["isPlaying"] = isPlaying

        Log.d(TAG, "📱 Track: ${info["title"]} - ${info["artist"]} (${if (isPlaying) "playing" else "paused"})")

        return info
    }

    private fun sendMusicInfoToFlutter() {
        val info = getNowPlayingInfo()
        if (info != null && eventSink != null) {
            Log.d(TAG, "📡 Sending info to Flutter")
            eventSink?.success(info)
        } else {
            Log.w(TAG, "⚠️ Cannot send info: ${if (info == null) "no info" else "no eventSink"}")
        }
    }

    private fun togglePlayPause() {
        val controller = activeController ?: return
        val playbackState = controller.playbackState

        if (playbackState?.state == PlaybackState.STATE_PLAYING) {
            controller.transportControls.pause()
            Log.d(TAG, "⏸️ Paused")
        } else {
            controller.transportControls.play()
            Log.d(TAG, "▶️ Playing")
        }
    }

    private fun nextTrack() {
        activeController?.transportControls?.skipToNext()
        Log.d(TAG, "⏭️ Next track")
    }

    private fun previousTrack() {
        activeController?.transportControls?.skipToPrevious()
        Log.d(TAG, "⏮️ Previous track")
    }

    private fun seek(positionMs: Long) {
        activeController?.transportControls?.seekTo(positionMs)
        Log.d(TAG, "⏩ Seek to ${positionMs}ms")
    }

    private fun setPlaybackSpeed(speed: Float): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            Log.w(TAG, "⚠️ setPlaybackSpeed not supported before Android N")
            return false
        }

        val controller = activeController ?: return false
        return try {
            controller.transportControls.setPlaybackSpeed(speed)
            Log.d(TAG, "🎚️ Playback speed set: $speed")
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error setting playback speed: ${e.message}")
            false
        }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val listeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        )
        val isEnabled = listeners?.contains(packageName) == true
        Log.d(TAG, "🔐 Notification permission: $isEnabled")
        return isEnabled
    }

    private fun requestNotificationPermission() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        startActivity(intent)
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "🔄 onResume - refreshing media sessions")
        
        // 앱이 다시 활성화될 때 미디어 세션 재확인
        if (isNotificationListenerEnabled()) {
            setupMediaSessionManager()
        }
    }
}
