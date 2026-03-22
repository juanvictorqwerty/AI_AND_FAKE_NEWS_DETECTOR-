# Hybrid Fact-Check API Documentation

A comprehensive fact-checking system that combines Google Fact Check Tools API with web search to provide thorough claim verification.

## Features

- **Google Fact Check API Integration**: Direct access to verified fact-checks
- **Web Search**: Searches trusted sources when Google API has no results
- **Search Query Generation**: AI-optimized queries for better results
- **Source Filtering**: Only returns results from trusted publishers
- **Caching**: 30-minute cache to avoid repeated searches
- **Rate Limiting**: Built-in protection against API abuse

## API Endpoints

### 1. Standard Fact Check (Google API Only)

```
POST /fact-check
```

Uses only the Google Fact Check Tools API.

### 2. Hybrid Fact Check (Google API + Web Search)

```
POST /fact-check/hybrid
```

Combines Google API results with web search for comprehensive verification.

**Request:**
```json
{
  "claim": "The Earth is flat",
  "languageCode": "en",
  "skipWebSearch": false
}
```

**Response:**
```json
{
  "success": true,
  "claimText": "The Earth is flat",
  "searchQuery": "The Earth is flat fact check",
  "googleFactCheckResult": {
    "found": true,
    "status": "false",
    "source": "Full Fact",
    "sourceUrl": "https://fullfact.org/online/earth-is-spherical-not-flat/",
    "reviewDate": "2023-03-03T00:00:00Z",
    "textualRating": "We have abundant evidence going back thousands of years..."
  },
  "webSearchResults": [
    {
      "title": "The Earth is not flat – Full Fact",
      "url": "https://fullfact.org/online/earth-is-spherical-not-flat/",
      "date": "2023-03-03T00:00:00Z",
      "snippet": "We have abundant evidence going back thousands of years...",
      "publisher": "fullfact.org",
      "isTrusted": true
    }
  ],
  "combinedVerdict": "false",
  "evidenceSummary": "This claim has been rated as FALSE by Full Fact...",
  "totalSources": 2,
  "trustedSourcesCount": 2
}
```

### 3. Web Search Only

```
POST /fact-check/search
```

Searches the web for fact-check sources without using Google API.

**Request:**
```json
{
  "claim": "The Earth is flat"
}
```

**Response:**
```json
{
  "success": true,
  "query": "The Earth is flat",
  "results": [
    {
      "title": "...",
      "url": "...",
      "date": "...",
      "snippet": "...",
      "publisher": "...",
      "isTrusted": true
    }
  ]
}
```

## Combined Verdict Values

| Verdict | Description |
|---------|-------------|
| `true` | Multiple sources confirm the claim is accurate |
| `false` | Evidence shows the claim is false or misleading |
| `inconclusive` | Sources provide conflicting information |
| `unverified` | No reliable sources found to verify the claim |

## Trusted Sources

The system filters results to include only trustworthy sources:

### Fact-Check Sites (Score: 100)
- Snopes
- FactCheck.org
- PolitiFact
- Full Fact
- AFP Fact Check

### News Agencies (Score: 90)
- Reuters
- Associated Press
- BBC
- CNN

### Educational/Government (Score: 85)
- .edu domains
- .gov domains
- Wikipedia
- WHO
- CDC

### Scientific Journals (Score: 85)
- Nature
- Scientific American
- Science.org

## Configuration

### Required Environment Variables

```env
# Google Fact Check API (Required)
GOOGLE_FACT_CHECK_API_KEY=your-key-here

# Google Custom Search (Optional, enables web search)
GOOGLE_SEARCH_API_KEY=your-key-here
GOOGLE_SEARCH_ENGINE_ID=your-engine-id

# OR SerpAPI Alternative (Optional)
SERP_API_KEY=your-key-here
```

### Getting API Keys

**Google Fact Check API:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Enable "Fact Check Tools API"
3. Create credentials (API Key)

**Google Custom Search:**
1. Go to [Programmable Search Engine](https://cse.google.com/cse/)
2. Create a new search engine
3. Enable "Search the entire web"
4. Get your Search Engine ID
5. Enable "Custom Search API" in Google Cloud Console

**SerpAPI (Alternative):**
1. Go to [SerpAPI](https://serpapi.com/)
2. Sign up and get your API key

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Hybrid Fact Check Flow                 │
├─────────────────────────────────────────────────────────┤
│  1. User sends claim                                    │
│     ↓                                                   │
│  2. Generate optimized search query                     │
│     ↓                                                   │
│  3. Query Google Fact Check API                         │
│     ↓                                                   │
│  4. If unverified/no result → Search web                │
│     ↓                                                   │
│  5. Filter results by trusted sources                   │
│     ↓                                                   │
│  6. Analyze and combine verdicts                        │
│     ↓                                                   │
│  7. Generate evidence summary                           │
│     ↓                                                   │
│  8. Return combined result                              │
└─────────────────────────────────────────────────────────┘
```

## Caching & Rate Limiting

### Caching
- Search results are cached for 30 minutes
- Cache key based on normalized claim text
- Maximum 100 cached entries (LRU eviction)

### Rate Limiting
- 10 requests per minute per endpoint
- Rate limit window: 60 seconds
- Returns 429 status when exceeded

## Example Usage

### Using cURL

```bash
# Get JWT token first
curl -X POST http://localhost:4000/auth/signin \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "password"}'

# Use token for hybrid fact-check
curl -X POST http://localhost:4000/fact-check/hybrid \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "claim": "The Earth is flat",
    "languageCode": "en"
  }'
```

### Using JavaScript

```javascript
const response = await fetch('http://localhost:4000/fact-check/hybrid', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`,
  },
  body: JSON.stringify({
    claim: 'The Earth is flat',
    languageCode: 'en',
  }),
});

const result = await response.json();
console.log(result.combinedVerdict); // "false"
console.log(result.evidenceSummary);   // Detailed summary
```

## Error Handling

### 401 Unauthorized
```json
{
  "message": "No token provided",
  "error": "Unauthorized",
  "statusCode": 401
}
```

### 429 Rate Limit
```json
{
  "message": "Search rate limit exceeded. Please try again later.",
  "error": "Too Many Requests",
  "statusCode": 429
}
```

### No Results Found
```json
{
  "success": true,
  "claimText": "Some obscure claim",
  "combinedVerdict": "unverified",
  "evidenceSummary": "We could not find any fact-check reviews...",
  "totalSources": 0,
  "message": "No definitive fact-check found from reliable sources."
}
```

## Testing

Run the test suite:
```bash
pnpm test
```

## Integration with AI Pipeline

The hybrid fact-check API is designed to integrate with AI-powered claim analysis:

```javascript
// Example AI pipeline integration
async function analyzeClaim(claimText) {
  // Step 1: Get fact-check data
  const factCheck = await fetch('/fact-check/hybrid', {
    method: 'POST',
    body: JSON.stringify({ claim: claimText }),
  }).then(r => r.json());

  // Step 2: Use fact-check data to inform AI analysis
  const aiAnalysis = await aiService.analyze({
    claim: claimText,
    factCheckData: factCheck,
  });

  return {
    verdict: factCheck.combinedVerdict,
    confidence: calculateConfidence(factCheck),
    sources: factCheck.webSearchResults,
    explanation: aiAnalysis.explanation,
  };
}
```
