import { Injectable, Logger } from '@nestjs/common';
import { SearchSourceDto } from './dto';

/**
 * Verdict analysis result
 */
export interface VerdictResult {
    verdict: 'true' | 'false' | 'unverified';
    confidence: 'low' | 'medium' | 'high';
    reason: string;
    usedSources: {
        title: string;
        justification: string;
    }[];
}

@Injectable()
export class VerdictAnalysisService {
    private readonly logger = new Logger(VerdictAnalysisService.name);

    // OpenRouter configuration
    private readonly openRouterApiKey = process.env.OPENROUTER_API_KEY;
    private readonly openRouterEndpoint = 'https://openrouter.ai/api/v1/chat/completions';
    // You can swap this for 'google/gemini-2.0-flash-001' or 'anthropic/claude-3.5-sonnet', etc.
    private readonly model = 'google/gemini-2.0-flash-001';

    async analyzeVerdict(
        claim: string,
        sources: SearchSourceDto[],
    ): Promise<VerdictResult> {
        this.logger.log(
            `Analyzing verdict via OpenRouter for claim: "${claim.substring(0, 50)}..."`,
        );

        if (!sources || sources.length === 0) {
            return {
                verdict: 'unverified',
                confidence: 'low',
                reason: 'No sources available to verify this claim.',
                usedSources: [],
            };
        }

        try {
            return await this.callOpenRouter(claim, sources);
        } catch (err) {
            this.logger.error('OpenRouter verdict analysis failed', err);
            return {
                verdict: 'unverified',
                confidence: 'low',
                reason: 'Verdict analysis service is temporarily unavailable.',
                usedSources: [],
            };
        }
    }

    private async callOpenRouter(
        claim: string,
        sources: SearchSourceDto[],
    ): Promise<VerdictResult> {
        const sourcesText = sources
            .slice(0, 10)
            .map(
                (s, i) =>
                    `[${i + 1}] ${s.isTrusted ? '(TRUSTED) ' : ''}${s.title}\n${s.snippet}`,
            )
            .join('\n\n');

        const prompt = `You are a professional fact-checker. Analyze the following claim against the provided sources and return a structured JSON verdict.

CLAIM:
"${claim}"

SOURCES:
${sourcesText}

INSTRUCTIONS:
- verdict must be exactly one of: "true", "false", or "unverified"
- confidence must be exactly one of: "low", "medium", or "high"
- reason should be 1–2 sentences explaining your verdict
- usedSources should list up to 3 sources you relied on, with a short justification each
- Trusted sources carry more weight than non-trusted sources
- If sources conflict or are insufficient, use "unverified"

Respond ONLY with a valid JSON object — no markdown, no extra text.`;

        const response = await fetch(this.openRouterEndpoint, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${this.openRouterApiKey}`,
                'Content-Type': 'application/json',
                // Optional OpenRouter specific headers
                'HTTP-Referer': 'https://your-app-url.com', 
                'X-Title': 'Fact Checker App',
            },
            body: JSON.stringify({
                model: this.model,
                messages: [{ role: 'user', content: prompt }],
                temperature: 0.1,
                max_tokens: 512,
                // Forces the model to output JSON if supported (e.g., Gemini/GPT-4)
                response_format: { type: 'json_object' }
            }),
        });

        if (!response.ok) {
            const errorBody = await response.text();
            throw new Error(`OpenRouter API error ${response.status}: ${errorBody}`);
        }

        const data = await response.json();
        const rawText: string = data.choices?.[0]?.message?.content ?? '';

        return this.parseResponse(rawText);
    }

    private parseResponse(raw: string): VerdictResult {
        const clean = raw
            .replace(/```json\s*/gi, '')
            .replace(/```\s*/g, '')
            .trim();

        try {
            const parsed = JSON.parse(clean);

            return {
                verdict: (['true', 'false', 'unverified'] as const).includes(parsed.verdict)
                    ? parsed.verdict
                    : 'unverified',
                confidence: (['low', 'medium', 'high'] as const).includes(parsed.confidence)
                    ? parsed.confidence
                    : 'low',
                reason: typeof parsed.reason === 'string' ? parsed.reason.trim() : 'No reason provided.',
                usedSources: Array.isArray(parsed.usedSources)
                    ? parsed.usedSources.slice(0, 3).filter((s: any) => s?.title && s?.justification)
                    : [],
            };
        } catch {
            this.logger.warn(`Could not parse LLM response: ${raw}`);
            return {
                verdict: 'unverified',
                confidence: 'low',
                reason: 'Could not parse the analysis response.',
                usedSources: [],
            };
        }
    }
}