# Kontrak API Auth (untuk klien Flutter)

Auth mobile memakai **JSON + JWT Bearer** (bukan cookie/redirect web).

- **Base URL** (dev lokal): `http://localhost:4000`
- Semua endpoint di bawah `Content-Type: application/json`.
- Respons login/register selalu: `{ user, token, refresh_token }`.
  - `token` = **access token** (JWT, umur ~1 jam).
  - `refresh_token` = umur panjang (~30 hari), sekali-pakai (rotasi).
  - `user` = `{ id, email, full_name, is_superuser }`.

Untuk endpoint terproteksi, kirim header:
```
Authorization: Bearer <token>
```

---

## POST /api/auth/register
Registrasi email + password.

**Request**
```json
{
  "full_name": "Budi Santoso",
  "email": "budi@example.com",
  "password": "minimal8char",
  "phone": "+628123456789",     // opsional
  "address": "Jl. ...",          // opsional
  "birthdate": "1995-08-17"       // opsional (YYYY-MM-DD)
}
```
Wajib: `full_name`, `email`, `password` (min 8 karakter). `email` case-insensitive & unik.

**201 Created**
```json
{
  "user": { "id": "uuid", "email": "budi@example.com", "full_name": "Budi Santoso", "is_superuser": false },
  "token": "eyJ...",
  "refresh_token": "eyJ..."
}
```

**Error**
- `400` — field wajib kurang: `{ "error": "full_name, email, dan password (min 8) wajib" }`
- `422` — validasi gagal (email sudah dipakai / password < 8):
  ```json
  { "error": "registrasi gagal", "details": [ { "field": "email", "message": "has already been taken" } ] }
  ```

---

## POST /api/auth/login
Login email + password.

**Request**
```json
{ "email": "budi@example.com", "password": "minimal8char" }
```

**200 OK** — sama bentuknya dengan register (`{ user, token, refresh_token }`).

**Error**
- `400` — `{ "error": "email dan password wajib" }`
- `401` — `{ "error": "email atau password salah" }` (tidak membocorkan apakah email ada).

---

## POST /api/auth/google
Login/registrasi via Google (SDK `google_sign_in` di device).

**Request**
```json
{ "id_token": "<id_token dari google_sign_in>" }
```

**200 OK** — `{ user, token, refresh_token }`. User dibuat otomatis bila belum ada; `full_name` & `avatar` diisi dari profil Google.

**Error**
- `400` — `{ "error": "id_token wajib" }`
- `401` — `{ "error": "unauthorized" }` (id_token invalid/expired/aud salah).

> ⚠️ **Penting (Flutter):** `id_token` harus punya **audience = `GOOGLE_CLIENT_ID`** yang divalidasi backend. Di `google_sign_in`, set **`serverClientId` = Web client ID** (bukan client Android/iOS). Kalau salah, backend menolak (401).

---

## POST /api/auth/refresh
Tukar refresh token dengan pasangan baru (refresh lama langsung **dicabut** — rotasi).

**Request**
```json
{ "refresh_token": "<refresh_token>" }
```

**200 OK**
```json
{ "user": {...}, "token": "eyJ...(baru)", "refresh_token": "eyJ...(baru)" }
```

**Error**
- `400` — `{ "error": "refresh_token wajib" }`
- `401` — refresh token invalid / sudah dirotasi / kadaluarsa.

---

## Alur klien (disarankan)
1. **Register/Login/Google** → simpan `token` + `refresh_token` di `flutter_secure_storage`.
2. Sisipkan `Authorization: Bearer <token>` di request terproteksi.
3. Bila dapat **401** karena token kadaluarsa → panggil `/api/auth/refresh` dengan `refresh_token` → simpan pasangan baru → ulangi request. Bila refresh juga 401 → paksa login ulang.
4. Logout = hapus token dari storage (server stateless untuk access token; refresh yang dipakai akan otomatis basi setelah rotasi/expired).

## Catatan
- Endpoint auth (`register/login/google/refresh`) **publik** (tanpa Bearer).
- Endpoint terproteksi (mis. `/api/payments/*`) butuh Bearer valid (plug `ApiAuth`).
- Profil tambahan (`phone/address/birthdate/interest/dst.`) bisa dilengkapi belakangan lewat endpoint profil (menyusul).
