"""
支払い方法を自動検索してshops.csvに書き戻すスクリプト
使い方: python fetch_payment_methods.py
依存: pip install duckduckgo-search
"""

import csv
import time
import re
import os

try:
    from duckduckgo_search import DDGS
except ImportError:
    print("依存ライブラリが見つかりません。以下を実行してください:")
    print("  pip install duckduckgo-search")
    exit(1)

# ---- 検索で拾うキーワードの定義 ----
KEYWORD_RULES = [
    (r'現金のみ|cash\s*only',                       '現金のみ'),
    (r'paypay|ペイペイ',                             'PayPay'),
    (r'楽天\s*pay|楽天ペイ',                         '楽天Pay'),
    (r'd\s*払い|d払い',                              'd払い'),
    (r'au\s*pay|auペイ',                             'au PAY'),
    (r'メルペイ|merpay',                             'メルペイ'),
    (r'suica|pasmo|交通系\s*ic|icカード',            '交通系IC'),
    (r'電子マネー|e-money',                          '電子マネー'),
    (r'クレジット|credit\s*card|visa|master|jcb|amex','クレジットカード'),
    (r'現金',                                        '現金'),
]

def extract_payment_keywords(text: str) -> list[str]:
    """テキストから支払いキーワードを抽出して重複なしリストで返す"""
    text_lower = text.lower()
    found = []
    for pattern, label in KEYWORD_RULES:
        if re.search(pattern, text_lower) and label not in found:
            found.append(label)
    return found

def search_payment_methods(shop_name: str, address: str) -> str:
    """DuckDuckGoで検索し、スニペットから支払い方法を推定する"""
    query = f"{shop_name} {address} 支払い方法"
    print(f"  検索中: {query[:60]}...")

    try:
        with DDGS() as ddgs:
            results = list(ddgs.text(query, max_results=5))
    except Exception as e:
        print(f"  ⚠️  検索エラー: {e}")
        return ''

    # 全スニペット + タイトルをまとめて1つのテキストにする
    combined = ' '.join(
        f"{r.get('title', '')} {r.get('body', '')}" for r in results
    )

    keywords = extract_payment_keywords(combined)

    if keywords:
        result_str = '・'.join(keywords)
        print(f"  → 検出: {result_str}")
        return result_str
    else:
        print("  → キーワードなし")
        return ''

def main():
    csv_path = os.path.join(os.path.dirname(__file__), 'shops.csv')

    # CSV読み込み
    with open(csv_path, encoding='utf-8-sig', newline='') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        rows = list(reader)

    if 'payment_methods' not in fieldnames:
        print("❌ payment_methods 列がCSVにありません")
        return

    # 処理対象：payment_methods が空の行のみ
    targets = [r for r in rows if not r.get('payment_methods', '').strip()]
    print(f"\n対象: {len(targets)} 件（空欄のみ）/ 全 {len(rows)} 件\n")

    if not targets:
        print("全行に支払い方法が設定済みです。")
        return

    updated = 0
    for i, row in enumerate(rows):
        if row.get('payment_methods', '').strip():
            continue  # 既に入力済みはスキップ

        shop_name = row.get('name', '').strip()
        address   = row.get('address', '').strip()

        print(f"[{updated + 1}/{len(targets)}] {shop_name}")
        result = search_payment_methods(shop_name, address)

        if result:
            row['payment_methods'] = result
            updated += 1

        # レート制限対策（1秒待機）
        time.sleep(1.2)

    # CSV書き戻し
    with open(csv_path, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"\n✅ 完了！ {updated} 件を更新しました → shops.csv")
    print("\n次のステップ: python import_csv.py でDBに同期してください")

if __name__ == '__main__':
    main()
