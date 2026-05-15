## to do
- tambah deteksi posisi tubuh bersedia dan berlari berdasarkan data-data dari json(file json dummy boleh dibuat dulu), untuk kode deteksi bersedia/berlari ini dibuat jadi modul/file tersendiri
- buatkan penilaian lari berdasarkan poin-poin berikut
-> nilai posisi bersedia(total nilai setiap frame posisi bersedia dibagi total frame bersedia)
-> nilai posisi berlari(total nilai setiap frame lari dibagi total frame lari)

penilaian ini, terjadi ketika submit rekaman video, berikut alurnya
1. rekam video dan simpan hasil timer
2. video tiap frame nya dideteksi posisi bersedia/berlari, jika tidak keduanya maka kosongkan
3. nilai setiap frame berdasarkan posisi nya, dan dapatkan total nilai kedua posisi tersebut
4. ambil frame dengan posisi bersedia terbaik dan posisi berlari terbaik, lalu feed ke gemini LLM API untuk menilai dari gambar-gambar tersebut
5. dari nilai tiap posisi yang didapatkan, buatkan rekomendasi berbasis if else sederhana
6. tampilkan hasil review dan rekomendasi dari gemini dan hasil yang if else(tapi di aplikasi jangan bilant if else)

catatan cara penilaian posisi bersiap/berlari dengan cara membandingkannya dengan file-file json yang berisikan data-data bone atau pose yang bersedia atau berlari yang benar

selain itu, buatkan .env.example terkait GEMINI_API_KEY, GEMINI_MODEL_ID, dan terkair firestore authentication(untuk sementara dibuatkan dulu)
