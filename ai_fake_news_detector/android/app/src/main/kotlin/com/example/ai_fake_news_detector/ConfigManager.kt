package com.example.ai_fake_news_detector

import android.content.Context
import android.content.SharedPreferences

/**
 * ConfigManager - Manages configuration settings for the native notification system
 * Reads base URL and other settings from SharedPreferences
 */
object ConfigManager {
    
    private const val PREFS_NAME = "app_config"
    private const val KEY_BASE_URL = "base_url"
    private const val KEY_AUTH_TOKEN = "auth_token"
    
    // Default base URL (same as Flutter default)
    private const val DEFAULT_BASE_URL = "http://192.168.1.152:4000"
    
    private var prefs: SharedPreferences? = null
    
    /**
     * Initialize the ConfigManager with application context
     */
    fun init(context: Context) {
        prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }
    
    /**
     * Get the base URL for API calls
     * Returns the stored URL or default if not set
     */
    fun getBaseUrl(): String {
        return prefs?.getString(KEY_BASE_URL, DEFAULT_BASE_URL) ?: DEFAULT_BASE_URL
    }
    
    /**
     * Set the base URL for API calls
     * This can be called from Flutter to sync the .env value
     */
    fun setBaseUrl(url: String) {
        prefs?.edit()?.putString(KEY_BASE_URL, url)?.apply()
    }
    
    /**
     * Get the authentication token
     * Returns null if not set
     */
    fun getAuthToken(): String? {
        return prefs?.getString(KEY_AUTH_TOKEN, null)
    }
    
    /**
     * Set the authentication token
     * This can be called from Flutter to sync the token
     */
    fun setAuthToken(token: String) {
        prefs?.edit()?.putString(KEY_AUTH_TOKEN, token)?.apply()
    }
    
    /**
     * Clear all configuration
     */
    fun clear() {
        prefs?.edit()?.clear()?.apply()
    }
}
