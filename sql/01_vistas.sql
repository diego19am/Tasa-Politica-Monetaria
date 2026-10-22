-- =============================================================================
-- 01_vistas.sql  |  Hito 2 - Monitor de coyuntura (variable objetivo: TPM)
-- Vistas sobre las tablas: bloques, series_catalogo, observaciones.
-- Es idempotente: se puede ejecutar muchas veces (DROP VIEW IF EXISTS).
-- Ejecucion:  python src/aplicar_sql.py        (o desde el notebook)
--
-- Requisitos del Hito 2 que cubre este archivo:
--   * JOIN        -> v_obs_mensual, v_transformaciones, v_panel
--   * GROUP BY    -> v_obs_mensual (diario -> mensual), v_panel (pivote por mes)
--   * Ventanas    -> v_transformaciones (LAG y AVG con PARTITION BY codigo)
--
-- Regla de oro de las ventanas: SIEMPRE PARTITION BY codigo (cada serie por
-- separado) y SIEMPRE asegurar que la fila "de hace k meses" esta realmente
-- k meses atras. LAG(valor, 12) mira 12 FILAS atras; si a la serie le falta un
-- mes (BCP/BCU a 5 anos: oct-2022 a jun-2023; CPI EE.UU.: oct-2025), 12 filas
-- atras ya no son 12 meses atras. Por eso aqui se usa RANGE sobre un indice
-- mensual entero (ver seccion 2).
-- =============================================================================

DROP VIEW IF EXISTS v_panel_d12;
DROP VIEW IF EXISTS v_panel;
DROP VIEW IF EXISTS v_transformaciones;
DROP VIEW IF EXISTS v_obs_mensual;

-- -----------------------------------------------------------------------------
-- 1) Frecuencia mensual para TODAS las series (JOIN + GROUP BY)
--    * Series mensuales: se usan tal cual (fecha = primer dia del mes).
--    * Series diarias (TPM, BCP5, BCU5R): se toma el ULTIMO valor no nulo del
--      mes. Para una tasa de politica es lo correcto (la tasa vigente al cierre
--      del mes); para BCP/BCU es el dato de cierre de mes. El GROUP BY busca la
--      ultima fecha con dato de cada (serie, mes) y el JOIN recupera su valor.
--    * Los NULL (fines de semana/feriados que devuelve la API) se descartan.
-- -----------------------------------------------------------------------------
CREATE VIEW v_obs_mensual AS
SELECT o.codigo, o.fecha AS mes, o.valor
FROM observaciones o
JOIN series_catalogo s ON s.codigo = o.codigo
WHERE s.frecuencia = 'Mensual' AND o.valor IS NOT NULL
UNION ALL
SELECT o.codigo, strftime('%Y-%m-01', o.fecha) AS mes, o.valor
FROM observaciones o
JOIN series_catalogo s ON s.codigo = o.codigo AND s.frecuencia = 'Diaria'
JOIN (SELECT codigo, MAX(fecha) AS fecha_ult
      FROM observaciones
      WHERE valor IS NOT NULL
      GROUP BY codigo, strftime('%Y-%m', fecha)) u
  ON u.codigo = o.codigo AND u.fecha_ult = o.fecha;

