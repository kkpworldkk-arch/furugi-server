import csv
import os
import sys
import urllib.parse

SCRIPT_DIR = os.path.dirname(__file__)
ROOT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, os.pardir))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)

from server import app, db, Shop 

def import_shops_from_csv(filename='lib/shops.csv'):
    if not os.path.exists(filename):
        alt = os.path.join(ROOT_DIR, 'shops.csv')
        if os.path.exists(alt):
            filename = alt
        else:
            print(f"❌ エラー: {filename} および {alt} のいずれも見つかりません。")
            return

    print("🚀 座標、Plus Code、Googleマップリンクを最適化しながらインポートを開始します...")

    with app.app_context():
        # 既存DBに nearest_station カラムがなければ追加
        try:
            db.session.execute(db.text("ALTER TABLE shop ADD COLUMN nearest_station VARCHAR(100) DEFAULT ''"))
            db.session.commit()
            print("📌 nearest_station カラムを追加しました。")
        except Exception:
            db.session.rollback()  # 既にカラムがある場合はスキップ

        # カラムが追加された最新のモデルを反映
        db.create_all()

        with open(filename, encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            count = 0
            update_count = 0
            
            for row in reader:
                # 1. 基本データの取得とクリーンアップ
                name = (row.get('name') or '店名なし').strip()
                address = (row.get('address') or '').strip()
                place_id = (row.get('place_id') or '').strip()
                # ★ Plus Code の取得（列名は plus_code を想定）
                plus_code = (row.get('plus_code') or '').strip()

                # 2. 座標の取得（数値がない場合は東京駅）
                try:
                    lat = float(row.get('latitude') or 35.6812)
                    lng = float(row.get('longitude') or 139.7671)
                except ValueError:
                    lat, lng = 35.6812, 139.7671

                # 3. GoogleマップURLの生成
                # クエリ作成（Plus Codeがあればそれを混ぜると検索精度が爆上がりします）
                search_query = f"{name} {plus_code}" if plus_code else f"{name} {address}"
                name_addr_query = urllib.parse.quote(search_query)
                
                if place_id:
                    # Place IDがある場合
                    generated_url = f"https://www.google.com/maps/search/?api=1&query={name_addr_query}&query_place_id={place_id}"
                else:
                    # Plus Code または 住所で検索
                    generated_url = f"https://www.google.com/maps/search/?api=1&query={name_addr_query}"

                # 4. 重複チェック（店名と住所の組み合わせで判定）
                shop = Shop.query.filter_by(name=name, address=address).first()

                if shop:
                    # ★ 既存データの上書き更新
                    shop.latitude = lat
                    shop.longitude = lng
                    shop.genres = row.get('genres', shop.genres)
                    shop.hours = row.get('hours', shop.hours)
                    shop.description = row.get('description', shop.description)
                    shop.price_range = row.get('price_range', shop.price_range)
                    update_count += 1
                    print(f"🔄 更新完了: {name}")
                else:
                    # ★ 新規登録
                    new_shop = Shop(
                        name=name,
                        address=address,
                        genres=row.get('genres', '古着'),
                        hours=row.get('hours', ''),
                        homepage_url=row.get('homepage_url', ''),
                        sns_url=row.get('sns_url', ''),
                        description=row.get('description', ''),
                        price_range=row.get('price_range', '不明'),
                        latitude=lat,
                        longitude=lng,
                        rating=0.0,
                        review_count=0
                    )
                    db.session.add(new_shop)
                    count += 1
                    print(f"✅ 新規登録: {name}")

            db.session.commit()
            print(f"\n✨ 完了！ 新規: {count}件 / 更新: {update_count}件")

if __name__ == '__main__':
    import_shops_from_csv()