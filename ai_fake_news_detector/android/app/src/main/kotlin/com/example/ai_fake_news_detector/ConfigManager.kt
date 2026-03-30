package com.example.ai_fake_news_detector

import android.content.Context
import android.content.SharedPreferences

/**
 * ConfigManager - Manages configuration settings for the native notification system
 * Reads base URL and other settings from SharedPreferences
 * Uses the same SharedPreferences as Flutter for token synchronization
 *
 * IMPORTANT: Flutter's shared_preferences plugin stores data in a file named
 * "FlutterSharedPreferences" and prefixes every key with "flutter."
 * e.g. Dart key "auth_token" → Android key "flutter.auth_token"
 */
object ConfigManager {

    // Flutter's shared_preferences file name
    private const val FLUTTER_PREFS_FILE = "FlutterSharedPreferences"

    // Flutter's key prefix (added automatically by the shared_preferences plugin)
    private const val FLUTTER_PREFIX = "flutter."

    // Raw keys (must match the keys used in AuthController / AuthService on the Dart side)
    private const val RAW_KEY_BASE_URL = "base_url"
    private const val RAW_KEY_AUTH_TOKEN = "auth_token"
    private const val RAW_KEY_FACT_CHECK_URL = "fact_check_url"
    private const val RAW_KEY_MEDIA_UPLOAD_URL = "media_upload_url"

    // Fully-qualified keys as stored on disk
    private const val KEY_BASE_URL = "$FLUTTER_PREFIX$RAW_KEY_BASE_URL"
    private const val KEY_AUTH_TOKEN = "$FLUTTER_PREFIX$RAW_KEY_AUTH_TOKEN"
    private const val KEY_FACT_CHECK_URL = "$FLUTTER_PREFIX$RAW_KEY_FACT_CHECK_URL"
    private const val KEY_MEDIA_UPLOAD_URL = "$FLUTTER_PREFIX$RAW_KEY_MEDIA_UPLOAD_URL"

    // Default URLs (from .env file)
    // Fact checking service uses port 4000
    private const val DEFAULT_FACT_CHECK_URL = "http://192.168.1.152:4000"
    // Media upload service uses port 8000
    private const val DEFAULT_MEDIA_UPLOAD_URL = "http://192.168.1.152:8000"
    // Legacy base URL (defaults to media upload URL for backward compatibility)
    private const val DEFAULT_BASE_URL = DEFAULT_MEDIA_UPLOAD_URL

    private var prefs: SharedPreferences? = null

    /**
     * Initialize the ConfigManager with application context.
     * Must be called once (e.g. in Application.onCreate) before any get/set calls.
     *
     * Uses "FlutterSharedPreferences" to match the file that Flutter's
     * shared_preferences plugin writes to on Android.
     */
    fun init(context: Context) {
        prefs = context.getSharedPreferences(FLUTTER_PREFS_FILE, Context.MODE_PRIVATE)
    }

    /**
     * Get the base URL for API calls.
     * Reads the "flutter.base_url" key written by Flutter's shared_preferences.
     * Returns DEFAULT_BASE_URL if not set.
     */
    fun getBaseUrl(): String {
        return prefs?.getString(KEY_BASE_URL, DEFAULT_BASE_URL) ?: DEFAULT_BASE_URL
    }

    /**
     * Set the base URL for API calls.
     * Writes to "flutter.base_url" so Flutter can also read the updated value.
     */
    fun setBaseUrl(url: String) {
        prefs?.edit()?.putString(KEY_BASE_URL, url)?.apply()
    }

    /**
     * Get the authentication token.
     * Reads the "flutter.auth_token" key written by AuthController._saveToken() in Dart.
     * Returns null if the token has not been saved yet or the user is not logged in.
     */
    fun getAuthToken(): String? {
        return prefs?.getString(KEY_AUTH_TOKEN, null)
    }

    /**
     * Set the authentication token.
     * Writes to "flutter.auth_token" so it stays in sync with Flutter's AuthController.
     */
    fun setAuthToken(token: String) {
        prefs?.edit()?.putString(KEY_AUTH_TOKEN, token)?.apply()
    }

    /**
     * Get the fact check API URL.
     * Reads the "flutter.fact_check_url" key written by Flutter's shared_preferences.
     * Returns DEFAULT_FACT_CHECK_URL if not set.
     */
    fun getFactCheckUrl(): String {
        return prefs?.getString(KEY_FACT_CHECK_URL, DEFAULT_FACT_CHECK_URL) ?: DEFAULT_FACT_CHECK_URL
    }

    /**
     * Set the fact check API URL.
     * Writes to "flutter.fact_check_url" so Flutter can also read the updated value.
     */
    fun setFactCheckUrl(url: String) {
        prefs?.edit()?.putString(KEY_FACT_CHECK_URL, url)?.apply()
    }

    /**
     * Get the media upload API URL.
     * Reads the "flutter.media_upload_url" key written by Flutter's shared_preferences.
     * Returns DEFAULT_MEDIA_UPLOAD_URL if not set.
     */
    fun getMediaUploadUrl(): String {
        return prefs?.getString(KEY_MEDIA_UPLOAD_URL, DEFAULT_MEDIA_UPLOAD_URL) ?: DEFAULT_MEDIA_UPLOAD_URL
    }

    /**
     * Set the media upload API URL.
     * Writes to "flutter.media_upload_url" so Flutter can also read the updated value.
     */
    fun setMediaUploadUrl(url: String) {
        prefs?.edit()?.putString(KEY_MEDIA_UPLOAD_URL, url)?.apply()
    }

    /**
     * Clear all configuration entries managed by this class.
     * Does NOT wipe the entire FlutterSharedPreferences file — only the keys
     * owned by ConfigManager — so other Flutter preferences are left intact.
     */
    fun clear() {
        prefs?.edit()
            ?.remove(KEY_BASE_URL)
            ?.remove(KEY_AUTH_TOKEN)
            ?.remove(KEY_FACT_CHECK_URL)
            ?.remove(KEY_MEDIA_UPLOAD_URL)
            ?.apply()
    }
}