# Technote: Unexpected Conversational State Retention in GPT4All API Server with DeepSeek-R1-Distill-Qwen-7B

**Date:** 2026-07-27  
**Status:** Confirmed / Model-specific  
**Affects:** GPT4All local API server (tested on v3.10.0) + DeepSeek-R1-Distill-Qwen-7B  
**Severity:** Medium (privacy / multi-user isolation risk)  
**Related Project:** RENT-A-HAL (multi-user speech interface)

---

## Summary

When using the GPT4All local API server with the model **DeepSeek-R1-Distill-Qwen-7B**, the server retains and re-injects previous conversation turns into subsequent requests — even when the client sends only a single-message payload containing no history.

This creates the appearance that the 7B model has persistent multi-turn memory without RAG and without the client supplying context. The behavior is **model-specific** (Llama 3 / 3.2 models under identical conditions do not exhibit it), **process-scoped**, and **shared across all clients and users**.

---

## Observed Behavior

- The RENT-A-HAL client always sends a minimal payload of the form:
  ```json
  {
    "model": "DeepSeek-R1-Distill-Qwen-7B",
    "messages": [{"role": "user", "content": "<current utterance only>"}],
    "max_tokens": ...,
    "temperature": 0.7
  }
  ```

- Despite this, the model correctly recalls specific facts established in earlier turns, including:
  - Fictional details (e.g., a favorite planet named “Ork”)
  - Previously discussed U.S. states (including Ohio)
  - Multi-topic summaries of conversations that occurred hours earlier

- Key characteristics of the retained context:
  - Survives across different clients (desktop browser → mobile browser)
  - Is shared across different users of the multi-user system
  - Is completely cleared by a full restart of the GPT4All process
  - Does **not** appear when the identical client and server configuration is used with Llama 3 8B Instruct or Llama 3.2 3B Instruct

- LocalDocs was examined and ruled out as the source of the recalled content.

---

## Experimental Controls

| Control | Result |
|---------|--------|
| Client sends only single-message payloads | Confirmed — no history is ever transmitted by RENT-A-HAL |
| Full process restart of GPT4All | All retained context is wiped |
| Switch to Llama 3 / 3.2 models | No retention occurs |
| Different client (mobile) after desktop conversation | Context remains available |
| Different user sessions on the same GPT4All instance | Context is shared globally |
| LocalDocs collection present | Content of recalled conversations not present in indexed documents |

---

## Root Cause Analysis

The GPT4All local API server appears to maintain a long-lived conversation object (most likely the special “Server” chat visible at the bottom of the chat sidebar) for the DeepSeek model path. Incoming API requests for this model are appended to that existing history rather than being treated as isolated, stateless requests.

This behavior is inconsistent with:

- The OpenAI-compatible API contract (which is expected to be stateless)
- Observed behavior of the same server when serving Llama-family models
- Typical community reports, which more commonly describe the opposite problem (API server failing to retain history even when the client supplies it)

The most plausible technical mechanisms are:

1. Residual / persistent use of the Server chat object specifically for DeepSeek requests
2. Incomplete reset of `n_past` or the KV cache on the DeepSeek chat-template code path
3. Interaction between the DeepSeek-specific Jinja chat template (including the regex that strips `<think>` blocks from prior assistant messages) and GPT4All’s internal session handling

The model weights themselves are not responsible. A transformer only attends to tokens present in its current context window; the surprising element is that GPT4All is still supplying prior-turn tokens on every request.

---

## Implications for RENT-A-HAL

RENT-A-HAL is designed as a multi-user speech interface with per-user isolation. Because the retained context inside GPT4All is **global** to the process:

- Conversation content from User A can leak into responses given to User B
- Private or identifying information is not isolated between users
- The system violates the expectation of clean per-user conversational state

This constitutes a privacy and correctness risk whenever DeepSeek-R1-Distill-Qwen-7B is selected as the active backend model.

---

## Recommendations

### Short-term
- Prefer Llama-family models when strict multi-user isolation is required.
- Document this behavior in operator / deployment notes.
- Consider emitting a startup warning when the configured GPT4All model is detected to be a DeepSeek variant.

### Medium-term
- Investigate whether GPT4All exposes any reliable API or UI mechanism to force a context reset on the Server chat.
- Evaluate moving DeepSeek inference to a truly stateless backend (llama.cpp server, Ollama with explicit per-session control, etc.) if the current memory behavior is undesirable.

### Upstream
- This appears to be an uncommon and previously under-documented edge case. A clear, reproducible report to the GPT4All project (nomic-ai/gpt4all) would be valuable for maintainers.

---

## Reproduction Steps

1. Launch GPT4All with the local API server enabled and load **DeepSeek-R1-Distill-Qwen-7B**.
2. From any client, establish several specific facts across multiple turns (the client must send only the current utterance each time).
3. From a different client or under a different user identity, ask about those facts.
4. Observe correct recall of the earlier details.
5. Fully quit and restart GPT4All → the retained context is gone.
6. Repeat the identical sequence with a Llama 3 model → no retention occurs.

---

## Conclusion

The observed “memory” is not an emergent capability of the 7B model, nor is it provided by RENT-A-HAL or LocalDocs. It is residual conversational state maintained by the GPT4All local API server specifically on the DeepSeek model path.

While the behavior can produce impressively coherent multi-turn interactions, it breaks multi-user isolation and should be treated as a known hazard until upstream behavior is clarified or mitigated.

---

*This technote was produced from controlled experiments conducted on 2026-07-27 while integrating DeepSeek-R1-Distill-Qwen-7B into the RENT-A-HAL multi-user speech interface.*
