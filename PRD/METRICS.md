# METRIK Keberhasilan — JosJob (bahan diskusi team meet)

> **Status:** BELUM DISEPAKATI. Dokumen ini adalah bahan diskusi untuk team
> meet berikutnya, bukan keputusan. **Tidak ada target angka di sini** —
> target hanya boleh ditulis setelah tim menyepakatinya, dengan baseline dan
> sumber data yang jelas. Jangan mengarang nilainya.
>
> Format tiap metrik mengikuti rincian tugas di Notion: baseline, target,
> sumber data, pemilik, dan periode pengukuran.

## 1. Kenapa dokumen ini terpisah?

Metrik adalah gap terbesar PRD ini. Daripada mengarang target di PRD utama,
metrik dipisah ke dokumen ini supaya bisa dibahas khusus di team meet
berikutnya — lalu hasilnya ditulis kembali ke sini dan ke `PRD.md` §11.

## 2. Kandidat metrik (bukan target)

### 2.1 Kualitas AI / ranking

| Metrik | Definisi yang diusulkan | Sumber data (usulan) | Pemilik (usulan) |
| --- | --- | --- | --- |
| Waktu upload CV → ranking tampil | Waktu dari upload selesai sampai ranking + penjelasan tampil | Log backend (timestamp) | backdev |
| % CV berhasil diekstrak | CV dengan status `done`/`partial` dibagi semua CV yang diupload | Tabel analisis CV | backdev |
| % CV tidak terbaca | CV dengan status `unreadable` dibagi semua CV yang diupload | Tabel analisis CV | backdev |
| Relevansi ranking | Penilaian manual: apakah 5 teratas memang relevan untuk CV tersebut? (skala 1–5, dinilai tim/penguji) | Uji manual dengan CV + lowongan synthetic | tim (belum diputuskan siapa) |
| % ranking dengan penjelasan lengkap | Item ranking yang punya `match_score` + `missing_skills` + `explanation` | Log/DB hasil ranking | backdev |

**Pertanyaan diskusi:** berapa CV dan lowongan synthetic yang dipakai untuk
uji relevansi? Siapa yang menilai? Berapa skor minimum yang dianggap
"berhasil"?

### 2.2 Alur pengguna

| Metrik | Definisi yang diusulkan | Sumber data (usulan) | Pemilik (usulan) |
| --- | --- | --- | --- |
| CTR ranking → detail | Klik kartu lowongan dibagi tampilnya ranking | Analitik frontend / log | frontdev |
| Tingkat penyelesaian apply | Apply selesai dibagi apply dimulai | Log backend | backdev |
| Klik hook kursus | Klik "skill hilang → kursus" dibagi tampilnya skill hilang | Analitik frontend / log | frontdev |
| Enroll setelah melihat gap | Enroll ke kursus yang dibuka dari hook skill hilang | Tabel enrollment | backdev |
| % user yang menjawab lokasi | User yang menjawab pertanyaan lokasi dibagi semua user yang ditanya | Local/browser + log (hati-hati privasi) | frontdev |

**Pertanyaan diskusi:** apakah analitik frontend perlu dibangun, atau cukup
log backend? Bagaimana mengukur tanpa melanggar privasi (tidak ada tracking
lintas situs, tidak ada data pribadi di analitik)?

### 2.3 Keandalan AI

| Metrik | Definisi yang diusulkan | Sumber data (usulan) | Pemilik (usulan) |
| --- | --- | --- | --- |
| % analisis yang memakai fallback | Analisis yang jatuh ke 9Router / keyword dibagi semua analisis | Provenance per analisis | backdev |
| % analisis gagal total | Status `failed` dibagi semua analisis | Tabel analisis CV | backdev |
| Konsistensi skor | Ranking yang sama untuk CV + lowongan yang sama pada dua kali proses (diuji dengan model yang di-pin) | Uji manual | backdev |

**Pertanyaan diskusi:** berapa besar ketidakkonsistenan dari round-robin
yang masih dapat diterima? Apakah demo memakai model yang di-pin?

### 2.4 Demo / lomba (bukan metrik produk)

| Metrik | Definisi yang diusulkan |
| --- | --- |
| Core flow jalan end-to-end saat demo | Ya/tidak (upload CV → ranking + penjelasan → apply), diuji manual sebelum Final Day |
| Jumlah peserta uji fase 3 | Belum diputuskan — lihat PRD v1: "phase-3 trial N" masih terbuka |

## 3. Yang harus diputuskan di team meet

1. Metrik mana yang dipakai (pilih 3–5 saja — jangan semuanya).
2. Baseline tiap metrik (diukur dari apa? uji manual pertama? nol?).
3. Target tiap metrik (angka + tanggal).
4. Pemilik tiap metrik.
5. Periode pengukuran (misal: selama product improvement 7–16 Des, atau
   selama uji internal sebelum semifinal 30 Nov).
6. Cara mengukur relevansi ranking tanpa mengarang angka.

## 4. Aturan

- Target yang belum disepakati **tidak boleh** ditulis di PRD, proposal,
  atau deck.
- Angka BPS dan angka dampak lain hanya boleh dipakai setelah diverifikasi
  ke sumber resmi.
- Data demo (synthetic) tidak boleh dilaporkan seolah-olah data pengguna
  nyata.
