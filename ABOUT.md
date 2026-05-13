# Sprintify App

# Deskripsi
Aplikasi yang dikembangkan merupakan sistem evaluasi kecepatan lari 60 meter berbasis mobile yang terintegrasi dengan perekaman video, analisis computer vision, serta sistem pendukung keputusan untuk memberikan penilaian dan rekomendasi latihan. Pengguna memulai dari halaman awal (splash screen) yang menampilkan identitas aplikasi, kemudian masuk melalui halaman login untuk mengakses sistem. Setelah berhasil masuk, pengguna diarahkan ke dashboard yang berfungsi sebagai pusat navigasi utama, menampilkan ringkasan aktivitas serta akses cepat untuk memulai tes lari atau melihat hasil sebelumnya. Pengguna terlebih dahulu mengelola data atlet atau siswa melalui halaman khusus yang menyediakan fitur penambahan, pengeditan, dan penyimpanan data sebagai subjek pengujian.

Sebelum melakukan pengambilan data, pengguna akan melalui halaman persiapan tes yang berisi pemilihan atlet serta pengaturan metode pengujian menggunakan perekaman video. Selanjutnya, proses inti dilakukan pada halaman recording, di mana aplikasi merekam aktivitas lari menggunakan kamera perangkat secara langsung. Video yang dihasilkan kemudian dikirim ke sistem backend untuk diproses. Selama proses analisis berlangsung, pengguna akan melihat halaman processing yang menampilkan status pemrosesan data secara real-time hingga hasil siap ditampilkan.

Hasil utama ditampilkan pada halaman hasil lari yang menyajikan informasi waktu tempuh serta kategori performa berdasarkan parameter tertentu. Untuk analisis yang lebih mendalam, pengguna dapat mengakses halaman analisis detail yang menampilkan hasil pengolahan computer vision, seperti momen start dan finish, serta indikator teknis lainnya yang relevan. Berdasarkan data tersebut, sistem kemudian memberikan rekomendasi pada halaman khusus yang memanfaatkan metode sistem pendukung keputusan untuk menyarankan perbaikan atau latihan yang perlu dilakukan. Dengan alur yang terstruktur ini, aplikasi tidak hanya berfungsi sebagai alat ukur kecepatan, tetapi juga sebagai sistem evaluasi dan pendukung peningkatan performa lari secara komprehensif.

# Halaman/Pages

🧩 1. Core Pages (Wajib) — ± 8–10 halaman
1. Splash Screen
Logo aplikasi / instansi
Loading awal
2. Login / Register
Login user (guru/pelatih/admin)
Bisa pakai email/password atau Google
3. Dashboard (Home)

👉 Halaman utama setelah login

Isi:

Tombol:
“Mulai Tes Lari”
“Lihat Hasil”
Ringkasan:
total percobaan
performa terakhir
4. Data Atlet / Siswa

👉 CRUD data siswa

Fitur:

Tambah siswa
Edit / hapus
Detail siswa

Field:

Nama
Umur
Jenis kelamin
Kelas (opsional)
5. Halaman Persiapan Tes

👉 Sebelum recording dimulai

Isi:

Pilih siswa
Pilih mode:
Video saja
Instruksi:
posisi kamera
jarak 60m
6. Halaman Recording (Camera Page)

👉 Ini halaman paling penting

Fitur:

Record video
Timer (opsional)

Output:

Video dikirim ke backend
7. Halaman Processing

👉 Setelah upload video

Isi:

Loading / progress:
“Sedang menganalisis video…”
Status:
CV processing
scoring

💡 Bisa pakai polling ke backend

8. Halaman Hasil Lari

👉 Output utama sistem

Isi:

Waktu tempuh (misalnya: 9.2 detik)
Kategori:
Baik / cukup / kurang
Grafik sederhana
9. Halaman Analisis Detail

👉 Dari computer vision

Isi:

Frame penting (start & finish)
(Opsional):
jumlah langkah
kecepatan rata-rata
Highlight:
posisi tubuh
10. Halaman Rekomendasi (SPK)

👉 Nilai tambah skripsi kamu

Isi:

Rekomendasi:
“Perlu latihan start”
“Perbaiki langkah”
Skor evaluasi:
teknik
kecepatan
Bisa pakai:
rule-based
atau metode SPK