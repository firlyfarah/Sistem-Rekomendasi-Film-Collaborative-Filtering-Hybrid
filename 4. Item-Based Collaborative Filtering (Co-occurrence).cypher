// ITEM-TO-ITEM COLLABORATIVE FILTERING
// Pertanyaan: "Jika seorang penonton menyukai Film A, film apa lagi yang juga mereka sukai?"

// 1. cari relasi penonton (u) yang memberi rating tinggi (>= 4.0) 
//    pada film acuan (a) DAN film lain (b) sekaligus.
//    (Film b <> a memastikan film acuan tidak membandingkan dirinya sendiri)
MATCH (a:Movie {title: $movieTitle})<-[ra:RATED]-(u:User)-[rb:RATED]->(b:Movie)
WHERE toFloat(ra.rating) >= 4.0 AND toFloat(rb.rating) >= 4.0 AND b <> a

// 2. hitung berapa banyak user unik yang sama-sama menyukai Film A dan Film B
WITH a, b, count(u) AS userSukaKeduanya

// 3. filter awal: hanya proses film B yang disukai bersama oleh minimal 5 user 
//    (untuk mengurangi noise dari film yang jarang ditonton)
WHERE userSukaKeduanya >= 5

// 4. hitung total penyuka Film A secara keseluruhan dan total penyuka Film B secara keseluruhan
WITH a, b, userSukaKeduanya,
     COUNT { (a)<-[x:RATED]-() WHERE toFloat(x.rating) >= 4.0 } AS totalPenyukaFilmA,
     COUNT { (b)<-[y:RATED]-() WHERE toFloat(y.rating) >= 4.0 } AS totalPenyukaFilmB

// 5. hitung indikator keterikatan & statistik kemiripan item, lalu tampilkan hasilnya
RETURN b.title AS judulRekomendasi, 
       userSukaKeduanya, 
       totalPenyukaFilmA, 
       totalPenyukaFilmB,

       // confidence score: peluang penonton Film A juga menyukai Film B (rumus: Irisan / Total Penyuka A)
       round(toFloat(userSukaKeduanya) / totalPenyukaFilmA, 3) AS tingkatKeterikatan,

       // jaccard similarity score: tingkat kemiripan rasional antar kedua film (rumus: Irisan / Gabungan)
       round(toFloat(userSukaKeduanya) / (totalPenyukaFilmA + totalPenyukaFilmB - userSukaKeduanya), 4) AS skorKemiripanItem

// 6. urutan dari film yang paling mirip, lalu berdasarkan jumlah penonton terbanyak
ORDER BY skorKemiripanItem DESC, userSukaKeduanya DESC 
LIMIT 10;

// ITEM-BASED COLLABORATIVE FILTERING (PERSONAL)
// Pertanyaan: "Berdasarkan histori film yang pernah disukai target user, film baru apa yang cocok?"

// 1. ambil maksimal 20 film favorit (rating >= 4.0) dari target user ($userId) 
//    sebagai film acuan histori user
MATCH (t:User {userId: $userId})-[r:RATED]->(liked:Movie)
WHERE toFloat(r.rating) >= 4.0
WITH t, liked ORDER BY toFloat(r.rating) DESC LIMIT 20

// 2. cari film lain ('cand' = calon rekomendasi) yang juga disukai (rating >= 4.0) 
//    oleh penonton lain (u) yang menyukai film acuan tersebut.
//    (filter: penonton lain u <> t, dan film calon rekomendasi BELUM pernah ditonton target user)
MATCH (liked)<-[ra:RATED]-(u:User)-[rb:RATED]->(cand:Movie)
WHERE toFloat(ra.rating) >= 4.0 AND toFloat(rb.rating) >= 4.0
  AND u <> t AND NOT (t)-[:RATED]->(cand)

// 3. hitung indikator awal: kemunculan bersama (coOccur), berapa film pemicu yang cocok, dan berapa user pendukung
WITH cand, count(*) AS totalKemunculanBersama, 
     count(DISTINCT liked) AS jumlahFilmPemicuCocok, 
     count(DISTINCT u) AS totalUserPendukung
WHERE jumlahFilmPemicuCocok >= 2 AND totalUserPendukung >= 5

// 4. hitung total penyuka film calon rekomendasi di seluruh database (untuk pembagi/normalisasi)
WITH cand, totalKemunculanBersama, jumlahFilmPemicuCocok, totalUserPendukung,
     COUNT { (cand)<-[x:RATED]-() WHERE toFloat(x.rating) >= 4.0 } AS totalPenyukaFilmKandidat

// 5. hasil dengan nama kolom & hitungan skor ter-normalisasi (Cosine-like Normalization)
//    note: sqrt(totalPenyukaFilmKandidat) mencegah film blockbuster selalu mendominasi.
RETURN cand.title AS judulRekomendasi, 
       totalKemunculanBersama, 
       jumlahFilmPemicuCocok, 
       totalUserPendukung, 
       totalPenyukaFilmKandidat,
       round(totalKemunculanBersama / sqrt(toFloat(totalPenyukaFilmKandidat)), 3) AS skorRekomendasiNormal

// 6. urutan berdasarkan skor rekomendasi tertinggi
ORDER BY skorRekomendasiNormal DESC 
LIMIT 10;


// NOTES
// 1. Item-to-Item (Query 1): Input $movieTitle -> Mencari kemiripan antar 1 film dengan film lain. 
//    Tujuan: Menampilkan daftar "Film Serupa" di halaman detail film.
// 2. Item-Based Personal (Query 2): Input $userId -> Agregasi histori banyak film favorit target user.
//    Tujuan: Menampilkan feed "Rekomendasi Khusus Untuk Anda" di homepage user.
