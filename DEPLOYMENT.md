 # MedPak AI — Setup & Deployment Guide

Two ways to share MedPak AI:

- **Now — self-hosted demo (free, no card):** your PC runs the whole app and
  friends get a permanent ngrok URL. One URL serves everything — the backend
  also serves the built frontend (see §3).
- **Later — cloud deployment:** Hugging Face Space (backend) + Vercel
  (frontend). Note: since July 2026 HF requires a paid PRO plan to create
  Docker Spaces, so that path costs $9/month (cancel anytime).

---

## 1. Get a Free Groq API Key (the AI brain)

1. Go to [console.groq.com/keys](https://console.groq.com/keys)
2. Sign up (free) → **Create API Key** → copy it
3. Models used: `openai/gpt-oss-120b` (primary) + `openai/gpt-oss-20b` (fallback)

> The LLM layer uses the OpenAI-compatible endpoint, so it is provider-agnostic —
> you can point `GROQ_BASE_URL` / `GROQ_MODEL` / the API key at any compatible
> provider (e.g. Alibaba Cloud DashScope) without code changes.

---

## 2. Run Locally (development)

### Backend

```bash
cd backend
python -m venv venv
venv\Scripts\activate          # Windows
pip install -r requirements.txt

# Create .env (see backend/.env.example) with:
#   GROQ_API_KEY=gsk_xxx
#   SECRET_KEY=<python -c "import secrets; print(secrets.token_hex(32))">

python main.py                 # http://localhost:8000  (docs at /docs)
```

### Frontend

```bash
cd frontend
npm install
npm run dev                    # http://localhost:5173
```

The Vite dev server proxies `/api/*` to `http://127.0.0.1:8000` automatically.

> If `frontend/dist` exists (after `npm run build`), the backend serves the
> finished app at **http://localhost:8000** — no separate frontend server
> needed. That is the self-host mode used below.

---

## 3. Share a Live Test Link — Self-Hosted Demo (free, no card)

One process + one tunnel = one public URL. No CORS, no second host, no signup
walls — friends test the *full* app (OCR scanning and semantic search included,
since your PC has the RAM for them).

### Step 1 — One-time ngrok setup (email signup, no credit card)

1. Create a free account: [dashboard.ngrok.com/signup](https://dashboard.ngrok.com/signup)
2. Install: `winget install ngrok.ngrok`
3. `ngrok config add-authtoken <YOUR_TOKEN>` — token is shown at
   [dashboard.ngrok.com/get-started/your-authtoken](https://dashboard.ngrok.com/get-started/your-authtoken)
4. Claim your free **static domain** (a permanent URL):
   [dashboard.ngrok.com/domains](https://dashboard.ngrok.com/domains)

> If `ngrok` is "not recognized" after installing: winget added it to your
> user PATH, but windows that were already open keep the old PATH. Either
> fully close and reopen your terminal app — or ignore it: `start_demo.ps1`
> finds ngrok inside the winget package folder automatically.

### Step 2 — Build the frontend (once, and after any UI change)

```bash
cd frontend
npm run build
```

### Step 3 — Launch

Paste your static domain into `$NgrokDomain` at the top of `start_demo.ps1`
(repo root), then:

```powershell
powershell -ExecutionPolicy Bypass -File .\start_demo.ps1
```

The script starts the backend, waits for it, opens the tunnel and prints your
permanent public URL (it opens in your browser too).

### What testers experience

- First visit shows ngrok's one-time “You are about to visit…” page — click
  **Visit Site** (normal on the free plan; API calls already skip it)
- They register a MedPak AI account inside the app, then everything works:
  search, live prices, alternatives, OCR scan, chat
- Each visitor is rate-limited by their real IP (the tunnel forwards it)

### Ground rules

- **Keep the PC on and awake** while friends test — the app runs on your
  machine (Windows Settings → System → Power → set sleep to *Never* while
  plugged in during demo days)
- Close the ngrok window to stop sharing; the URL is static, so it comes back
  next time you run the script
- Free-plan limits: 1 GB of responses + 20k requests per month — far more than
  a test round needs
- Accounts your friends create live in your local
  `backend/database/users.db`

**Troubleshooting:** “Port 8000 busy” means a backend is already running — the
script reuses it. Tunnel errors usually mean a typo in `$NgrokDomain`.

---

## 4. Optional — Cloud Backend on Hugging Face Spaces ($9/month PRO)

> Since July 2026, creating a Docker or Gradio Space requires a paid PRO plan
> ($9/month, cancel anytime); CPU Basic hardware itself stays $0/hour. Skip
> this section unless you want the cloud copy — the self-hosted demo in §3 is
> the free path.

### Step 1 — Create the Space

1. Go to [huggingface.co/new-space](https://huggingface.co/new-space)
2. **Space name:** `medpak-ai-backend` · **SDK:** **Docker** · **Blank** template · **Public**
3. Create it (leave it empty)

### Step 2 — Push the backend code

From the `backend/` folder:

```powershell
.\deploy_to_hf.ps1 -HfUser <your-hf-username> -SpaceName medpak-ai-backend
```

When git asks for credentials: username = your HF username, password = an
**HF access token** with *write* permission ([settings/tokens](https://huggingface.co/settings/tokens)).

The script handles Git LFS automatically (the 15 MB medicine database exceeds
HF's 10 MB plain-git limit) and never uploads user accounts or local caches —
only source code, the medicine DB and the Dvago product index.

### Step 3 — Add secrets in the Space

Space → **Settings → Variables and secrets** → add:

| Name | Value |
|---|---|
| `GROQ_API_KEY` | `gsk_...` (your Groq key) |
| `SECRET_KEY` | any long random string (JWT signing) |
| `CORS_ORIGINS` | `["*"]` (JWT travels in the Authorization header, not cookies) |
| `DEBUG` | `false` |

### Step 4 — Wait for the build (~10–20 min first time)

The Docker image installs PyTorch + EasyOCR. When it finishes, verify:

```
https://<your-hf-username>-medpak-ai-backend.hf.space/api/health/
```

> Notes: free Spaces sleep after ~48 h idle (first request after sleep takes ~30 s).
> Storage is ephemeral — user accounts and cached prices reset on restart
> (the medicine database itself is baked into the image). The first OCR scan
> after a restart downloads model weights (~1–2 min).

---

## 5. Optional — Cloud Frontend on Vercel (free)

Only needed for the split cloud setup (§4 backend + this frontend). For the
self-hosted demo the backend already serves the frontend — skip Vercel.

### Step 1 — Import the repository

1. Go to [vercel.com](https://vercel.com) → **Sign Up** → continue with GitHub
   (this login is for *you, the developer* — your visitors will never see it)
2. **Add New… → Project** → find **MedPak-AI** → **Import**

### Step 2 — Configure the import (two things matter)

| Setting | Value |
|---|---|
| Framework Preset | Vite (auto-detected) |
| **Root Directory** | **`frontend`** — click *Edit* and select it. The repo root also holds `backend/`; skipping this is the #1 cause of failed builds |

Add this **Environment Variable** on the same screen:

| Name | Value |
|---|---|
| `VITE_API_BASE_URL` | `https://<your-hf-username>-medpak-ai-backend.hf.space/api` |

Leave Build Command and Output Directory at their defaults, click **Deploy**
(≈ 1 minute).

### Step 3 — Share the public URL

When the build finishes, open **Domains** — you get a link like
`https://medpak-ai.vercel.app`. It is **fully public**: anyone can open it,
register a MedPak AI account inside the app and start testing. **Vercel never
asks visitors to log in** — production URLs on `*.vercel.app` are open by default.

> Seeing a Vercel password screen anyway? That's "Deployment Protection",
> which only guards *preview* URLs on some plans. Fix it once:
> **Project → Settings → Deployment Protection → Disabled**, and share the
> *Production* URL from the Domains tab. Note: changing `VITE_API_BASE_URL`
> later requires a redeploy (Vite bakes it in at build time).

### CLI alternative

```bash
cd frontend
npm i -g vercel      # once
vercel               # first-time login + project link
vercel --prod        # ship to production
```

---

## 6. Environment Variables Reference (backend)

| Variable | Required | Default | Description |
|---|---|---|---|
| `GROQ_API_KEY` | Yes | — | Groq API key |
| `GROQ_BASE_URL` | No | `https://api.groq.com/openai/v1` | OpenAI-compatible endpoint |
| `GROQ_MODEL` | No | `openai/gpt-oss-120b` | Primary LLM |
| `GROQ_FALLBACK_MODEL` | No | `openai/gpt-oss-20b` | Fallback on rate limits |
| `SECRET_KEY` | Yes (prod) | dev default | JWT signing secret |
| `CORS_ORIGINS` | No | localhost list | JSON array of allowed origins |
| `DEBUG` | No | `true` | Set `false` in production |
| `OCR_USE_GPU` | No | `false` | CUDA only |

---

## 7. Live Price System

Prices are scraped from Pakistani pharmacy websites (Dvago product pages +
search engines) and cached in 3 tiers:

1. **In-memory** (instant, resets on restart)
2. **SQLite `live_prices.db`** (persists, 72 h freshness)
3. **Live scrape** (real-time, updates both tiers)

Strength-aware queries (`Risek 20mg price in Pakistan`), pack-size parsing
(`Rs. 193.20 for 21 caps`), and same-form/same-salt-set comparisons keep prices
accurate. Database prices are never shown — only verified live prices.

---

## 8. Architecture

```
Frontend (React/Vite)
  served by FastAPI (self-host) · Vercel (cloud) · :5173 (dev)
        ↓ /api/*  (JWT auth)
Backend (FastAPI)
  ├── Groq GPT-OSS 120B (LLM, RAG chat)
  ├── ChromaDB + MiniLM (semantic search)
  ├── EasyOCR (medicine box scanning)
  ├── SQLite pharmapedia.db (23k brands)
  └── Live price scrapers (Dvago + SERP)
```

---

*MedPak AI — Smart Medicine Information, Better Health*
