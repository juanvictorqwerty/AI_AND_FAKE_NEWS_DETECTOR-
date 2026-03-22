# Fact Check API Module

A NestJS module that integrates with the Google Fact Check Tools API to verify claims and return structured fact-checking results.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [API Usage](#api-usage)
- [Example Response](#example-response)
- [Error Handling](#error-handling)
- [Rate Limiting](#rate-limiting)

## Prerequisites

1. **Node.js** (v18 or higher)
2. **pnpm** or **npm**
3. **Google Fact Check API Key** - [Get one here](https://developers.google.com/fact-check/tools/api)

## Installation

### 1. Install Dependencies

```bash
cd news_auth_check
pnpm install
```

### 2. Configure Environment Variables

Copy the example environment file and add your Google API key:

```bash
cp .env.example .env
```

Edit `.env` and add your API key:

```env
GOOGLE_FACT_CHECK_API_KEY=your-google-fact-check-api-key-here
```

### 3. Run the Application

```bash
# Development mode
pnpm start:dev

# Production mode
pnpm build
pnpm start:prod
```

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GOOGLE_FACT_CHECK_API_KEY` | Yes | Your Google Fact Check Tools API key |
| `PORT` | No | Server port (default: 4000) |
| `FACT_CHECK_RATE_LIMIT` | No | Max requests per window (default: 100) |
| `FACT_CHECK_RATE_LIMIT_WINDOW` | No | Time window in ms (default: 1 hour) |

### Getting a Google Fact Check API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the **Fact Check Tools API**
4. Create credentials (API Key)
5. Copy the API key to your `.env` file

## API Usage

### Authentication

All fact-check endpoints require a valid JWT token. Include the token in the Authorization header:

```
Authorization: Bearer <your-jwt-token>
```

The token is validated against the database to ensure:
- Token is not expired
- Token has not been revoked (logged out)

### Endpoint

```
POST /fact-check
```

### Request Body

```json
{
  "claim": "The Earth is flat",
  "languageCode": "en"
}
```

### Request Parameters

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `claim` | string | Yes | The text/claim to fact-check (max 1000 chars) |
| `languageCode` | string | No | Language code (default: "en") |

### cURL Example

```bash
curl -X POST http://localhost:4000/fact-check \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your-jwt-token>" \
  -d '{
    "claim": "The Earth is flat",
    "languageCode": "en"
  }'
```

### JavaScript/TypeScript Example

```typescript
const response = await fetch('http://localhost:4000/fact-check', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    claim: 'The Earth is flat',
    languageCode: 'en',
  }),
});

const result = await response.json();
console.log(result);
```

## Example Response

### Successful Response (Claim Found)

```json
{
  "success": true,
  "claimText": "The Earth is flat",
  "status": "false",
  "source": "Full Fact",
  "sourceUrl": "https://fullfact.org/online/earth-is-spherical-not-flat/",
  "reviewDate": "2023-03-03T00:00:00Z",
  "textualRating": "We have abundant evidence going back thousands of years that the Earth is roughly spherical.",
  "evidenceSummary": "This claim has been rated as FALSE by Full Fact. We have abundant evidence going back thousands of years that the Earth is roughly spherical.",
  "claimant": "Flat Earth Society",
  "claimDate": "2023-01-01",
  "totalReviews": 1,
  "allReviews": [
    {
      "publisher": "Full Fact",
      "url": "https://fullfact.org/online/earth-is-spherical-not-flat/",
      "title": "The Earth is not flat – Full Fact",
      "reviewDate": "2023-03-03T00:00:00Z",
      "textualRating": "We have abundant evidence going back thousands of years that the Earth is roughly spherical.",
      "status": "false"
    }
  ]
}
```

### Response When No Fact-Check Found

```json
{
  "success": true,
  "claimText": "Some random unverified claim",
  "status": "unverified",
  "source": "No fact-check found",
  "sourceUrl": "",
  "reviewDate": "",
  "textualRating": "No fact-check available for this claim",
  "evidenceSummary": "We could not find any fact-check reviews for this claim. This does not mean the claim is true or false, just that it has not been reviewed by fact-checking organizations yet.",
  "totalReviews": 0,
  "message": "No fact-check results found for this claim"
}
```

## Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | Whether the request was successful |
| `claimText` | string | The claim that was fact-checked |
| `status` | string | Review status: `true`, `false`, or `unverified` |
| `source` | string | Name of the fact-checking organization |
| `sourceUrl` | string | URL to the fact-check article |
| `reviewDate` | string | Date when the claim was reviewed |
| `textualRating` | string | Original textual rating from the source |
| `evidenceSummary` | string | **Auto-generated user-friendly summary** of the evidence |
| `claimant` | string | Who made the claim (if available) |
| `claimDate` | string | When the claim was made (if available) |
| `totalReviews` | number | Total number of fact-check reviews found |
| `allReviews` | array | Array of all fact-check reviews |
| `message` | string | Additional message (e.g., when no results found) |

## Status Values

The API analyzes fact-check verdicts and returns standardized status values:

| Status | Description | Keyword Examples |
|--------|-------------|------------------|
| `true` | The claim is verified as accurate | "True", "Correct", "Verified", "Confirmed" |
| `false` | The claim is rated as false/misleading | "False", "Fake", "Incorrect", "Debunked", "Pants on Fire", "No evidence" |
| `unverified` | No fact-check available or inconclusive | "Unproven", "No reviews found", or unclear verdict |

### How Status is Determined

The API uses intelligent text analysis on the fact-check's textual rating to determine the status:

- **False indicators**: "false", "fake", "incorrect", "misleading", "untrue", "fabricated", "hoax", "fiction", "wrong", "inaccurate", "debunked", "baseless", "refuted", "pants on fire", "mostly false"
- **True indicators**: "true", "correct", "accurate", "confirmed", "verified", "authentic", "genuine", "real", "substantiated", "mostly true"
- **Negation handling**: The API correctly handles negations like "not true" (false) vs "true" (true)

## Error Handling

### Unauthorized (401) - No Token

```json
{
  "message": "No token provided",
  "error": "Unauthorized",
  "statusCode": 401
}
```

### Unauthorized (401) - Invalid or Revoked Token

```json
{
  "message": "Invalid or revoked token",
  "error": "Unauthorized",
  "statusCode": 401
}
```

### Invalid API Key (403)

```json
{
  "success": false,
  "message": "Invalid API key. Please check your configuration.",
  "errorCode": "INVALID_API_KEY"
}
```

### Rate Limit Exceeded (429)

```json
{
  "success": false,
  "message": "Rate limit exceeded. Please try again later.",
  "errorCode": "RATE_LIMIT_EXCEEDED"
}
```

### Validation Error (400)

```json
{
  "message": ["Claim text is required"],
  "error": "Bad Request",
  "statusCode": 400
}
```

### API Error (502)

```json
{
  "success": false,
  "message": "Failed to fact-check claim. Please try again later.",
  "errorCode": "API_ERROR"
}
```

## Rate Limiting

The Google Fact Check Tools API has built-in rate limiting. This implementation includes:

1. **Request Timeouts**: 10-second timeout on API calls
2. **Error Handling**: Graceful handling of rate limit errors (429)
3. **Configurable Limits**: Optional environment variables for custom rate limiting

To implement additional rate limiting, you can use NestJS throttler:

```bash
pnpm add @nestjs/throttler
```

## Architecture

```
src/fact-check/
├── dto/
│   ├── fact-check-claim.dto.ts    # Input validation
│   ├── fact-check-result.dto.ts   # Output structure
│   └── index.ts                   # DTO exports
├── fact-check.controller.ts       # HTTP endpoint
├── fact-check.service.ts          # Business logic
└── fact-check.module.ts           # Module definition
```

## Testing

Run the test suite:

```bash
# Unit tests
pnpm test

# E2E tests
pnpm test:e2e
```

## Troubleshooting

### "Cannot find module 'axios'"

Run:
```bash
pnpm install
```

### "Invalid API key" error

1. Verify your `GOOGLE_FACT_CHECK_API_KEY` is set in `.env`
2. Ensure the Fact Check Tools API is enabled in Google Cloud Console
3. Check that your API key has no restrictions blocking your server IP

### No results found

The Google Fact Check API only returns results for claims that have been fact-checked by participating organizations. Not all claims will have fact-checks available.

## License

This module is part of the news_auth_check project.
