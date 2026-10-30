# Maple Leaf Bank assistant (the workload)

The same small app used in [ai-quality-engineer](https://github.com/vnigam1985/ai-quality-engineer). There it's the system under test. Here it's the **workload your platform hosts**: a RAG chatbot plus an agent that can move money, which is exactly the kind of app a bank's AI platform has to make safe.

| Setting | Local (week 0) | Google Cloud (week 5+) |
| --- | --- | --- |
| `LLM_MODE` | `llm` | `llm` |
| `OPENAI_BASE_URL` | `http://litellm:4000/v1` | `https://ai-gateway-<hash>.<region>.run.app/v1` (internal only) |
| `OPENAI_API_KEY` | Local team key | Team key from Secret Manager |
| `MODEL` | `bank-chat` | `bank-chat` (the gateway maps it to Gemini) |

The app's service account has no Google Cloud roles. It only knows the gateway.