-- -----------------------------------------------------------------------------
-- 2) Transformaciones por serie (FUNCIONES DE VENTANA con PARTITION BY codigo)
--    nivel          : valor mensual
--    pct_12m        : variacion % respecto del mismo mes del anio anterior
--    dif_12m        : diferencia absoluta en 12 meses (sirve para tasas, en pp)
--    dif_mensual    : diferencia respecto del mes anterior
--    var_12m        : "variacion interanual" de la serie en %:
--                       tipo 'indice'    -> pct_12m calculado aqui
--                       tipo 'variacion' -> el propio valor (ya es var. 12m)
--                       tipo 'nivel'     -> NULL (tasas, desempleo, tc: se usan en nivel)
--    media_movil_3m : promedio de los ultimos 3 meses del nivel
--    var_12m_mm3    : media movil de 3 meses de var_12m (suaviza el Imacec)
--
--    Como se evita el problema de los huecos: se ordena por `mnum` (anio*12+mes,
--    un entero) y se usa RANGE en vez de ROWS/LAG. "RANGE BETWEEN 12 PRECEDING
--    AND 12 PRECEDING" toma SOLO la fila cuyo mnum es exactamente 12 menos; si
--    ese mes no existe, la ventana queda vacia y FIRST_VALUE devuelve NULL.
--    Asi, un hueco solo anula los calculos que realmente lo necesitan.
--    (Primera version: LAG(.,12) + chequeo de fecha; funcionaba, pero tambien
--     anulaba meses calculables DESPUES de un hueco, p.ej. CPI EE.UU. tras oct-2025.)
-- -----------------------------------------------------------------------------
CREATE VIEW v_transformaciones AS
WITH b AS (
    SELECT m.codigo, s.alias, s.tipo, m.mes, m.valor AS nivel,
           CAST(strftime('%Y', m.mes) AS INTEGER) * 12
         + CAST(strftime('%m', m.mes) AS INTEGER) AS mnum
    FROM v_obs_mensual m
    JOIN series_catalogo s ON s.codigo = m.codigo
),
t AS (
    SELECT b.*,
           FIRST_VALUE(b.nivel) OVER w12 AS nivel_m12,
           FIRST_VALUE(b.nivel) OVER w1  AS nivel_m1
    FROM b
    WINDOW w12 AS (PARTITION BY b.codigo ORDER BY b.mnum
                   RANGE BETWEEN 12 PRECEDING AND 12 PRECEDING),
           w1  AS (PARTITION BY b.codigo ORDER BY b.mnum
                   RANGE BETWEEN 1 PRECEDING AND 1 PRECEDING)
),
t2 AS (
    SELECT t.codigo, t.alias, t.tipo, t.mes, t.mnum, t.nivel,
           (t.nivel / t.nivel_m12 - 1) * 100 AS pct_12m,
           t.nivel - t.nivel_m12             AS dif_12m,
           t.nivel - t.nivel_m1              AS dif_mensual,
           CASE t.tipo WHEN 'indice'    THEN (t.nivel / t.nivel_m12 - 1) * 100
                       WHEN 'variacion' THEN t.nivel END AS var_12m
    FROM t
)
SELECT t2.codigo, t2.alias, t2.tipo, t2.mes, t2.nivel,
       t2.pct_12m, t2.dif_12m, t2.dif_mensual, t2.var_12m,
       CASE WHEN COUNT(t2.nivel)   OVER w3 = 3 THEN AVG(t2.nivel)   OVER w3 END AS media_movil_3m,
       CASE WHEN COUNT(t2.var_12m) OVER w3 = 3 THEN AVG(t2.var_12m) OVER w3 END AS var_12m_mm3
FROM t2
WINDOW w3 AS (PARTITION BY t2.codigo ORDER BY t2.mnum
              RANGE BETWEEN 2 PRECEDING AND CURRENT ROW);

