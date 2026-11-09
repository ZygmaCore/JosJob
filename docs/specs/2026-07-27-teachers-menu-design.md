# Spec: Menu Teachers (admin)

Tanggal: 2026-07-27
Status: disetujui (brainstorm 2026-07-27); **revisi saat implementasi: aksi
Delete DIBATALKAN** — `Class.instructor_id` non-nullable (Ash + DB), sehingga
"lepaskan dari class" butuh migrasi schema; user memutuskan membatalkan delete.
Menu ini rilis sebagai list + detail (read-only). `teachers:manage` tetap
di-seed sebagai placeholder.

## Latar belakang

Admin org butuh melihat siapa saja pengajar di organisasinya beserta class yang
mereka ajar, tanpa menelusuri menu Memberships/Membership Roles/Classes satu
per satu. "Teacher" **bukan entitas baru** — ia adalah user dengan membership
`active` yang mengemban role `key == "teacher"` di sebuah org (pola yang sama
dengan pencarian pengajar di form class, lihat `teacher_users/1` di
`StellarWeb.Admin.ClassController`). Fitur ini murni view + dua aksi di atas
data yang sudah ada; tidak ada perubahan schema selain seed permission baru.

## Ruang lingkup

- Menu sidebar baru "Teachers" → `/teachers` (list) dan `/teachers/:id` (detail).
- Aksi Delete = cabut role teacher + lepaskan dia dari class yang diajar.
- Permission baru `teachers:read` dan `teachers:manage` (di-seed).

Di luar lingkup: CRUD user/membership (tetap di menu masing-masing), edit
class/jadwal dari halaman teacher (tetap di menu Classes), filter "class tanpa
pengajar" di list Classes (tindak lanjut terpisah bila perlu).

## Halaman list (`/teachers`)

Scope tenant mengikuti pola Classes:
- Non-superuser: hanya teacher di org aktif.
- Superuser: semua org, plus kolom "Tenant".

Kolom:

| Kolom | Isi |
|---|---|
| Nama | Nama lengkap user, email di baris kedua (satu sel) |
| Class | Judul class yang dia ajar **di org tsb** (instructor_id = user, organization_id = org); maks 3 judul, sisanya "+N lagi"; "-" bila belum mengajar |
| Tenant | Nama org (hanya superuser) |
| Aksi | Detail, Delete |

Teacher tanpa class tetap tampil (itu justru informasi penting).
User yang menjadi teacher di >1 org muncul satu baris per org (identitas baris
= pasangan org+user, bukan user saja).

## Halaman detail (`/teachers/:id`)

Read-only ("Detail", bukan "Edit"). `:id` = user id; org context = org aktif
(superuser: perlu param `org` bila user mengajar di lebih dari satu org —
link dari list sudah membawa org yang tepat).

- Header: nama, email, nama org.
- Daftar class yang dia ajar di org tsb, per class:
  - Judul class + judul course-nya.
  - Jumlah peserta: enrollment ber-status `active`; tampil "N" atau "N/kapasitas"
    bila `capacity` terisi.
  - Jadwal: render array `schedule` per sesi (hari/tanggal + jam, sesuai bentuk
    map yang dipakai form Classes).
  - Judul class menjadi link ke `/classes/:id/edit` bila user punya izin
    kelola class (cek `StellarWeb.Perms.can?` yang sama dengan list Classes).
- Tanpa form apa pun.

## Delete

Konfirmasi harus menyebut dampak: nama teacher dan daftar class yang akan
kehilangan pengajar, mis. *"Cabut role teacher dari X? N class berikut akan
kehilangan pengajar: A, B, C"*.

Eksekusi (transaksional, urutan bebas tapi harus keduanya):
1. Hapus baris `membership_roles` role-teacher milik membership user itu di org tsb.
2. Set `instructor_id = nil` pada semua class org tsb yang dia ajar.

Yang TIDAK disentuh: record user, membership (status tetap `active`), role lain
yang dia emban (mis. dia juga coordinator), enrollment, dan class di org lain.

Konsekuensi yang disadari: class jadi tanpa pengajar dan hanya terlihat dari
kolom Pengajar yang kosong — admin org bertanggung jawab menugaskan pengajar
baru lewat menu Classes.

## Akses & routing

- Seed permission: `teachers:read` (list + detail), `teachers:manage` (delete).
  `manage` = superset `read` mengikuti konvensi permission lain.
- Route `/teachers` (index, show, delete) di scope RBAC ber-plug permission,
  pola sama dengan `/classes`.
- Item `admin_nav` baru: key `:teachers`, gate `["teachers:read", "teachers:manage"]`.
- Superuser selalu lolos (permissions `:all`).

## Implementasi (arah, bukan rencana rinci)

- Controller baru `StellarWeb.Admin.TeacherController` (index, show, delete).
- Ekstrak helper privat pencarian teacher di `ClassController`
  (`teacher_users/1`, `teacher_membership_ids/1`, `active_user_ids/2`,
  `teacher_role_query/2`, `teacher_pairs/1`) ke modul bersama
  `StellarWeb.Teachers`, dipakai kedua controller — satu sumber kebenaran
  "siapa itu teacher".
- Query class per teacher: `Class` filter `organization_id` + `instructor_id`,
  load `course` + hitung enrollment aktif (pakai pola `seats_left`/count yang
  sudah ada di `StellarLrn.Learning`).

## Testing

Controller test (pola test admin yang sudah ada):
1. List ter-scope org aktif; teacher org lain tidak muncul; superuser melihat semua.
2. Kolom Class menampilkan judul class yang benar; teacher tanpa class tampil dengan "-".
3. User ber-role selain teacher tidak muncul.
4. Detail: jumlah peserta aktif benar (enrollment non-aktif tidak dihitung) dan jadwal tampil.
5. Delete: `membership_roles` terhapus, `instructor_id` class jadi nil, user +
   membership + role lain utuh; class di org lain tidak tersentuh.
6. Delete tanpa `teachers:manage` ditolak; list tanpa `teachers:read` ditolak.
7. Menu sidebar tampil/hilang sesuai permission (pola `admin_nav_test.exs`).
