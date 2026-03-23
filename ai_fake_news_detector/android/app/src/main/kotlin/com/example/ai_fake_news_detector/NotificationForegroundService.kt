package com.example.ai_fake_news_detector

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput
import io.flutter.plugin.common.MethodChannel

// NOTE: If you see "Unresolved reference: ic_send" or "Unresolved reference: ic_close" errors,
// this is because the R class hasn't been generated yet. To fix this:
// 1. Build the project: flutter build apk --debug
// 2. Or clean and rebuild: cd android && ./gradlew clean && cd .. && flutter clean && flutter pub get
// 3. Invalidate caches in Android Studio: File -> Invalidate Caches / Restart
// The drawable resources (ic_send.xml and ic_close.xml) exist in res/drawable/ and are correctly defined.

class NotificationForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "fact_check_notification_channel"
        const val NOTIFICATION_ID = 1001
        const val KEY_TEXT_REPLY = "key_text_reply"
        const val ACTION_SUBMIT = "com.example.ai_fake_news_detector.ACTION_SUBMIT"
        const val ACTION_STOP = "com.example.ai_fake_news_detector.ACTION_STOP"
        
        private var isRunning = false
        private var instance: NotificationForegroundService? = null
        
        // Conversation context for continuous chat
        private var lastQuestion: String? = null
        private var lastAnswer: String? = null
        
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
        // Clear conversation context when service is destroyed
        lastQuestion = null
        lastAnswer = null
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
        // Use unique request code to ensure PendingIntent is unique
        val replyPendingIntent = PendingIntent.getService(
            this,
            System.currentTimeMillis().toInt(), // Unique request code
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

        // Build conversation context for display
        val conversationContext = buildConversationContext("Ready to fact check")
        
        // Build the notification
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AI Fact Checker")
            .setContentText(conversationContext)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(replyAction)
            .addAction(stopAction)
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText(conversationContext))
            .build()
    }

    private fun handleRemoteInput(intent: Intent) {
        val remoteInput = RemoteInput.getResultsFromIntent(intent)
        if (remoteInput != null) {
            val inputText = remoteInput.getCharSequence(KEY_TEXT_REPLY)?.toString()
            if (!inputText.isNullOrEmpty()) {
                // Store the question for conversation context
                lastQuestion = inputText
                
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
            try {
                val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fact_check_channel")
                println("NotificationForegroundService: Sending to Flutter: $text")
                channel.invokeMethod("onNotificationInput", text)
            } catch (e: Exception) {
                println("NotificationForegroundService: Error sending to Flutter: ${e.message}")
                // Update notification with error if Flutter is not available
                updateNotificationWithStatus("Error: App is closed. Please open the app to continue.")
            }
        } else {
            println("NotificationForegroundService: ERROR - FlutterEngine is null")
            // Update notification with error if Flutter engine is not available
            updateNotificationWithStatus("Error: App is closed. Please open the app to continue.")
        }
    }

    private fun updateNotificationWithStatus(status: String) {
        // Build conversation context for display
        val conversationContext = buildConversationContext(status)
        
        // Create RemoteInput for inline text input (keep input field visible during processing)
        val remoteInput = RemoteInput.Builder(KEY_TEXT_REPLY)
            .setLabel("Ask another question...")
            .build()

        // Create the reply action with RemoteInput
        val replyIntent = Intent(this, NotificationForegroundService::class.java).apply {
            action = ACTION_SUBMIT
        }
        val replyPendingIntent = PendingIntent.getService(
            this,
            System.currentTimeMillis().toInt(), // Unique request code
            replyIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        val replyAction = NotificationCompat.Action.Builder(
            R.drawable.ic_send,
            "Ask Again",
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
        
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AI Fact Checker")
            .setContentText(conversationContext)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(replyAction)
            .addAction(stopAction)
            .setStyle(NotificationCompat.BigTextStyle().bigText(conversationContext))
            .build()

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    fun updateNotificationWithResult(result: String) {
        println("NotificationForegroundService: updateNotificationWithResult called with: $result")
        
        // Store the answer for conversation context
        lastAnswer = result
        
        // Build notification with result and re-attach RemoteInput for continuous chat
        val notification = buildNotificationWithResult(result)
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // Cancel the old notification first to ensure clean state
        notificationManager.cancel(NOTIFICATION_ID)
        // Then notify with new notification to ensure RemoteInput is properly attached
        notificationManager.notify(NOTIFICATION_ID, notification)
        println("NotificationForegroundService: Notification updated successfully with RemoteInput re-attached")
    }
    
    /**
     * Build notification with result and re-attach RemoteInput for continuous chat loop
     */
    private fun buildNotificationWithResult(result: String): Notification {
        // Create RemoteInput for inline text input (re-attached after each result)
        val remoteInput = RemoteInput.Builder(KEY_TEXT_REPLY)
            .setLabel("Ask another question...")
            .build()

        // Create the reply action with RemoteInput
        // Use unique request code to ensure PendingIntent is unique for each update
        val replyIntent = Intent(this, NotificationForegroundService::class.java).apply {
            action = ACTION_SUBMIT
        }
        val replyPendingIntent = PendingIntent.getService(
            this,
            System.currentTimeMillis().toInt(), // Unique request code for each update
            replyIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        val replyAction = NotificationCompat.Action.Builder(
            R.drawable.ic_send,
            "Ask Again",
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

        // Build conversation context for display
        val conversationContext = buildConversationContext(result)
        
        // Build the notification with result and RemoteInput
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AI Fact Checker - Result")
            .setContentText(conversationContext)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(replyAction)
            .addAction(stopAction)
            .setStyle(NotificationCompat.BigTextStyle().bigText(conversationContext))
            .build()
    }
    
    /**
     * Build conversation context for display in notification
     */
    private fun buildConversationContext(result: String): String {
        val context = StringBuilder()
        
        // Add last question if available
        if (!lastQuestion.isNullOrEmpty()) {
            context.append("Q: $lastQuestion\n\n")
        }
        
        // Add result/answer
        context.append("A: $result")
        
        return context.toString()
    }
}
