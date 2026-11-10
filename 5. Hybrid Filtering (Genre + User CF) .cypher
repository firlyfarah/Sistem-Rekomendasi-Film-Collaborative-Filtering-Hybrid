// NOTES: HYBRID RECOMMENDER (USER CF + GENRE AFFINITY)
// tujuan: Menghasilkan skor rekomendasi gabungan (Hybrid Score) untuk 1 target user ($userId).
// 
// ALUR TAHAP:
// (a) Profil Genre: Menghitung persentase (share) genre favorit yang sering disukai target user
// (b) User Similarity: Mencari 30 user lain yang seleranya paling mirip menggunakan Jaccard Index
// (c) Kandidat Film: Mengumpulkan film-film (rating >= 4.0) dari 30 user serupa yang belum pernah ditonton target user
// (d) Normalisasi CF: Mengubah skor Collaborative Filtering (cfScore) ke skala 0 sampai 1
// (e) Scoring Hybrid: Menggabungkan 60% bobot CF + 40% bobot Genre Preference menjadi 'hybridScore'

// (a) Profil genre target user
MATCH (t:User {userId: $userId})-[r:RATED]->(:Movie)-[:HAS]-(g:Genre)
WHERE r.rating >= 4.0
WITH t, coalesce(g.name, g.genre) AS genre, count(*) AS cnt
WITH t, collect({genre: genre, cnt: cnt}) AS raw, sum(cnt) AS total
WITH t, [x IN raw | {genre: x.genre, share: toFloat(x.cnt) / total}] AS prefs

// (b) User serupa (Jaccard)
MATCH (t)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(o:User)
WHERE r1.rating >= 4.0 AND r2.rating >= 4.0 AND o <> t
WITH t, prefs, o, count(m) AS irisan
WHERE irisan >= 3
WITH t, prefs, o, irisan,
     COUNT { (t)-[x:RATED]->() WHERE x.rating >= 4.0 } AS likedT,
     COUNT { (o)-[y:RATED]->() WHERE y.rating >= 4.0 } AS likedO
WITH t, prefs, o, toFloat(irisan) / (likedT + likedO - irisan) AS jaccard
ORDER BY jaccard DESC LIMIT 30

// (c) Kandidat film + skor CF
MATCH (o)-[r:RATED]->(rec:Movie)
WHERE r.rating >= 4.0 AND NOT (t)-[:RATED]->(rec)
WITH prefs, rec, sum(jaccard) AS cfScore, count(DISTINCT o) AS pendukung
WHERE pendukung >= 2

// (d) Normalisasi CF ke 0..1
WITH prefs, collect({rec: rec, cf: cfScore, sup: pendukung}) AS rows, max(cfScore) AS maxCf
UNWIND rows AS row
WITH prefs, row.rec AS rec, row.cf / maxCf AS cfNorm, row.sup AS pendukung

// (e) Genre affinity
WITH rec, cfNorm, pendukung, prefs,
     [(rec)-[:HAS]-(g:Genre) | coalesce(g.name, g.genre)] AS genres
WITH rec, cfNorm, pendukung, genres,
     reduce(s = 0.0, x IN prefs | s + CASE WHEN x.genre IN genres THEN x.share ELSE 0.0 END) AS genreScore

RETURN rec.title AS rekomendasi, genres,
       round(cfNorm, 3) AS cfScore, round(genreScore, 3) AS genreScore, pendukung,
       round(0.6 * cfNorm + 0.4 * genreScore, 4) AS hybridScore
ORDER BY hybridScore DESC LIMIT 10;
