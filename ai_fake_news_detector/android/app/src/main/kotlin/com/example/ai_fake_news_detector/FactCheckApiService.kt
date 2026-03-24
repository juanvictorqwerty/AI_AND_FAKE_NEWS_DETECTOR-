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
                val baseUrl = ConfigManager.getBaseUrl()
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
                    // Parse the result
                    val resultJson = json.optJSONObject("result")
                    val verdict = resultJson?.optString("verdict", "Unknown") ?: "Unknown"
                    val explanation = resultJson?.optString("explanation", "") ?: ""
                    val sources = resultJson?.optJSONArray("sources")
                    val sourcesList = mutableListOf<String>()
                    
                    if (sources != null) {
                        for (i in 0 until sources.length()) {
                            sourcesList.add(sources.optString(i, ""))
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
