-- 06_huecos_mensuales.sql
-- Diagnostico de huecos: meses SIN dato dentro del rango propio de cada serie
-- (entre su primer y su ultimo mes). Usa un calendario generado con un CTE
-- recursivo + JOIN + GROUP BY. Es la verificacion que respalda por que las
-- variaciones a 12 meses se calculan con ventanas RANGE y no con LAG(12).
WITH RECURSIVE cal(mes) AS (
    SELECT '2003-01-01'
    UNION ALL
    SELECT date(mes, '+1 month') FROM cal WHERE mes < '2026-12-01'
),
rango AS (
    SELECT codigo, MIN(mes) AS d, MAX(mes) AS h
    FROM v_obs_mensual
    GROUP BY codigo
)
SELECT s.alias,
       COUNT(*)     AS meses_sin_dato,
       MIN(c.mes)   AS primer_hueco,
       MAX(c.mes)   AS ultimo_hueco
FROM series_catalogo s
JOIN rango r ON r.codigo = s.codigo
JOIN cal c   ON c.mes BETWEEN r.d AND r.h
LEFT JOIN v_obs_mensual m ON m.codigo = s.codigo AND m.mes = c.mes
WHERE m.mes IS NULL
GROUP BY s.alias
ORDER BY s.alias;
