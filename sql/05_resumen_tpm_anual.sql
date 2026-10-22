-- 05_resumen_tpm_anual.sql
-- Resumen anual de la TPM y la inflacion (GROUP BY sobre el panel mensual).
SELECT strftime('%Y', mes) AS anio,
       ROUND(MIN(tpm), 2)             AS tpm_min,
       ROUND(MAX(tpm), 2)             AS tpm_max,
       ROUND(AVG(tpm), 2)             AS tpm_prom,
       ROUND(AVG(tpm_real_exante), 2) AS tpm_real_prom,
       ROUND(AVG(ipc_12m), 2)         AS ipc_prom
FROM v_panel
GROUP BY anio
ORDER BY anio;
