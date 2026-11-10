// 1. mengecek pola relasi 
MATCH (a)-[r]->(b)
RETURN labels(a) AS dari, type(r) AS relasi, labels(b) AS ke, count(*) AS total
ORDER BY total DESC;

// 2. pemeriksaan Tipe Data & Format (cek tipe userId, rating, timestamp)
MATCH (u:User)-[r:RATED]->(m:Movie)
RETURN u.userId AS userId, r.rating AS rating, r.timestamp AS ts, m.title AS title
LIMIT 5;

// 3. node Genre
MATCH (g:Genre) RETURN keys(g) AS props, g LIMIT 5;

// 4. konversi tipe data: rating & timestamp pada dataset ini tersimpan sebagai STRING,
//     sehingga stDev() error dan perbandingan rating >= 4.0 menghasilkan null.
:auto
MATCH ()-[r:RATED]->()
WHERE r.rating IS :: STRING OR r.timestamp IS :: STRING
CALL (r) {
  SET r.rating = toFloat(r.rating),
      r.timestamp = toInteger(r.timestamp)
} IN TRANSACTIONS OF 10000 ROWS;

// 5. verifikasi tipe (harus FLOAT dan INTEGER)
MATCH ()-[r:RATED]->()
RETURN valueType(r.rating) AS tipeRating, valueType(r.timestamp) AS tipeTimestamp, count(*) AS total;

// 6. constraint & index untuk mempercepat lookup
CREATE CONSTRAINT user_id_unique IF NOT EXISTS FOR (u:User) REQUIRE u.userId IS UNIQUE;
CREATE CONSTRAINT movie_id_unique IF NOT EXISTS FOR (m:Movie) REQUIRE m.movieId IS UNIQUE;
CREATE INDEX movie_title_idx IF NOT EXISTS FOR (m:Movie) ON (m.title);
