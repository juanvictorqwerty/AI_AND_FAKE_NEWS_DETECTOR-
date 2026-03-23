package com.example.ai_fake_news_detector

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput
import io.flutter.plugin.common.MethodChannel

class NotificationForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "fact_check_notification_channel"
        const val NOTIFICATION_ID = 1001
        const val KEY_TEXT_REPLY = "key_text_reply"
        const val ACTION_SUBMIT = "com.example.ai_fake_news_detector.ACTION_SUBMIT"
        const val ACTION_STOP = "com.example.ai_fake_news_detector.ACTION_STOP"
        
        private var isRunning = false
        private var instance: NotificationForegroundService? = null
        
        fun isServiceRunning(): Boolean = isRunning
        
        fun getInstance(): NotificationForegroundService? {
            return instance
        }
        
        fun startService(context: Context) {
            val intent = Intent(context, NotificationForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun stopService(context: Context) {
            val intent = Intent(context, NotificationForegroundService::class.java)
            intent.action = ACTION_STOP
            context.startService(intent)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_SUBMIT -> {
                handleRemoteInput(intent)
            }
            else -> {
                // Start the foreground service with notification
                val notification = createNotification()
                startForeground(NOTIFICATION_ID, notification)
                isRunning = true
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        isRunning = false
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Fact Check Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for fact checking from notification bar"
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        // Create RemoteInput for inline text input
        val remoteInput = RemoteInput.Builder(KEY_TEXT_REPLY)
            .setLabel("Enter text to fact check...")
            .build()

        // Create the reply action
        val replyIntent = Intent(this, NotificationForegroundService::class.java).apply {
            action = ACTION_SUBMIT
        }
        val replyPendingIntent = PendingIntent.getService(
            this,
            0,
            replyIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        val replyAction = NotificationCompat.Action.Builder(
            R.drawable.ic_send,
            "Fact Check",
            replyPendingIntent
        )
            .addRemoteInput(remoteInput)
            .build()

        // Create stop action
        val stopIntent = Intent(this, NotificationForegroundService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopAction = NotificationCompat.Action.Builder(
            R.drawable.ic_close,
            "Stop",
            stopPendingIntent
        ).build()

        // Build the notification
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AI Fact Checker")
            .setContentText("Tap to enter text for fact checking")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(replyAction)
            .addAction(stopAction)
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("Enter text below to fact check instantly without opening the app"))
            .build()
    }

    private fun handleRemoteInput(intent: Intent) {
        val remoteInput = RemoteInput.getResultsFromIntent(intent)
        if (remoteInput != null) {
            val inputText = remoteInput.getCharSequence(KEY_TEXT_REPLY)?.toString()
            if (!inputText.isNullOrEmpty()) {
                // Send the text to Flutter via MethodChannel
                sendToFlutter(inputText)
                
                // Update notification with processing status
                updateNotificationWithStatus("Processing: $inputText")
            }
        }
    }

    private fun sendToFlutter(text: String) {
        // Get the Flutter engine from MainActivity
        val flutterEngine = MainActivity.getFlutterEngine()
        if (flutterEngine != null) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fact_check_channel")
            println("NotificationForegroundService: Sending to Flutter: $text")
            channel.invokeMethod("onNotificationInput", text)
        } else {
            println("NotificationForegroundService: ERROR - FlutterEngine is null")
        }
    }

    private fun updateNotificationWithStatus(status: String) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AI Fact Checker")
            .setContentText(status)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    fun updateNotificationWithResult(result: String) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AI Fact Checker - Result")
            .setContentText(result)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(true)
            .setAutoCancel(false)
            .setStyle(NotificationCompat.BigTextStyle().bigText(result))
            .build()

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}
