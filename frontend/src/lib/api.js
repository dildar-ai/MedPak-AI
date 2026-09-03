import axios from 'axios';

/** Dev uses Vite proxy (/api → backend). Production: set VITE_API_BASE_URL at build time. */
const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL ??
  (import.meta.env.DEV ? '/api' : 'http://127.0.0.1:8000/api');

// ── Auth storage ─────────────────────────────────────────────────────────────

const TOKEN_KEY = 'medpak_token';
const USER_KEY = 'medpak_user';

export const authStorage = {
  getToken: () => localStorage.getItem(TOKEN_KEY),
  getUser: () => {
    try {
      return JSON.parse(localStorage.getItem(USER_KEY));
    } catch {
      return null;
    }
  },
  set: (token, user) => {
    localStorage.setItem(TOKEN_KEY, token);
    localStorage.setItem(USER_KEY, JSON.stringify(user));
  },
  clear: () => {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
  },
};

// ── Axios instance ───────────────────────────────────────────────────────────

const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Attach the JWT to every request when signed in
api.interceptors.request.use((config) => {
  const token = authStorage.getToken();
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// On 401 (expired/invalid token) — drop credentials and tell the app to show
// the login screen. A 401 from /auth/login itself means wrong credentials and
// must NOT trigger the logout flow.
api.interceptors.response.use(
  (response) => response,
  (error) => {
    const status = error.response?.status;
    const url = error.config?.url || '';
    if (status === 401 && !url.startsWith('/auth/')) {
      authStorage.clear();
      window.dispatchEvent(new Event('medpak:unauthorized'));
    }
    return Promise.reject(error);
  }
);

// ── Auth API ─────────────────────────────────────────────────────────────────

export const authApi = {
  register: async (email, username, password) => {
    const response = await api.post('/auth/register', { email, username, password });
    return response.data;
  },

  login: async (email, password) => {
    const response = await api.post('/auth/login', { email, password });
    return response.data;
  },

  me: async () => {
    const response = await api.get('/auth/me');
    return response.data;
  },
};

// ── Medicine API ─────────────────────────────────────────────────────────────

export const medicineApi = {
  search: async (query) => {
    const response = await api.get(`/medicine/search?q=${encodeURIComponent(query)}`);
    return response.data;
  },

  scan: async (imageFile) => {
    const formData = new FormData();
    formData.append('file', imageFile);

    const response = await api.post('/medicine/scan', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
      timeout: 60000,
    });
    return response.data;
  },

  getDetails: async (drugId, brandName = null) => {
    const url = brandName
      ? `/medicine/${drugId}?brand=${encodeURIComponent(brandName)}`
      : `/medicine/${drugId}`;
    const response = await api.get(url);
    return response.data;
  },

  getAlternatives: async (drugId, brandName = null) => {
    const url = brandName
      ? `/medicine/${drugId}/alternatives?brand=${encodeURIComponent(brandName)}`
      : `/medicine/${drugId}/alternatives`;
    const response = await api.get(url);
    return response.data;
  },

  checkInteractions: async (drugId1, drugId2) => {
    const response = await api.get(`/medicine/interactions/${drugId1}/${drugId2}`);
    return response.data;
  },

  chat: async (message, drugId, sessionId = null) => {
    const response = await api.post('/medicine/chat', {
      message,
      drug_id: drugId,
      session_id: sessionId,
    }, { timeout: 60000 });
    return response.data;
  },

  getLivePrice: async (brandName, strength = null) => {
    let url = `/medicine/live-price?brand=${encodeURIComponent(brandName)}`;
    if (strength) url += `&strength=${encodeURIComponent(strength)}`;
    const response = await api.get(url);
    return response.data;
  },

  refreshPrices: async (brandName, strength = null) => {
    const response = await api.post('/medicine/prices/refresh', {
      brand: brandName,
      ...(strength ? { strength } : {}),
    });
    return response.data;
  },
};


export const chatApi = {
  sendMessage: async (message, sessionId = null) => {
    const response = await api.post('/chat/message', {
      message,
      session_id: sessionId,
    });
    return response.data;
  },

  getHistory: async (sessionId) => {
    const response = await api.get(`/chat/history/${sessionId}`);
    return response.data;
  },

  getSessions: async () => {
    const response = await api.get('/chat/sessions');
    return response.data;
  }
};
