import sqlite3
import os

db_path = os.path.join(os.path.abspath(os.path.dirname(__file__)), 'furugiya.db')

def add_holiday_column():
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        # holiday列を後付けで追加する
        cursor.execute("ALTER TABLE shop ADD COLUMN holiday TEXT")
        conn.commit()
        conn.close()
        print("✅ データベースの更新に成功しました！")
    except sqlite3.OperationalError:
        print("⚠️ すでに列が存在するか、テーブルが見つかりません。")

if __name__ == '__main__':
    add_holiday_column()