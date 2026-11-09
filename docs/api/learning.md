# Learning API Contract (Catalog + Enrollment)

Student-facing endpoints for browsing the course catalog and managing enrollments.

- **Base URL** (local dev): `http://localhost:4000`
- All requests/responses are JSON. Successful bodies use a `{ "data": … }` envelope;
  errors use `{ "error": "<code>" }`.
- **All endpoints require** an access-token Bearer header (the JWT from
  [`auth.md`](./auth.md), pipeline `:api_auth`):
  ```
  Authorization: Bearer <token>
  ```
  Missing/invalid/refresh token → `401 { "error": "unauthorized" }`.
- Data is **org-scoped**: a user only sees courses/classes for organizations where they
  are an **active member**. Courses must also be `is_active`.

---

## GET /api/catalog/courses

Active courses shared to the current user's organizations.

**Response `200`**
```json
{
  "data": [
    {
      "id": "c7a8b9c0-…",
      "title": "Go Programming",
      "description": "…",
      "section": { "id": "…", "name": "Technology Information" },
      "industries": [ { "id": "…", "name": "Software & IT" } ],
      "class_count": 2
    }
  ]
}
```

---

## GET /api/catalog/courses/:id

Course detail with its classes (only those in the user's orgs) and materials.

- `404 { "error": "not_found" }` when the course is inactive or not shared to the user's org.

**Response `200`**
```json
{
  "data": {
    "id": "…",
    "title": "Go Programming",
    "description": "…",
    "section": { "id": "…", "name": "Technology Information" },
    "industries": [ { "id": "…", "name": "Software & IT" } ],
    "materials": [
      { "id": "…", "title": "Instalasi Go", "url": "https://…", "mime_type": "application/pdf", "description": "…" }
    ],
    "classes": [
      {
        "id": "…",
        "title": "Batch Sabtu Pagi",
        "schedule": [
          { "start_date": "2026-08-01T09:00", "end_date": "2026-08-01T10:00", "recurring": false }
        ],
        "capacity": 10,
        "seats_left": 7,
        "instructor": { "id": "…", "full_name": "Budi" },
        "enrolled": false,
        "materials": [
          { "id": "…", "title": "Slide", "url": "https://…", "mime_type": "application/pdf", "description": null }
        ]
      }
    ]
  }
}
```

- `seats_left` is `null` when the class capacity is unlimited, otherwise
  `capacity − active enrollments` (never below 0).
- `enrolled` = whether the current user is enrolled in that class.
- per-class `materials` = course materials **plus** the instructor's own materials.

---

## POST /api/classes/:id/enroll

Enroll the current user into a class.

- **`201`**
  ```json
  { "data": { "enrollment_id": "…", "class_id": "…", "status": "active" } }
  ```
- **`404` `{ "error": "not_found" }`** — class missing or not in one of the user's orgs.
- **`409` `{ "error": "already_enrolled" }`** — the user is already enrolled in this class.
- **`409` `{ "error": "full" }`** — the class has reached its capacity.

---

## DELETE /api/classes/:id/enroll

Remove the current user's enrollment for a class.

- **`200`** `{ "data": { "ok": true } }`
- **`404` `{ "error": "not_enrolled" }`** — the user has no enrollment in this class.

---

## GET /api/me/enrollments

The current user's enrollments (newest first).

**Response `200`**
```json
{
  "data": [
    {
      "id": "…",
      "status": "active",
      "enrolled_at": "2026-07-22T09:00:00.000000Z",
      "class": {
        "id": "…",
        "title": "Batch Sabtu Pagi",
        "schedule": [
          { "start_date": "2026-08-01T09:00", "end_date": "2026-08-01T10:00", "recurring": false }
        ],
        "course": { "id": "…", "title": "Go Programming" }
      }
    }
  ]
}
```

- `status` is one of `"active"` | `"completed"`.
