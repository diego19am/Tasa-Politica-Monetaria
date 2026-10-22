-- 04_resumen_por_bloque.sql
-- Calidad de datos: cobertura y faltantes por serie, agrupados por bloque tematico.
-- JOIN (series -> bloques, series -> observaciones) + GROUP BY.
-- n_obs = 0 indica extraccion fallida; "ultimo_dato" antiguo indica serie
-- descontinuada; "desde" reciente indica historia insuficiente.
-- Los faltantes de las series diarias son fines de semana y feriados.
SELECT b.bloque, s.alias, s.frecuencia, s.unidad,
       COUNT(o.valor) AS n_obs,
       SUM(CASE WHEN o.valor IS NULL THEN 1 ELSE 0 END) AS n_faltantes,
       MIN(o.fecha) AS desde,
       MAX(CASE WHEN o.valor IS NOT NULL THEN o.fecha END) AS ultimo_dato
FROM series_catalogo s
JOIN bloques b            ON b.bloque_id = s.bloque_id
LEFT JOIN observaciones o ON o.codigo = s.codigo
GROUP BY b.bloque, s.alias, s.frecuencia, s.unidad
ORDER BY b.bloque_id, s.alias;
