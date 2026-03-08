import sqlite3
import os

db_path = os.path.join(os.path.abspath(os.path.dirname(__file__)), 'furugiya.db')

def add_missing_columns():
    columns_to_add = [
        ("holiday", "TEXT"),
        ("plus_code", "TEXT"),
        ("place_id", "TEXT"),
        ("map_url", "TEXT"),
    ]
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    for col_name, col_type in columns_to_add:
        try:
            cursor.execute(f"ALTER TABLE shop ADD COLUMN {col_name} {col_type}")
            print(f"[OK] {col_name} added")
        except sqlite3.OperationalError:
            print(f"[SKIP] {col_name} already exists")
    conn.commit()
    conn.close()

if __name__ == '__main__':
    add_missing_columns()