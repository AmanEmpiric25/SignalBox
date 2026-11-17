package com.signalbox.signalbox

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Receives every notification posted on the device once the user has granted
 * notification-listener access in system settings.
 *
 * The service does no storage work itself: it normalises the payload and hands
 * it to [NotificationStreamHandler], which forwards it to Dart over an
 * [io.flutter.plugin.common.EventChannel]. Events posted while no Dart
 * listener is attached are buffered there.
 */
class SignalBoxNotificationListenerService : NotificationListenerService() {

    override fun onListenerConnected() {
        super.onListenerConnected()
        NotificationStreamHandler.setListenerConnected(true)
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        NotificationStreamHandler.setListenerConnected(false)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val notification = sbn ?: return
        if (notification.packageName == packageName) {
            // Never capture our own notifications.
            return
        }

        val extras = notification.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val body = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            ?: ""

        if (title.isBlank() && body.isBlank()) {
            // Ongoing/foreground-service placeholders carry no readable content.
            return
        }

        val payload = hashMapOf<String, Any?>(
            "packageName" to notification.packageName,
            "appLabel" to resolveAppLabel(notification.packageName),
            "title" to title,
            "body" to body,
            "postedAt" to notification.postTime,
            "key" to notification.key,
            "importance" to notification.notification.priority
        )

        NotificationStreamHandler.emit(payload)
    }

    /**
     * Resolves the user visible application name. Falls back to the package
     * name when the application has been uninstalled.
     */
    private fun resolveAppLabel(targetPackage: String): String {
        return try {
            val pm = packageManager
            val info = pm.getApplicationInfo(targetPackage, 0)
            pm.getApplicationLabel(info).toString()
        } catch (e: Exception) {
            targetPackage
        }
    }
}
