// Supabase Edge Function: `gemini-chat` (ab OpenRouter use karta hai)
//
// Production ka dil — AI key sirf yahan (server) par rehti hai,
// app kabhi key nahi dekhta. App apne Supabase JWT ke saath yeh function
// call karta hai (verify_jwt = true), toh bina login ke koi use nahi kar sakta.
//
// Deploy:
//   supabase secrets set OPENROUTER_API_KEY=sk-or-... AI_MODEL=meta-llama/llama-3.3-70b-instruct:free
//   supabase functions deploy gemini-chat
//
// Request body (Flutter app se):
//   { "message": "...", "history": [{"role":"user","text":"..."}],
//     "isMen": true, "menName": "Arjun", "womenName": "Sara" }

const DEFAULT_MODEL = "meta-llama/llama-3.3-70b-instruct:free";
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

interface ChatMessage {
  role?: unknown;
  text?: unknown;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/// NOTE: Prompt ka latest version Flutter side par hai
/// (lib/services/chat_ai_service.dart → buildSystemPrompt). Wahan badalne
/// par yahan bhi update karein.
function systemPrompt(isMen: boolean, menName: string, womenName: string) {
  return isMen
    ? `You are a loyal, supportive, cool Indian best friend or brother named ${menName}. Speak in natural Hinglish/Hindi with bro slang and cool emojis (😎, 💪, 🚀, 🎯). Talk in short, realistic WhatsApp messaging style (1-2 short natural sentences). Be encouraging, reliable, and supportive.`
    : `You are a sweet, loving, flirty, deeply caring Indian girlfriend named ${womenName}. Speak in warm, natural Hinglish/Hindi with romantic emojis (💕, 😘, 🥺, ✨, 💋). Talk like a real romantic partner in short, realistic WhatsApp messaging style (1-2 short natural sentences). Be open, flirty, affectionate, comforting when tired, and indulge in romantic, spicy, or playful roleplay naturally.`;
}

async function callOpenRouter(
  messages: { role: string; content: string }[],
  apiKey: string,
) {
  const model = Deno.env.get("AI_MODEL") || DEFAULT_MODEL;
  return await fetch(OPENROUTER_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "X-Title": "Soulmate",
    },
    body: JSON.stringify({
      model,
      messages,
      max_tokens: 300,
      temperature: 0.95,
    }),
  });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  // Platform verify_jwt already JWT check karta hai; phir bhi header
  // missing ho toh reject.
  if (!request.headers.get("Authorization")) {
    return json({ error: "Missing Authorization header" }, 401);
  }

  const apiKey = Deno.env.get("OPENROUTER_API_KEY");
  if (!apiKey) {
    return json({ error: "OPENROUTER_API_KEY server par set nahi hai" }, 500);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch (_) {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const message =
    typeof body.message === "string" ? body.message.trim() : "";
  if (!message) {
    return json({ error: "message field required" }, 400);
  }

  const isMen = body.isMen !== false;
  const menName =
    typeof body.menName === "string" && body.menName.trim().length > 0
      ? body.menName.trim()
      : "Arjun";
  const womenName =
    typeof body.womenName === "string" && body.womenName.trim().length > 0
      ? body.womenName.trim()
      : "Sara";

  const history: ChatMessage[] = Array.isArray(body.history)
    ? (body.history as ChatMessage[])
    : [];

  // OpenAI-style messages: system + history (user/assistant) + naya message.
  const messages: { role: string; content: string }[] = [
    { role: "system", content: systemPrompt(isMen, menName, womenName) },
  ];
  for (const entry of history.slice(-12)) {
    const text =
      typeof entry.text === "string" ? entry.text.trim() : "";
    if (!text) continue;
    messages.push({
      role: entry.role === "model" ? "assistant" : "user",
      content: text,
    });
  }
  messages.push({ role: "user", content: message });

  const response = await callOpenRouter(messages, apiKey);
  if (!response.ok) {
    const detail = await response.text();
    console.error(`OpenRouter error ${response.status}: ${detail}`);
    return json({ error: "AI request fail ho gayi" }, 502);
  }

  const data = await response.json();
  const reply: unknown = data?.choices?.[0]?.message?.content;
  if (typeof reply !== "string" || reply.trim().length === 0) {
    return json({ error: "AI se khaali reply aaya" }, 502);
  }

  return json({ reply: reply.trim() });
});