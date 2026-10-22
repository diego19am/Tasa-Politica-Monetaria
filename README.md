# Monitor de Coyuntura y Proyección Macroeconómica — Hito 2

Ciencia de Datos para Economía (ICO09425) · Escuela de Ingeniería Comercial, FAE-UDP.

> Plantilla del README. Los textos entre `[corchetes]` los completa el equipo. Los comandos de `src/carga_db.py` siguen la guía del Hito 2; ajusten lo que difiera de su código.

## 1. Descripción
- **Variable objetivo:** Tasa de Política Monetaria (TPM).
- **Pregunta de proyección:** [copiar la pregunta de la propuesta del Hito 1].
- **Integrantes:** Diego Alarcon, Francisco Vera, Martyn Sanhueza, Benjamin Tomckowiack.
- **Flujo:** `API (BDE / FRED) → SQLite → vistas SQL → Python (notebook)`.
- **Estado (Hito 2):** base poblada desde las APIs (14 series), consultas SQL y análisis de coyuntura inicial.
- **Fecha de corte de los datos:** `[AAAA-MM-DD]` (el último dato diario cargado es del 2026-10-19; usar la misma fecha en `--hasta`).

## 2. Requisitos
- Python `[versión, p. ej. 3.11]`.
- `pip install -r requirements.txt` (el notebook usa pandas, numpy, matplotlib y jupyter/ipykernel; verificar que estén en el archivo).

## 3. Credenciales
1. Copiar `.env.example` a `.env` (cada integrante crea el suyo).
2. Completar las credenciales de la API del Banco Central y la clave de FRED con los nombres de variable que define `.env.example`.
3. **No** subir `.env` ni escribir claves en el código, el README o los notebooks (`.gitignore` ya excluye `.env`, `db/`, `data/` y `*.db`).

## 4. Reproducción (en este orden)
```bash
# 1) Descargar las series y cargarlas a la base. Debe terminar con 14 [OK] y 0 [ERROR].
python src/carga_db.py --hasta [AAAA-MM-DD]

# 2) Crear las vistas SQL (frecuencia mensual, variaciones, panel)
python src/aplicar_sql.py

# 3) Abrir el análisis de coyuntura
jupyter notebook notebooks/01_analisis_coyuntura.ipynb
```
Notas:
- Nunca usar `--demo` para el análisis: genera datos sintéticos.
- El script de carga no se detiene si falla una serie: informa `[ERROR]` y sigue. Contar los `[OK]`.
- El notebook también crea las vistas por sí mismo (ejecuta `sql/01_vistas.sql`), pero se recomienda el paso 2.

## 5. Estructura de carpetas
```
src/         extracción y carga (carga_db.py, config.py) y aplicar_sql.py
sql/         01_vistas.sql (vistas con JOIN, GROUP BY y funciones de ventana),
             04_resumen_por_bloque.sql, 05_resumen_tpm_anual.sql, 06_huecos_mensuales.sql
notebooks/   01_analisis_coyuntura.ipynb
docs/        razones_series.md (razón económica de cada serie)
db/          base SQLite generada (NO se versiona)
```

## 6. Decisiones de datos
- IPC: empalme del BCCh base 2023 (el empalme base 2018 terminaba en dic-2023). No coincide exactamente con las cifras del INE (abril de 2026: 3,95% vs 4,0%).
- Inflación subyacente: IPC sin volátiles (el IPCX1 se discontinuó en 2018).
- Tasas a 5 años: mercado secundario BCP (nominal) y BCU/BTU (real); la BCU licitada terminó en 2017.
- Expectativas EEE: horizontes de 11 y 23 meses (alias históricos `eee_12m` y `eee_24m` en la base).
- Series diarias a mensual: último valor del mes (GROUP BY en `v_obs_mensual`).
- Variaciones a 12 meses: funciones de ventana con `PARTITION BY codigo` y `RANGE` sobre un índice mensual entero, para que los huecos no descuadren el cálculo.
- **Huecos conocidos:** BCP y BCU a 5 años sin dato de oct-2022 a jun-2023 (la API devuelve nulos); CPI EE.UU. sin dato en oct-2025. No se interpolan.
- Imacec: serie original (sin desestacionalizar); se usa media móvil de 3 meses. Cambio a serie desestacionalizada: pendiente.

## 7. Entrega del Hito 2
```bash
git tag hito-2
git push origin hito-2     # git push solo no sube los tags
```
