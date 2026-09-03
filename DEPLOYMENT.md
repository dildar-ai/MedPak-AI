# MedPak AI — Setup & Deployment Guide

Share MedPak AI with anyone via two free public URLs:

- **Backend** → Hugging Face Spaces (Docker, 16 GB RAM — runs FastAPI + OCR + RAG)
- **Frontend** → Vercel (React/Vite static build)

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

---

## 3. Deploy the Backend to Hugging Face Spaces (free, permanent)

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
https://<your-hf-username>-medpak-ai-backend.hf.space/api/health
```

> Notes: free Spaces sleep after ~48 h idle (first request after sleep takes ~30 s).
> Storage is ephemeral — user accounts and cached prices reset on restart
> (the medicine database itself is baked into the image). The first OCR scan
> after a restart downloads model weights (~1–2 min).

---

## 4. Deploy the Frontend to Vercel (free, permanent)

```bash
cd frontend
npm i -g vercel      # once
vercel               # first-time login + project link
```

Set the environment variable (Vercel dashboard → Settings → Environment Variables,
or when prompted):

| Name | Value |
|---|---|
| `VITE_API_BASE_URL` | `https://<your-hf-username>-medpak-ai-backend.hf.space/api` |

Then ship it:

```bash
vercel --prod
```

You now have a public link like `https://medpak-ai.vercel.app` — share it anywhere.

---

## 5. Environment Variables Reference (backend)

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

## 6. Live Price System

Prices are scraped from Pakistani pharmacy websites (Dvago product pages +
search engines) and cached in 3 tiers:

1. **In-memory** (instant, resets on restart)
2. **SQLite `live_prices.db`** (persists, 72 h freshness)
3. **Live scrape** (real-time, updates both tiers)

Strength-aware queries (`Risek 20mg price in Pakistan`), pack-size parsing
(`Rs. 193.20 for 21 caps`), and same-form/same-salt-set comparisons keep prices
accurate. Database prices are never shown — only verified live prices.

---

## 7. Architecture

```
Frontend (React/Vite)          Backend (FastAPI, HF Spaces)
  Vercel / localhost:5173  →     /api/*  (JWT auth)
                                      ├── Groq GPT-OSS 120B (LLM, RAG chat)
                                      ├── ChromaDB + MiniLM (semantic search)
                                      ├── EasyOCR (medicine box scanning)
                                      ├── SQLite pharmapedia.db (23k brands)
                                      └── Live price scrapers (Dvago + SERP)
```

---

*MedPak AI — Smart Medicine Information, Better Health*
