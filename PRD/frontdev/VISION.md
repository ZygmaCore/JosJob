# VISION Frontend — JosJob (rencana ke depan)

> Dokumen ini berisi rencana **setelah** hackathon / di luar scope MVP.
> Bukan untuk dikerjakan sekarang, kecuali tim memutuskan sebaliknya.

## 1. Ranking dinamis v2 (UI)

- Menampilkan sinyal baru dari backend v2: badge popularitas ("Populer di
  Bandung minggu ini"), slot eksplorasi (lowongan baru yang sengaja
  dimunculkan), dan penjelasan yang lebih kaya ("cocok karena 5/6 skill +
  lokasi + baru diposting").
- UI harus tetap menjelaskan kenapa tiap item di atas — jangan sampai v2
  membuat ranking tidak bisa dijelaskan lagi.

## 2. Mobile

- Mobile = codebase Flutter yang sama. Setelah web stabil, periksa:
  layout kartu lowongan di layar kecil, bottom navigation, upload CV dari
  file HP, dan performa di koneksi lambat.
- Jangan membuat aplikasi native terpisah.

## 3. Quiz dan asesmen (UI sudah ada, backend belum)

- `quiz/` saat ini UI-only dengan data sample. Bila backend quiz dibangun
  nanti (lihat `../backdev/VISION.md`), hubungkan UI ini ke backend dan
  hapus data sample-nya — jangan biarkan sample dan data nyata tercampur
  tanpa label.

## 4. Notifikasi dan progres belajar

- Bila backend menambah FCM/push atau progres belajar yang lebih kaya,
  tampilkan notifikasi lamaran (status berubah) dan progres kursus di
  dashboard. Sampai saat itu, notifikasi in-app via channel yang sudah ada
  sudah cukup.

## 5. Aksesibilitas dan polish

- Audit kontras, ukuran teks, navigasi keyboard, dan screen reader untuk
  alur utama (landing → ranking → apply).
- Micro-interaction dan loading state yang konsisten (ikuti pedoman UI/UX
  di `AGENTS.md` root repo).

## 6. Hal yang sengaja TIDAK ada di vision ini

- Copywriting/branding yang meniru Upwork atau Glints.
- Angka statistik karangan di landing.
- Fitur yang mengharuskan user membagikan lokasi presisi (geolocation API).
