"""
shops.csv を DB に一括インポートするスクリプト。

使い方:
  python import_csv.py          # 重複しない店舗だけ追加
  python import_csv.py --clear  # 既存データを全削除してから全件インポート
"""
import csv
import os
import sys
import argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from server import app, db, Shop, migrate_db

CSV_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'lib', 'shops.csv')


def import_csv(clear_existing: bool = False):
    with app.app_context():
        db.create_all()
        migrate_db()  # 不足列を既存DBに追加

        if clear_existing:
            count = Shop.query.count()
            Shop.query.delete()
            db.session.commit()
            print(f"🗑️  既存データ {count} 件を削除しました")

        imported = 0
        skipped = 0

        with open(CSV_PATH, newline='', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            for row in reader:
                name = row.get('name', '').strip()
                address = row.get('address', '').strip()
                if not name:
                    continue

                # 重複チェック（店名で判定）
                if not clear_existing and Shop.query.filter_by(name=name).first():
                    skipped += 1
                    continue

                try:
                    lat = float(row.get('latitude') or 0)
                    lng = float(row.get('longitude') or 0)
                except (ValueError, TypeError):
                    lat, lng = 0.0, 0.0

                # genres: クォートされた "A,B,C" もそのまま保存（DB側はカンマ区切り文字列）
                genres_raw = row.get('genres', '').strip().strip('"')

                def col(key, default=''):
                    return (row.get(key) or default).strip()

                shop = Shop(
                    name=name,
                    address=address,
                    nearest_station=col('nearest_station'),
                    place_id=col('place_id'),
                    plus_code=col('plus_code'),
                    genres=genres_raw,
                    hours=col('hours'),
                    holiday=col('holiday') or 'なし',
                    homepage_url=col('homepage_url'),
                    sns_url=col('sns_url'),
                    description=col('description'),
                    price_range=col('price_range') or '不明',
                    payment_methods=col('payment_methods'),
                    parking=col('parking'),
                    latitude=lat,
                    longitude=lng,
                    rating=0.0,
                    review_count=0,
                )
                db.session.add(shop)
                imported += 1
                print(f"  ✓ {name}")

        db.session.commit()
        print(f"\n✅ 完了: {imported} 件インポート", end='')
        if skipped:
            print(f" / {skipped} 件スキップ（重複）", end='')
        print()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='shops.csv を DB にインポートします')
    parser.add_argument(
        '--clear',
        action='store_true',
        help='既存の全店舗データを削除してから全件インポートする',
    )
    args = parser.parse_args()
    import_csv(clear_existing=args.clear)