-- -----------------------------------------------------------------------------
-- 3) Panel mensual: una fila por mes, una columna por indicador
--    (JOIN implicito con v_transformaciones + GROUP BY mes para pivotear).
--    OJO con los nombres: en el catalogo los alias de las expectativas son
--    'eee_12m' y 'eee_24m' (historico), pero sus horizontes reales son 11 y 23
--    meses. En el panel se exponen como eee_11m y eee_23m.
--    Si renombran los alias en src/config.py, actualicen los dos CASE de abajo.
-- -----------------------------------------------------------------------------
CREATE VIEW v_panel AS
WITH base AS (
    SELECT t.mes,
        MAX(CASE WHEN t.alias='tpm'       THEN t.nivel       END) AS tpm,
        MAX(CASE WHEN t.alias='eee_12m'   THEN t.nivel       END) AS eee_11m,
        MAX(CASE WHEN t.alias='eee_24m'   THEN t.nivel       END) AS eee_23m,
        MAX(CASE WHEN t.alias='ipc_12m'   THEN t.var_12m     END) AS ipc_12m,
        MAX(CASE WHEN t.alias='ipc_sv'    THEN t.var_12m     END) AS ipc_sv_12m,
        MAX(CASE WHEN t.alias='imacec'    THEN t.var_12m     END) AS imacec_12m,
        MAX(CASE WHEN t.alias='imacec'    THEN t.var_12m_mm3 END) AS imacec_12m_mm3,
        MAX(CASE WHEN t.alias='desempleo' THEN t.nivel       END) AS desempleo,
        MAX(CASE WHEN t.alias='dolar'     THEN t.nivel       END) AS dolar,
        MAX(CASE WHEN t.alias='dolar'     THEN t.pct_12m     END) AS dolar_12m,
        MAX(CASE WHEN t.alias='tcr'       THEN t.nivel       END) AS tcr,
        MAX(CASE WHEN t.alias='bcp5'      THEN t.nivel       END) AS bcp5,
        MAX(CASE WHEN t.alias='bcu5r'     THEN t.nivel       END) AS bcu5r,
        MAX(CASE WHEN t.alias='cobre'     THEN t.nivel       END) AS cobre,
        MAX(CASE WHEN t.alias='fedfunds'  THEN t.nivel       END) AS fedfunds,
        MAX(CASE WHEN t.alias='cpi_usa'   THEN t.var_12m     END) AS cpi_usa_12m
    FROM v_transformaciones t
    GROUP BY t.mes
)
SELECT b.*,
    b.tpm - b.eee_11m  AS tpm_real_exante,   -- TPM menos expectativa a 11 meses
    b.tpm - b.ipc_12m  AS tpm_real_expost,   -- TPM menos inflacion observada
    b.ipc_12m - 3.0    AS brecha_inflacion,  -- meta de 3%
    b.eee_23m - 3.0    AS brecha_expectativas,
    b.tpm - b.fedfunds AS diferencial_fed,
    b.bcp5 - b.tpm     AS pendiente_5y,
    -- Brecha de actividad PROVISORIA: Imacec 12m menos su promedio historico
    -- expansivo (solo usa informacion pasada). Una sola serie, por eso no lleva
    -- PARTITION BY. Se reemplazara por un filtro HP one-sided en el Hito 3.
    b.imacec_12m - AVG(b.imacec_12m) OVER (ORDER BY b.mes
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS brecha_actividad
FROM base b
WHERE b.tpm IS NOT NULL
ORDER BY b.mes;

-- -----------------------------------------------------------------------------
-- 4) Diferencias a 12 meses del panel (para el analisis de rezagos, seccion 9)
--    Antes se calculaban en pandas con q - q.shift(12); ahora viven en SQL.
--    El panel tiene una fila por cada mes consecutivo (la TPM no tiene huecos),
--    asi que LAG(.,12) = 12 meses; el chequeo sobre `mes` lo deja explicito.
--    Si la columna tiene NULL en el mes o en el mes-12, la diferencia es NULL.
-- -----------------------------------------------------------------------------
CREATE VIEW v_panel_d12 AS
WITH w AS (
    SELECT p.*, LAG(p.mes, 12) OVER (ORDER BY p.mes) AS mes_m12 FROM v_panel p
)
SELECT w.mes,
    CASE WHEN w.mes_m12 = date(w.mes,'-12 months') THEN w.tpm        - LAG(w.tpm,        12) OVER (ORDER BY w.mes) END AS tpm,
    CASE WHEN w.mes_m12 = date(w.mes,'-12 months') THEN w.ipc_12m    - LAG(w.ipc_12m,    12) OVER (ORDER BY w.mes) END AS ipc_12m,
    CASE WHEN w.mes_m12 = date(w.mes,'-12 months') THEN w.ipc_sv_12m - LAG(w.ipc_sv_12m, 12) OVER (ORDER BY w.mes) END AS ipc_sv_12m,
    CASE WHEN w.mes_m12 = date(w.mes,'-12 months') THEN w.eee_11m    - LAG(w.eee_11m,    12) OVER (ORDER BY w.mes) END AS eee_11m,
    CASE WHEN w.mes_m12 = date(w.mes,'-12 months') THEN w.eee_23m    - LAG(w.eee_23m,    12) OVER (ORDER BY w.mes) END AS eee_23m,
    CASE WHEN w.mes_m12 = date(w.mes,'-12 months') THEN w.imacec_12m - LAG(w.imacec_12m, 12) OVER (ORDER BY w.mes) END AS imacec_12m,
    CASE WHEN w.mes_m12 = date(w.mes,'-12 months') THEN w.desempleo  - LAG(w.desempleo,  12) OVER (ORDER BY w.mes) END AS desempleo,
    CASE WHEN w.mes_m12 = date(w.mes,'-12 months') THEN w.fedfunds   - LAG(w.fedfunds,   12) OVER (ORDER BY w.mes) END AS fedfunds,
    CASE WHEN w.mes_m12 = date(w.mes,'-12 months') THEN w.dolar      - LAG(w.dolar,      12) OVER (ORDER BY w.mes) END AS dolar,
    CASE WHEN w.mes_m12 = date(w.mes,'-12 months') THEN w.cobre      - LAG(w.cobre,      12) OVER (ORDER BY w.mes) END AS cobre,
    CASE WHEN w.mes_m12 = date(w.mes,'-12 months') THEN w.bcp5       - LAG(w.bcp5,       12) OVER (ORDER BY w.mes) END AS bcp5
FROM w;
