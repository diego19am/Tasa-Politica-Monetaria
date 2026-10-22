# Catálogo de series y razón económica (Etapa 1 de la guía)

Variable objetivo: **TPM**. Cada fila indica el mecanismo por el que la serie ayuda a anticipar o a contextualizar la TPM.
Copien cada razón como comentario junto a la serie en `src/config.py` (`SERIES_BCCH` / `SERIES_FRED`).
Los códigos son los que están en la base (`series_catalogo`).

| Alias | Código | Fuente | Frec. | Razón económica |
|---|---|---|---|---|
| `tpm` | F022.TPM.TIN.D001.NO.Z.D | BDE | Diaria | Variable objetivo: instrumento de política del Banco Central. |
| `eee_12m` (11 meses) | F089.IPC.V12.14.M | BDE | Mensual | Inflación esperada a 11 meses (EEE). El Banco Central reacciona a lo que esperan los agentes, no solo a la inflación pasada; sirve para calcular la TPM real ex ante. |
| `eee_24m` (23 meses) | F089.IPC.V12.15.M | BDE | Mensual | Mide si las expectativas de largo plazo están ancladas a la meta de 3%. Con expectativas ancladas, la TPM necesita reaccionar menos a shocks transitorios. |
| `ipc_12m` | G073.IPC.V12.2023.M | BDE | Mensual | Objetivo del Banco Central (meta 3%). Su brecha con la meta es el insumo principal de una regla de Taylor. |
| `ipc_sv` | G073.IPCSV.V12.2023.M | BDE | Mensual | Inflación subyacente (sin volátiles). Distingue shocks transitorios (combustibles, alimentos) de presiones generalizadas, que son las que mueven la TPM. |
| `imacec` | F032.IMC.IND.Z.Z.EP18.Z.Z.0.M | BDE | Mensual | Actividad mensual: aproxima la brecha de actividad (segundo argumento de la regla de Taylor) y el ciclo económico. Serie original; falta cambiar a desestacionalizada. |
| `desempleo` | F049.DES.TAS.INE9.10.M | BDE | Mensual | Holgura del mercado laboral: canal por el que la actividad débil reduce presiones inflacionarias y habilita recortes. Parte en 2010-03. |
| `dolar` | F073.TCO.PRE.HIST.M | BDE | Mensual | Traspaso cambiario a precios de bienes transables: un peso débil presiona la inflación y limita recortes. |
| `tcr` | F073.TCR.IND.199101.M | BDE | Mensual | Tipo de cambio real: competitividad y presión de costos externos, ajustada por inflación relativa. |
| `bcp5` | F022.BCLP.TIS.AN05.NO.Z.D | BDE | Diaria | Tasa nominal a 5 años: resume lo que el mercado espera para la TPM futura más una prima por plazo. Es la variable más correlacionada con la TPM rezagada. Tiene un hueco oct-2022 a jun-2023. |
| `bcu5r` | F022.BUF.TIS.AN05.UF.Z.D | BDE | Diaria | Tasa real a 5 años: costo real del crédito de largo plazo y referencia para la tasa neutra real. Mismo hueco que `bcp5`. |
| `cobre` | F019.PPB.PRE.40.M | BDE | Mensual | Términos de intercambio e ingreso externo de Chile; influye en el tipo de cambio y en la actividad. |
| `fedfunds` | FEDFUNDS | FRED | Mensual | Política monetaria de EE.UU.: el diferencial de tasas con la TPM afecta el tipo de cambio y el margen para recortar. |
| `cpi_usa` | CPIAUCSL | FRED | Mensual | Inflación externa y ciclo de la Fed (condiciona a `fedfunds`) y precios de importaciones. Falta oct-2025. |

**Pendiente (no es parte del Hito 2):** índice de remuneraciones (sustentar o descartar presiones salariales) y un índice amplio del dólar de FRED (separar factor global del local).
