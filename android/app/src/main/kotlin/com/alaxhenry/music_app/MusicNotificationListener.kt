package com.alaxhenry.music_app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class MusicNotificationListener : NotificationListenerService() {

    private val TAG = "MusicNotificationListener"

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        Log.d(TAG, "🔔 Notification posted: ${sbn?.packageName}")
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        Log.d(TAG, "🔕 Notification removed: ${sbn?.packageName}")
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "✅ Notification Listener connected")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "❌ Notification Listener disconnected")
    }
}