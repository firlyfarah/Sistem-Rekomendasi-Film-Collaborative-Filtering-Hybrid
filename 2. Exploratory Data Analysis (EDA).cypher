// 1. ukuran graph
MATCH (u:User) WITH count(u) AS users
MATCH (m:Movie) WITH users, count(m) AS movies
MATCH (g:Genre) WITH users, movies, count(g) AS genres
MATCH ()-[r:RATED]->() 
RETURN users, movies, genres, count(r) AS ratings;

// 2. distribusi rating dan persentase 
MATCH ()-[r:RATED]->()
WITH r.rating AS rating, count(*) AS total
WITH collect({rating: rating, total: total}) AS rows, sum(total) AS grand
UNWIND rows AS row
RETURN row.rating AS rating, row.total AS total,
       round(100.0 * row.total / grand, 2) AS pct
ORDER BY rating;

// 3. statistik deskriptif rating
MATCH ()-[r:RATED]->()
RETURN count(r) AS n, round(avg(r.rating), 3) AS mean,
       round(stDev(r.rating), 3) AS stdev,
       min(r.rating) AS minR, max(r.rating) AS maxR,
       percentileCont(r.rating, 0.5) AS median;

// 4. top 10 user paling aktif
MATCH (u:User)-[r:RATED]->()
RETURN u.userId AS userId, count(r) AS jumlahRating, round(avg(r.rating), 2) AS rataRating
ORDER BY jumlahRating DESC LIMIT 10;

// 5. distribusi tingkat aktivitas user
MATCH (u:User)-[r:RATED]->()
WITH u, count(r) AS n, avg(r.rating) AS avgR
WITH CASE WHEN n < 20 THEN '<20'
          WHEN n < 50 THEN '20-49'
          WHEN n < 100 THEN '50-99'
          WHEN n < 500 THEN '100-499'
          ELSE '500+' END AS kategori, n, avgR
RETURN kategori, min(n) AS minN, count(*) AS jumlahUser, round(avg(avgR), 2) AS rataRating
ORDER BY minN;

// 6. film paling banyak di-review
MATCH (m:Movie)<-[r:RATED]-()
RETURN m.title AS title, count(r) AS jumlahRating, round(avg(r.rating), 2) AS rataRating
ORDER BY jumlahRating DESC LIMIT 10;

// 7. film rating tertinggi (minimal 50 rating)
MATCH (m:Movie)<-[r:RATED]-()
WITH m, count(r) AS n, avg(r.rating) AS avgR
WHERE n >= 50
RETURN m.title AS title, n, round(avgR, 2) AS rataRating
ORDER BY rataRating DESC, n DESC LIMIT 10;

// 8. sparsity (kelangkaan / kekosongan data) matriks user-film
MATCH (u:User) WITH count(u) AS TotalUser
MATCH (m:Movie) WITH TotalUser, count(m) AS TotalMovie
MATCH ()-[r:RATED]->() WITH TotalUser, TotalMovie, count(r) AS TotalRated
RETURN TotalUser, TotalMovie, TotalRated, round(100.0 * (1 - toFloat(TotalRated) / (TotalUser * TotalMovie)), 2) AS sparsityPct;

// 9. tren rating per tahun (asumsi timestamp = epoch detik)
MATCH ()-[r:RATED]->()
RETURN datetime({epochSeconds: toInteger(r.timestamp)}).year AS tahun, count(*) AS total
ORDER BY tahun;
