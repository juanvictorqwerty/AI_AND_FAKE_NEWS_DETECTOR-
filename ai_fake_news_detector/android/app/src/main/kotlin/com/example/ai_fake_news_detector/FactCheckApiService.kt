package com.example.ai_fake_news_detector

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * FactCheckApiService - Native Kotlin service for fact-checking API calls
 * Uses OkHttp and Coroutines for async HTTP requests
 */
class FactCheckApiService {
    
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()
    
    private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()
    
    /**
     * Search for fact-check results for a given claim
     * 
     * @param claim The claim text to fact-check
     * @param token The authentication token
     * @return FactCheckResult with success status and result or error message
     */
    suspend fun searchFactCheck(claim: String, token: String): FactCheckResult {
        return withContext(Dispatchers.IO) {
            try {
                val baseUrl = ConfigManager.getFactCheckUrl()
                val url = "$baseUrl/fact-check/search"
                
                println("FactCheckApiService: Calling $url")
                
                // Create JSON request body
                val jsonBody = JSONObject().apply {
                    put("claim", claim)
                }.toString()
                
                val request = Request.Builder()
                    .url(url)
                    .post(jsonBody.toRequestBody(JSON_MEDIA_TYPE))
                    .addHeader("Content-Type", "application/json")
                    .addHeader("Authorization", "Bearer $token")
                    .build()
                
                val response = client.newCall(request).execute()
                val responseBody = response.body?.string()
                
                println("FactCheckApiService: Response code=${response.code}, body=$responseBody")
                
                if (responseBody.isNullOrEmpty()) {
                    return@withContext FactCheckResult(
                        success = false,
                        message = "Server returned empty response. Status: ${response.code}"
                    )
                }
                
                val json = JSONObject(responseBody)
                
                // Check success field from backend
                if (json.optBoolean("success", false)) {
                    // Parse the verdict object (it's at top level, not inside "result")
                    val verdictJson = json.optJSONObject("verdict")
                    val verdict = verdictJson?.optString("verdict", "Unknown") ?: "Unknown"
                    val explanation = verdictJson?.optString("reason", "") ?: ""
                    
                    // Parse sources from top level
                    val sources = json.optJSONArray("sources")
                    val sourcesList = mutableListOf<String>()
                    
                    if (sources != null) {
                        for (i in 0 until sources.length()) {
                            val source = sources.optJSONObject(i)
                            if (source != null) {
                                val title = source.optString("title", "")
                                if (title.isNotEmpty()) {
                                    sourcesList.add(title)
                                }
                            }
                        }
                    }
                    
                    return@withContext FactCheckResult(
                        success = true,
                        verdict = verdict,
                        explanation = explanation,
                        sources = sourcesList
                    )
                } else {
                    val message = json.optString("message", "Fact-check failed")
                    return@withContext FactCheckResult(
                        success = false,
                        message = message
                    )
                }
            } catch (e: Exception) {
                println("FactCheckApiService: Error $e")
                return@withContext FactCheckResult(
                    success = false,
                    message = "Error: ${e.message}"
                )
            }
        }
    }
    
    /**
     * Data class to hold fact-check result
     */
    data class FactCheckResult(
        val success: Boolean,
        val verdict: String = "",
        val explanation: String = "",
        val sources: List<String> = emptyList(),
        val message: String = ""
    )
}
