package com.example.ai_fake_news_detector

import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import com.example.ai_fake_news_detector.OverlayActivity

/**
 * Quick Settings Tile Service for AI Fake News Detector
 * This service runs independently and can trigger Flutter overlay even when app is closed
 */
class QuickSettingsTileService : TileService() {

    companion object {
        private const val TAG = "QuickSettingsTile"
        private var instance: QuickSettingsTileService? = null
        
        fun getInstance(): QuickSettingsTileService? = instance
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "TileService created")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "TileService destroyed")
    }

    /**
     * Called when the tile is added to Quick Settings
     */
    override fun onTileAdded() {
        super.onTileAdded()
        Log.d(TAG, "Tile added to Quick Settings")
        updateTile()
    }

    /**
     * Called when the tile becomes visible
     */
    override fun onStartListening() {
        super.onStartListening()
        Log.d(TAG, "Tile started listening")
        updateTile()
    }

    /**
     * Called when the tile is no longer visible
     */
    override fun onStopListening() {
        super.onStopListening()
        Log.d(TAG, "Tile stopped listening")
    }

    /**
     * Called when the tile is removed from Quick Settings
     */
    override fun onTileRemoved() {
        super.onTileRemoved()
        Log.d(TAG, "Tile removed from Quick Settings")
    }

    /**
     * Called when user clicks the tile
     * This is the main entry point for triggering the overlay
     */
    override fun onClick() {
        super.onClick()
        Log.d(TAG, "Tile clicked")
        
        // Toggle tile state
        val tile = qsTile
        if (tile != null) {
            // Update tile state to active
            tile.state = Tile.STATE_ACTIVE
            tile.updateTile()
            
            // Trigger Flutter overlay
            triggerFlutterOverlay()
        }
    }

    /**
     * Update tile appearance and state
     */
    private fun updateTile() {
        val tile = qsTile ?: return
        
        // Set tile label
        tile.label = "Fact Check"
        
        // Set tile subtitle (available on Android 10+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = "AI Detector"
        }
        
        // Set tile state
        tile.state = Tile.STATE_INACTIVE
        
        // Update the tile
        tile.updateTile()
        Log.d(TAG, "Tile updated")
    }

    /**
     * Trigger Flutter overlay popup
     * This method launches an overlay activity that communicates with Flutter
     */
    private fun triggerFlutterOverlay() {
        try {
            // Create an intent to launch the overlay activity
            val intent = Intent(this, OverlayActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("trigger_source", "quick_settings_tile")
                putExtra("timestamp", System.currentTimeMillis())
            }
            
            startActivity(intent)
            Log.d(TAG, "Overlay activity launched")
            
            // Reset tile state after a short delay
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                val tile = qsTile
                if (tile != null) {
                    tile.state = Tile.STATE_INACTIVE
                    tile.updateTile()
                }
            }, 500)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error triggering overlay: ${e.message}", e)
            
            // Fallback: Try to launch main activity
            try {
                val fallbackIntent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    putExtra("trigger_source", "quick_settings_tile")
                }
                startActivity(fallbackIntent)
            } catch (fallbackError: Exception) {
                Log.e(TAG, "Fallback also failed: ${fallbackError.message}", fallbackError)
            }
        }
    }
}
