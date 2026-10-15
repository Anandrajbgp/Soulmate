# Soulmate — Production Setup (Google Login + Real AI Chat via OpenRouter)

App me **3 layers** hain (order ke hisaab se):

| Layer | Kab chalta hai |
|---|---|
| **Supabase Edge Function** (`gemini-chat`) — OpenRouter key server par | Google login + Supabase configured + function deployed |
| **Direct OpenRouter API** (build-time `OPENROUTER_API_KEY`) | Key `--dart-define` di ho |
| **Local fallback engine** (offline demo replies) | Upar wale dono na hon |

Google login ke turant baad user ka Supabase JWT session ban jaata hai —
usi se edge function securely call hota hai, **user ko API key daalni nahi
padti**. Login screen se "Continue as Guest" bhi chal sakta hai.

App package id: **`com.odlix.soulmate`** (Android + iOS dono).

---

## Step 1 — Google Cloud Console (OAuth)

1. [console.cloud.google.com](https://console.cloud.google.com) → naya project.
2. **APIs & Services → OAuth consent screen** → External → app name
   `Soulmate`, email bharo → **Test users** me apni Gmail add karo
   (publish se pehle sirf test users hi login kar sakte hain).
3. **APIs & Services → Credentials → Create credentials → OAuth client ID**,
   teen client banao:

   **(a) Web application** (Supabase ke liye — sabse zaroori):
   - Name: `Soulmate Web`
   - Authorized redirect URIs:
     `https://<PROJECT-REF>.supabase.co/auth/v1/callback`
   - **Client ID** aur **Client Secret** copy karo.

   **(b) Android**:
   - Package name: `com.odlix.soulmate`
   - SHA-1 (debug keystore, aapki machine):
     `D5:6B:93:B1:14:E3:EA:59:86:A3:2F:07:BC:B7:41:33:4B:75:EF:40`
   - ⚠️ Release APK ke liye **upload-keystore ka SHA-1** bhi add karna hoga:
     `keytool -list -v -keystore <upload-keystore>.jks -alias <alias>`
     (warna release build me Google login fail hoga)

   **(c) iOS** (jab iOS build karo):
   - Bundle id: `com.odlix.soulmate`
   - Client ID ka **REVERSED_CLIENT_ID** (jaise
     `com.googleusercontent.apps.XXXX-....`) → `ios/Runner/Info.plist` →
     `CFBundleURLSchemes` me `REVERSED_CLIENT_ID_YAHAN_DALEIN` ki jagah paste.

## Step 2 — Supabase (login session + edge function)

1. [supabase.com](https://supabase.com) → naya project.
2. **Project Settings → API** → `Project URL` aur `anon public` key note karo.
3. **Authentication → Providers → Google** → Enable → woh **Web client ID
   aur Secret** (Step 1a) paste → Save.
4. (Optional) **Authentication → URL Configuration → Redirect URLs** me
   `https://<PROJECT-REF>.supabase.co/auth/v1/callback` allow ho chahiye.

## Step 3 — OpenRouter key (AI)

1. [openrouter.ai](https://openrouter.ai/keys) → sign-in → **Create Key**.
   (Ek key se GPT, Claude, Llama, DeepSeek sab milte hain. Free model chahiye
   toh `AI_MODEL` me `:free` wali id use karein.)
2. Supabase CLI se (server path — key app me nahi aati):
   ```sh
   supabase link --project-ref <PROJECT-REF>
   supabase secrets set OPENROUTER_API_KEY=sk-or-... AI_MODEL=meta-llama/llama-3.3-70b-instruct:free
   supabase functions deploy gemini-chat
   ```
   Ya dashboard: **Edge Functions → gemini-chat** → code
   `supabase/functions/gemini-chat/index.ts` se paste → **Secrets** me
   `OPENROUTER_API_KEY` (+ optional `AI_MODEL`) add → Deploy.

Default model `meta-llama/llama-3.3-70b-instruct:free` hai. Badalna ho toh
secret (ya `AI_MODEL` define) me openrouter.ai/models ki koi bhi id set karein,
jaise `openai/gpt-4o-mini`.

## Step 4 — App chalao

**Aasan tarika (VS Code):** project root ki `dart_defines.json` me apni values
bhar dein (URL, anon key, Web client ID) — file gitignored hai, keys commit
nahi hoti. Phir VS Code me **Run → Start Debugging** (F5) → config chunein
**Soulmate (Debug)**. Empty values rahengi toh app Guest + Local AI mode me
chalega.

**Manual tarika:**

```sh
flutter run `
  --dart-define=SUPABASE_URL=https://<PROJECT-REF>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=eyJ... `
  --dart-define=GOOGLE_WEB_CLIENT_ID=<WEB_CLIENT_ID>.apps.googleusercontent.com `
  --dart-define=OPENROUTER_API_KEY=sk-or-... `
  --dart-define=AI_MODEL=meta-llama/llama-3.3-70b-instruct:free
```

- Pehle 3 defines = Google login (Supabase + Google client). **Production me
  inhe CI/build script me rakhein, git me nahi.**
- `OPENROUTER_API_KEY` + `AI_MODEL` = direct AI path. **Optional** — sirf tab
  do jab edge function deploy na ho. Production me key mat do, warna APK se
  mil jaati hai (server path rakhein).
- Kuch bhi configure na ho toh app Guest + Local AI mode me chalta hai.

Release build:
```sh
flutter build apk --release --dart-define=... (upar wale sab)
```

## Verification checklist

- [ ] Login screen par **Sign in with Google** → Google account chunta hai →
      chat screen khulta hai (koi error snackbar nahi).
- [ ] Drawer → **Account Status** me email + `Gemini AI • cloud connected`
      dikh raha hai.
- [ ] Chat me message bhejo → 5s baad AI ka **real** Hinglish reply aata hai
      (pehle waala conversation yaad rakh ke).
- [ ] Logout → dobara login → purani chat wapas.
- [ ] Do alag Google accounts → unki chats alag (per-user storage).

## Tests

```sh
flutter analyze   # 0 issues
flutter test      # 8 tests pass
```
