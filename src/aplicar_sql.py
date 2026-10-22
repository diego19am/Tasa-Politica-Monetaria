"""Aplica las vistas SQL del proyecto a la base de datos.

Uso (desde la raiz del repo):
    python src/aplicar_sql.py                 # busca la base en db/ o data/
    python src/aplicar_sql.py --db ruta/macro.db

Corre despues de la carga (python src/carga_db.py --hasta AAAA-MM-DD).
El SQL vive en sql/*.sql (comentado); este script solo lo ejecuta.
"""
import argparse
import sqlite3
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CANDIDATAS = [RAIZ / "db" / "macro.db", RAIZ / "data" / "macro.db", RAIZ / "macro.db"]


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--db", type=Path, default=None)
    args = ap.parse_args()

    db = args.db or next((r for r in CANDIDATAS if r.exists()), None)
    if db is None or not db.exists():
        raise SystemExit("No se encontro la base. Corre antes: python src/carga_db.py --hasta AAAA-MM-DD")

    script = (RAIZ / "sql" / "01_vistas.sql").read_text(encoding="utf-8")
    con = sqlite3.connect(db)
    con.executescript(script)
    con.commit()
    n = con.execute("SELECT COUNT(*) FROM v_panel").fetchone()[0]
    print(f"[OK] Vistas creadas en {db}. v_panel tiene {n} meses.")
    con.close()


if __name__ == "__main__":
    main()
