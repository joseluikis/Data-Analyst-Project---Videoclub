SELECT F.Film_id,
	F.Title AS Nombre,
	C.Name AS Categoria,
	COUNT(DISTINCT I.inventory_id) AS Número_de_Copias,
	COUNT(R.Rental_id) AS Número_de_Alquileres,
    SUM(P.Amount) AS Ingresos_Totales,
    SUM(P.Amount) / COUNT(DISTINCT I.inventory_id) AS RIU,
	COUNT(R.Rental_id) / COUNT(DISTINCT I.inventory_id) AS ARU

FROM Film F
JOIN Film_Category FC
ON F.Film_id = FC.Film_id
JOIN Category C
ON FC.Category_id = C.Category_id
LEFT JOIN Inventory I
ON F.Film_id = I.Film_id
LEFT JOIN Rental R
ON I.Inventory_id = R.Inventory_id
LEFT JOIN Payment P
ON R.rental_id = P.rental_id

GROUP BY F.Film_id, F.Title, C.Name
ORDER BY F.Film_id;

WITH 
-- 1) Copias por película
Copias AS (
  SELECT 
    i.film_id,
    COUNT(DISTINCT i.inventory_id) AS Copias
  FROM inventory i
  GROUP BY i.film_id
),

-- 2) Alquileres por día
alquileres_diarios AS (
  SELECT 
    i.film_id,
    DATE(r.rental_date) AS fecha,
    COUNT(*) AS alquileres_dia
  FROM rental r
  JOIN inventory i ON r.inventory_id = i.inventory_id
  GROUP BY i.film_id, DATE(r.rental_date)
),

-- 3) Marcar días con ruptura
stockout_diario AS (
  SELECT 
    d.film_id,
    d.fecha,
    d.alquileres_dia,
    c.copias,
    CASE WHEN d.alquileres_dia >= c.copias THEN 1 ELSE 0 END AS stockout_dia
  FROM alquileres_diarios d
  JOIN copias c USING (film_id)
),

-- 4) KPI de ruptura por película
kpi_stockout AS (
  SELECT 
    film_id,
    SUM(stockout_dia) AS Stockout_Dias,
    COUNT(*) AS Dias_Con_Demanda,
    ROUND(SUM(stockout_dia) / NULLIF(COUNT(*),0), 4) AS Stockout_Days_Ratio
  FROM stockout_diario
  GROUP BY film_id
)

-- 5) Tu query original + unión con stockout
SELECT 
    F.Film_id,
    F.Title AS Nombre,
    C.Name AS Categoria,
    COUNT(DISTINCT I.inventory_id) AS Numero_de_Copias,
    COUNT(R.Rental_id) AS Numero_de_Alquileres,
    SUM(P.Amount) AS Ingresos_Totales,

    -- Tus KPIs
    ROUND(SUM(P.Amount) / NULLIF(COUNT(DISTINCT I.inventory_id),0),2) AS RIU,
    ROUND(COUNT(R.Rental_id) / NULLIF(COUNT(DISTINCT I.inventory_id),0),2) AS ARU,

    -- Nuevo KPI
    ks.Stockout_Dias,
    ks.Dias_Con_Demanda,
    ks.Stockout_Days_Ratio

FROM Film F
JOIN Film_Category FC ON F.Film_id = FC.Film_id
JOIN Category C       ON FC.Category_id = C.Category_id
LEFT JOIN Inventory I ON F.Film_id = I.Film_id
LEFT JOIN Rental R    ON I.Inventory_id = R.Inventory_id
LEFT JOIN Payment P   ON R.rental_id   = P.rental_id
LEFT JOIN kpi_stockout ks ON F.film_id = ks.film_id

GROUP BY F.Film_id, F.Title, C.Name, ks.Stockout_Dias, ks.Dias_Con_Demanda, ks.Stockout_Days_Ratio
ORDER BY F.Film_id;
