"""
全店舗の住所を国土地理院(GSI)ジオコーダーで再取得し、座標を更新する。
APIキー不要・完全無料・日本の住所に特化。

使い方:
  python geocode_fix.py            # ドライラン（確認のみ）
  python geocode_fix.py --apply    # 実際にDBとCSVを更新
  python geocode_fix.py --all      # 関東含む全店舗を対象にする
  python geocode_fix.py --min 0    # ズレ量フィルタなし（全件表示）
"""
import os, sys, re, csv, math, time, argparse, requests

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from server import app, db, Shop

CSV_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'lib', 'shops.csv')

TARGET_PREFECTURES = ('青森県', '秋田県', '岩手県', '山形県', '宮城県', '福島県')

GSI_URL = 'https://msearch.gsi.go.jp/address-search/AddressSearch'


def strip_building(address: str) -> str:
    """ビル名・階数を除去して番地までに短縮する。
    '宮城県仙台市青葉区中央2丁目10-3 第二MTビル2F' → '宮城県仙台市青葉区中央2丁目10-3'
    """
    m = re.search(r'(\d+丁目\d+[-－]\d+|\d+[-－]\d+[-－]\d+|\d+[-－]\d+)', address)
    if m:
        return address[:m.end()].strip()
    return address


def geocode(address: str):
    """国土地理院APIで住所→(lat, lng)を取得。失敗時はビル名なしで再試行。"""
    for addr in [address, strip_building(address)]:
        try:
            r = requests.get(GSI_URL, params={'q': addr}, timeout=10)
            results = r.json()
            if results:
                coords = results[0]['geometry']['coordinates']
                lng, lat = coords[0], coords[1]
                # 日本国内チェック
                if 24 <= lat <= 46 and 122 <= lng <= 148:
                    return lat, lng
        except Exception:
            pass
        time.sleep(0.2)
    return None, None


def haversine_m(lat1, lon1, lat2, lon2):
    R = 6371000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlam/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def update_csv(updates: dict):
    rows = []
    with open(CSV_PATH, newline='', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for row in reader:
            name = row.get('name', '').strip()
            if name in updates:
                row['latitude']  = str(updates[name][0])
                row['longitude'] = str(updates[name][1])
            rows.append(row)
    with open(CSV_PATH, 'w', newline='', encoding='utf-8-sig') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true', help='実際にDB・CSVを更新する')
    parser.add_argument('--all',   action='store_true', help='関東含む全店舗を対象にする')
    parser.add_argument('--min',   type=float, default=50,
                        help='報告するズレの最小距離（メートル）。デフォルト: 50m')
    args = parser.parse_args()

    updates = {}
    failed  = []

    with app.app_context():
        all_shops = Shop.query.filter(Shop.address != '').all()
        shops = all_shops if args.all else [
            s for s in all_shops if any(p in s.address for p in TARGET_PREFECTURES)
        ]
        print(f"対象: {len(shops)} 店舗 / 国土地理院ジオコーダー使用\n")

        for i, shop in enumerate(shops, 1):
            print(f"[{i:3d}/{len(shops)}] {shop.name[:28]:28s} ...", end=' ', flush=True)

            new_lat, new_lng = geocode(shop.address)

            if new_lat is None:
                print("取得失敗")
                failed.append(shop.name)
                continue

            dist = haversine_m(shop.latitude, shop.longitude, new_lat, new_lng)

            if dist > 15_000:
                print(f"⚠️  要確認({dist/1000:.1f}km) → ({new_lat:.6f},{new_lng:.6f})")
                failed.append(f"{shop.name} [要確認:{dist/1000:.1f}km]")
                continue

            if dist >= args.min:
                print(f"{dist:6.0f}m  ({shop.latitude:.6f},{shop.longitude:.6f}) → ({new_lat:.6f},{new_lng:.6f})")
                updates[shop.name] = (new_lat, new_lng)
                if args.apply:
                    shop.latitude  = new_lat
                    shop.longitude = new_lng
            else:
                print(f"OK ({dist:.0f}m)")

        print(f"\n{'='*70}")
        print(f"更新: {len(updates)}件 / 失敗・要確認: {len(failed)}件 / 変化なし: {len(shops)-len(updates)-len(failed)}件")

        if failed:
            print("\n--- 取得失敗・要確認 ---")
            for n in failed:
                print(f"  {n}")

        if args.apply:
            db.session.commit()
            update_csv(updates)
            print(f"\n✅ 完了: DB・CSV各 {len(updates)} 件を更新しました")
        elif updates:
            print(f"\n確認後: python geocode_fix.py --apply")


if __name__ == '__main__':
    main()
