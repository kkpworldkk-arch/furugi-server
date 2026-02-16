from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import or_
from geopy.geocoders import Nominatim
from datetime import datetime
import os
import re
import time
import csv
import urllib.parse
UPLOAD_FOLDER = 'static/uploads'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)
    
def seed_data():
    db.create_all()
    
    # CSVファイルからデータを読み込む
    initial_shops = []
    try:
        with open('shops.csv', mode='r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                # 文字列として読み込まれる数値をfloatに変換
                row['latitude'] = float(row['latitude'])
                row['longitude'] = float(row['longitude'])
                initial_shops.append(row)
    except FileNotFoundError:
        print("⚠️ shops.csv が見つかりません。")
        return

    # あとは今までのループ処理と同様
    for s in initial_shops:
        # 優先順位に基づいたURL生成ロジック（後述）
        s['map_url'] = generate_map_url(s)

app = Flask(__name__)
app.config['JSON_AS_ASCII'] = False

# CORS設定
CORS(app, resources={r"/*": {
    "origins": "*", 
    "allow_headers": ["Content-Type", "ngrok-skip-browser-warning", "Authorization"],
    "methods": ["GET", "POST", "OPTIONS"]
}})

basedir = os.path.abspath(os.path.dirname(__file__))
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(basedir, 'furugiya.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# ==========================================
#  データベースモデル
# ==========================================

class Shop(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    genres = db.Column(db.String(200))
    rating = db.Column(db.Float, default=0.0)      
    review_count = db.Column(db.Integer, default=0) 
    address = db.Column(db.String(200))
    latitude = db.Column(db.Float)
    longitude = db.Column(db.Float)
    plus_code = db.Column(db.String(100), nullable=True)
    homepage_url = db.Column(db.String(200))
    sns_url = db.Column(db.String(200))
    hours = db.Column(db.String(100))
    holiday = db.Column(db.String(100))
    description = db.Column(db.String(1000))
    price_range = db.Column(db.String(50), default='不明')
    place_id = db.Column(db.String(100), nullable=True)
    map_url = db.Column(db.String(500), nullable=True)
class Article(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100))
    content = db.Column(db.Text)
    genre = db.Column(db.String(50))
    date = db.Column(db.String(20))

class Admin(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    password = db.Column(db.String(100))

class Post(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    item_name = db.Column(db.String(100), nullable=False) # 商品名
    price = db.Column(db.String(50))                      # 価格
    description = db.Column(db.Text)                     # 感想
    image_url = db.Column(db.String(500))                # 画像パス
    created_at = db.Column(db.DateTime, default=datetime.now)
    # どの店で買ったか
    shop_id = db.Column(db.Integer, db.ForeignKey('shop.id'), nullable=False)
    shop = db.relationship('Shop', backref=db.backref('posts', lazy=True))
# ==========================================
#  便利機能（住所から座標を取得）
# ==========================================

def get_lat_lng(address):
    if not address:
        return 35.6812, 139.7671  # 東京駅
    
    # 毎回異なるユーザーエージェントを使うことでブロックを防ぐ
    geolocator = Nominatim(user_agent="furugiya_map_v3_" + str(time.time()))
    
    # ビル名や「2F」などを取り除いて検索しやすくする
    clean_address = re.split(r'[ 　]|ビル|階|F|号|（|\(|🏢', address)[0]
    
    # 検索パターンのリスト（正確な住所 -> 削った住所）
    search_queries = [address, clean_address]
    
    for query in search_queries:
        try:
            print(f"🔍 検索中: {query}")
            # 日本であることを明示して精度を上げる
            location = geolocator.geocode(query + ", Japan", timeout=10)
            if location:
                print(f"✅ 発見: {location.latitude}, {location.longitude}")
                return location.latitude, location.longitude
        except Exception as e:
            print(f"⚠️ 検索エラー: {e}")
            continue
            
    print(f"❌ 特定不可: {address} (東京駅を返します)")
    return 35.6812, 139.7671

# ==========================================
#  API エンドポイント
# ==========================================

@app.route('/')
def home():
    return "古着屋マップAPIサーバー稼働中！"

@app.route('/api/shops', methods=['GET'])
def get_shops():
    keyword = request.args.get('q', '').strip()
    genre = request.args.get('genre', '').strip() # 追加：ジャンルを取得
    
    query = Shop.query

    # ジャンル指定があればフィルタリング（「すべて」以外の場合）
    if genre and genre != 'すべて':
        query = query.filter(Shop.genres.ilike(f'%{genre}%'))
        
    if keyword:
        # Shop.name に対して大文字小文字を無視した「あいまい検索」を行う
        shops = query.filter(Shop.name.ilike(f'%{keyword}%')).all()
    else:
        shops = Shop.query.all()
    
    output = []
    for shop in shops:
        output.append({
            "id": shop.id,
            "name": shop.name,
            "genres": shop.genres.split(',') if shop.genres else [],
            "rating": shop.rating,
            "reviewCount": shop.review_count,
            "address": shop.address,
            "latitude": shop.latitude,
            "longitude": shop.longitude,
            "plusCode": shop.plus_code if shop.plus_code else "",
            "homepageUrl": shop.homepage_url,
            "snsUrl": shop.sns_url,
            "hours": shop.hours,
            "holiday": shop.holiday if shop.holiday else "年中無休",
            "description": shop.description,
            "priceRange": shop.price_range,
            "map_url": shop.map_url,
            "imageUrls": []
        })
    return jsonify(output)

@app.route('/api/shops', methods=['POST'])
def add_shop():
    data = request.json
    lat = data.get('latitude')
    lng = data.get('longitude')
    
    if not lat or not lng or lat == 0:
        lat, lng = get_lat_lng(data.get('address', ''))

    genres_str = ",".join(data.get('genres', [])) if isinstance(data.get('genres'), list) else data.get('genres', '')

    new_shop = Shop(
        name=data.get('name', '店名なし'),
        address=data.get('address', ''),
        latitude=lat,
        longitude=lng,
        genres=genres_str,
        hours=data.get('hours', ''),
        holiday=data.get('holiday', ''),
        homepage_url=data.get('homepageUrl', ''),
        sns_url=data.get('snsUrl', ''),
        description=data.get('description', ''),
        price_range=data.get('priceRange', '不明'),
        rating=0.0,
        review_count=0
    )
    db.session.add(new_shop)
    db.session.commit()
    return jsonify({"message": "Shop added"}), 201

@app.route('/api/articles', methods=['GET'])
def get_articles():
    articles = Article.query.all()
    return jsonify([{"id":a.id,"title":a.title,"content":a.content,"genre":a.genre,"date":a.date} for a in articles])

@app.route('/api/articles', methods=['POST'])
def add_article():
    data = request.json
    password = data.get('password')
    admin = Admin.query.first()
    if not admin or admin.password != password:
        return jsonify({"error": "パスワードが違います"}), 401
    new_article = Article(title=data.get('title'), content=data.get('content'), genre=data.get('genre'), date=datetime.now().strftime('%Y-%m-%d'))
    db.session.add(new_article)
    db.session.commit()
    return jsonify({"message": "Article added"}), 201

@app.route('/api/admin/login', methods=['POST'])
def login():
    data = request.json
    password = data.get('password')
    admin = Admin.query.first()
    if admin and admin.password == password:
        return jsonify({"message": "OK"}), 200
    return jsonify({"error": "NG"}), 401

@app.route('/api/posts', methods=['GET'])
def get_posts():
    # 最新順に取得
    posts = Post.query.order_by(Post.created_at.desc()).all()
    output = []
    for p in posts:
        output.append({
            "id": p.id,
            "itemName": p.item_name,
            "price": p.price,
            "description": p.description,
            "imageUrl": f"{request.host_url}{p.image_url}" if p.image_url else "",
            "shopName": p.shop.name,
            "shopId": p.shop.id,
            "createdAt": p.created_at.strftime('%Y-%m-%d %H:%M')
        })
    return jsonify(output)

@app.route('/api/posts', methods=['POST'])
def add_post():
    # 今回は画像とテキストを同時に受け取るため form-data を想定
    item_name = request.form.get('itemName')
    price = request.form.get('price')
    description = request.form.get('description')
    shop_id = request.form.get('shopId')
    file = request.files.get('image')

    image_path = ""
    if file:
        filename = f"{int(time.time())}_{file.filename}"
        save_path = os.path.join(UPLOAD_FOLDER, filename)
        file.save(save_path)
        image_path = f"static/uploads/{filename}"

    new_post = Post(
        item_name=item_name,
        price=price,
        description=description,
        image_url=image_path,
        shop_id=shop_id
    )
    
    db.session.add(new_post)
    db.session.commit()
    return jsonify({"message": "ディグ成功！"}), 201

def seed_data():
    db.create_all()
    # 「count == 0」の条件を外し、店名ごとにチェックするように変更
    print("🌱 データの整合性をチェック中...")
    
    initial_shops = [
        {
            "name": "古着屋JAM 原宿店", "genres": "アメカジ,ヴィンテージ",
            "address": "東京都渋谷区神宮前6-28-5", 
            "latitude": 35.6673795, "longitude": 139.703866,
            "homepage_url": "https://jamtrading.jp/", "sns_url": "https://instagram.com/furugiya_jam_official",
            "hours": "11:00 - 20:00", "description": "国内最大級の古着屋JAMの原宿店。", "price_range": "¥5,000 ~"
        },
        {
            "name": "Chicago 表参道店", "genres": "着物,アメカジ",
            "address": "東京都渋谷区神宮前4-26-26", 
            "latitude": 35.6687659, "longitude": 139.7074562,
            "homepage_url": "https://www.chicago.co.jp/", "sns_url": "",
            "hours": "11:00 - 20:00", "description": "原宿・表参道エリアの老舗。", "price_range": "¥3,000 ~"
        },
        {
            "name": "Flamingo 下北沢店", "genres": "US古着,レディース",
            "address": "東京都世田谷区北沢2-25-12", 
            "latitude": 35.6626969, "longitude": 139.6670597,
            "homepage_url": "", "sns_url": "",
            "hours": "12:00 - 21:00", "description": "下北沢のシンボル的な古着屋。", "price_range": "¥3,000 ~"
        },
        {
            "name": "USED SNEAKERS KAI", "genres": "スニーカー,ストリート",
            "address": "埼玉県川口市芝中田1-1-14", 
            "latitude": 35.8307115, "longitude": 139.6972093,
            "homepage_url": "https://used-sneakers.com/", "sns_url": "https://www.instagram.com/usedsneakers_kai/",
            "hours": "13:00 - 20:00", "description": "スニーカー好きにはたまらない隠れ家的名店。", "price_range": "¥10,000 ~"
        },
        {
            "name": "古着83 十条本店", "genres": "ヴィンテージ,レギュラー,アメカジ,アウトドア,小物",
            "address": "東京都北区十条仲原1-2-5 赤のれんビル2F", 
            "place_id": "ChIJ7Y6CJ_2MGGARLTSfCl-Gf9w","latitude": 35.7616538, "longitude": 139.7214768,
            "homepage_url": "https://furugi83.thebase.in/", "sns_url": "https://www.instagram.com/furu.gi83/",
            "hours": "12:00 - 20:00", "description": "十条商店街にあるアットホームな古着屋。", "price_range": "¥3000~"
        },
        {
            "name": "古着屋 MERRYLOU", "genres": "ヴィンテージ,レギュラー",
            "address": "東京都杉並区高円寺北2-6-4", 
            "latitude":35.7061491, "longitude":139.6497929,
            "homepage_url": "", "sns_url": "https://www.instagram.com/koenji_furugi/",
            "hours": "12:00 - 20:00", "description": "高円寺初インディーズ古着屋。高円寺駅から最も近い古着屋", "price_range": "¥2000~"
        },
        # セカンドストリート（ここも評価データ削除済み）
        {"name": "2nd STREET 原宿店", "genres": "ヴィンテージ,ストリート", "address": "東京都渋谷区神宮前4-26-4", "latitude": 35.6692271, "longitude": 139.7081291, "hours": "11:00-21:00", "description": "メンズ強化店。", "price_range": "¥5,000 ~"},
        {"name": "2nd STREET 高円寺店", "genres": "ヴィンテージ,アメカジ", "address": "東京都杉並区高円寺南4-6-7", "latitude": 35.703028, "longitude": 139.6490492, "hours": "11:00-21:00", "description": "古着の街の旗艦店。", "price_range": "¥3,000 ~"},
        {"name": "Super 2nd STREET 大宮日進店", "genres": "超大型,楽器,古着", "address": "埼玉県さいたま市北区日進町3-372", "latitude": 35.9367519, "longitude": 139.5987896, "hours": "10:00-22:00", "description": "日本最大級の在庫。", "price_range": "¥1,000 ~"},
        {"name": "2nd STREET アメリカ村店", "genres": "ストリート,スニーカー", "address": "大阪府大阪市中央区西心斎橋2-18-5", "latitude": 34.6722428, "longitude": 135.4974877, "hours": "11:00-21:00", "description": "関西のストリートカルチャーの拠点。", "price_range": "¥5,000 ~"},
        {"name": "2nd STREET 札幌狸小路4丁目店", "genres": "ブランド,ヴィンテージ", "address": "北海道札幌市中央区南2条西4-9-2", "latitude": 43.0572281, "longitude": 141.3516235, "hours": "10:00-22:00", "description": "北海道最大の品揃え。", "price_range": "¥5,000 ~"},
        {"name": "2nd STREET 仙台中央店", "genres": "セレクト,ブランド古着", "address": "宮城県仙台市青葉区中央2-4-10", "latitude": 38.26211, "longitude": 140.8713, "hours": "10:00-21:00", "description": "東北エリアのトレンド発信拠点", "price_range": "¥5,000 ~"},
        {"name": "2nd STREET 宇都宮簗瀬店", "genres": "トータル,古着全般", "address": "栃木県宇都宮市簗瀬町2512-1", "latitude": 36.5441314, "longitude": 139.8942151, "hours": "10:00-21:00", "description": "北関東の広大な店舗。", "price_range": "¥1,000 ~"},
        {"name": "Super 2nd STREET 柏沼南店", "genres": "超大型,アウトドア", "address": "千葉県柏市風早1-8-1", "latitude": 35.8397974, "longitude": 140.0045411, "hours": "10:00-21:00", "description": "東日本最大級。", "price_range": "¥1,000 ~"},
        {"name": "Super 2nd STREET 名古屋みなと店", "genres": "超大型,家具", "address": "愛知県名古屋市港区砂美町1-5", "latitude": 35.1065099, "longitude": 136.8717918, "hours": "10:00-21:00", "description": "東海地方最大の店舗。", "price_range": "¥1,000 ~"},
        {"name": "2nd STREET 堀江店", "genres": "デザイナーズ,モード", "address": "大阪府大阪市西区南堀江1-9-1", "latitude": 34.67113, "longitude": 135.496079, "hours": "11:00-21:00", "description": "アーカイブ作品が揃う。", "price_range": "¥10,000 ~"},
        {"name": "2nd STREET 神戸三宮店", "genres": "インポート,ハイブランド", "address": "兵庫県神戸市中央区加納町4-3-5", "latitude": 34.6945885, "longitude": 135.1931349, "hours": "11:00-21:00", "description": "欧州インポートブランドが強い。", "price_range": "¥10,000 ~"},
        {"name": "2nd STREET 福岡天神2号店", "genres": "ヴィンテージ,メンズ", "address": "福岡県福岡市中央区大名2-1-4", "latitude": 33.5887023, "longitude": 130.3960067, "hours": "11:00-21:00", "description": "マニア垂涎のヴィンテージ特化店。", "price_range": "¥10,000 ~"},
        {"name": "2nd STREET 那覇小禄店", "genres": "夏服,アウトドア", "address": "沖縄県那覇市赤嶺2-1-7", "latitude": 26.1979829, "longitude": 127.6684142, "hours": "10:00-21:00", "description": "沖縄ならではの品揃え。", "price_range": "¥1,000 ~"},
    ]

    added_count = 0
    for s in initial_shops:
        # 「店名 ＋ 住所」を組み合わせた検索文字列を作成
        search_query = f"{s['name']} {s['address']}"
        # URLエンコード（日本語をURLで使える形式に変換）
        if s.get('place_id'):
            # Place ID指定のURL（一発で店舗ページが開く最強の形式）
            s['map_url'] = f"https://www.google.com/maps/search/?api=1&query={search_query}&query_place_id={s['place_id']}"
        else:
        # 店舗ページを直接開くためのURLを生成して辞書に追加
            s['map_url'] = f"https://www.google.com/maps/search/?api=1&query={search_query}"
        # --- ここまで追加 ---

        # 重複チェック（店名と住所の両方で判定）
        exists = Shop.query.filter_by(name=s['name'], address=s['address']).first()
        if not exists:
            new_s = Shop(**s)
            db.session.add(new_s)
            added_count += 1

    if Article.query.count() == 0:
        db.session.add(Article(title="古着屋マップへようこそ", content="全国の古着屋を網羅します。", genre="お知らせ", date="2025-12-14"))
    if Admin.query.count() == 0:
        db.session.add(Admin(password="admin"))
    db.session.commit()
    if added_count > 0:
        print(f"✅ 新たに {added_count} 件の初期データを補填しました。")
    else:
        print("👌 すべてのデータは最新です。")

if __name__ == '__main__':
    with app.app_context():
        seed_data()
    app.run(host='0.0.0.0', port=5000, debug=True)