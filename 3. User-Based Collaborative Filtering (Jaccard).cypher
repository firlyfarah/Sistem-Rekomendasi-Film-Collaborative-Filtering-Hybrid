:param userId => '414'; // user paling aktif merating
:param movieTitle => "Forrest Gump (1994)"; // movie dengan jumlah rating tertinggi

// 1. top 20 user paling mirip dengan target user
MATCH (t:User {userId: $userId})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(o:User)
WHERE r1.rating >= 4.0 AND r2.rating >= 4.0 AND o <> t
WITH t, o, count(m) AS irisan
WHERE irisan >= 3
WITH t, o, irisan,
     COUNT { (t)-[x:RATED]->() WHERE x.rating >= 4.0 } AS likedT,
     COUNT { (o)-[y:RATED]->() WHERE y.rating >= 4.0 } AS likedO
RETURN o.userId AS userMirip, irisan, likedT, likedO,
       round(toFloat(irisan) / (likedT + likedO - irisan), 4) AS jaccard
ORDER BY jaccard DESC LIMIT 20;

// 2. rekomendasi film: film yang disukai user mirip & belum dirating target
MATCH (t:User {userId: $userId})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(o:User)
WHERE r1.rating >= 4.0 AND r2.rating >= 4.0 AND o <> t
WITH t, o, count(m) AS irisan
WHERE irisan >= 3
WITH t, o, irisan,
     COUNT { (t)-[x:RATED]->() WHERE x.rating >= 4.0 } AS likedT,
     COUNT { (o)-[y:RATED]->() WHERE y.rating >= 4.0 } AS likedO
WITH t, o, toFloat(irisan) / (likedT + likedO - irisan) AS jaccard
ORDER BY jaccard DESC LIMIT 30

MATCH (o)-[r:RATED]->(rec:Movie)
WHERE r.rating >= 4.0 AND NOT (t)-[:RATED]->(rec)
WITH rec, sum(jaccard) AS skor, count(DISTINCT o) AS pendukung, avg(r.rating) AS rataRatingTetangga
WHERE pendukung >= 2
RETURN rec.title AS rekomendasi, round(skor, 4) AS skorCF, pendukung,
       round(rataRatingTetangga, 2) AS rataRatingTetangga
ORDER BY skor DESC, pendukung DESC LIMIT 10;
