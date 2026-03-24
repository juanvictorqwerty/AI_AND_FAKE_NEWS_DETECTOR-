package com.example.ai_fake_news_detector

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * BootReceiver - Automatically starts the NotificationForegroundService on device boot
 * and app install/first launch.
 */
class BootReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                // Start service on device boot
                println("BootReceiver: Device boot completed, starting NotificationForegroundService")
                startNotificationService(context)
            }
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                // Start service on app update
                println("BootReceiver: Package replaced, starting NotificationForegroundService")
                startNotificationService(context)
            }
            Intent.ACTION_PACKAGE_ADDED -> {
                // Start service on app install (first launch)
                val packageName = intent.data?.schemeSpecificPart
                if (packageName == context.packageName) {
                    println("BootReceiver: Package added, starting NotificationForegroundService")
                    startNotificationService(context)
                }
            }
        }
    }
    
    private fun startNotificationService(context: Context) {
        try {
            // Start the service as a foreground service
            NotificationForegroundService.startService(context)
            println("BootReceiver: NotificationForegroundService started successfully")
        } catch (e: Exception) {
            println("BootReceiver: Error starting NotificationForegroundService: ${e.message}")
            e.printStackTrace()
        }
    }
}
