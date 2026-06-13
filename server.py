from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from geopy.geocoders import Nominatim
from datetime import datetime
import os

app = Flask(__name__)
app.config['JSON_AS_ASCII'] = False

# CORS設定
CORS(app, resources={r"/*": {
    "origins": "*", 
    "allow_headers": ["Content-Type", "ngrok-skip-browser-warning", "Authorization"],
    "methods": ["GET", "POST", "PATCH", "OPTIONS"]
}})

# データベース設定（Railway PostgreSQL or ローカルSQLite）
database_url = os.environ.get('DATABASE_URL', '')
if database_url.startswith('postgres://'):
    database_url = database_url.replace('postgres://', 'postgresql://', 1)

if database_url:
    app.config['SQLALCHEMY_DATABASE_URI'] = database_url
else:
    basedir = os.path.abspath(os.path.dirname(__file__))
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(basedir, 'furugiya.db')

app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# ==========================================
#  データベース設計図
# ==========================================

class Shop(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    genres = db.Column(db.String(200)) # カンマ区切り
    rating = db.Column(db.Float, default=0.0)
    review_count = db.Column(db.Integer, default=0)
    address = db.Column(db.String(200))
    latitude = db.Column(db.Float)
    longitude = db.Column(db.Float)
    nearest_station = db.Column(db.String(100), default='')
    place_id = db.Column(db.String(100), default='')
    plus_code = db.Column(db.String(50), default='')
    homepage_url = db.Column(db.String(200))
    sns_url = db.Column(db.String(200))
    hours = db.Column(db.String(100))
    description = db.Column(db.String(1000))
    price_range = db.Column(db.String(50), default='不明')
    holiday = db.Column(db.String(100), default='なし')
    payment_methods = db.Column(db.String(200), default='不明')
    parking = db.Column(db.String(20), default='')

class Article(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100))
    content = db.Column(db.Text)
    genre = db.Column(db.String(50))
    date = db.Column(db.String(20))

class Admin(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    password = db.Column(db.String(100))

class Review(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    shop_id = db.Column(db.Integer, db.ForeignKey('shop.id'), nullable=False)
    nickname = db.Column(db.String(50), default='匿名')
    rating = db.Column(db.Float, nullable=False)
    comment = db.Column(db.String(500))
    date = db.Column(db.String(20))

class Notice(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    shop_id = db.Column(db.Integer, db.ForeignKey('shop.id'), nullable=False)
    title = db.Column(db.String(100))
    content = db.Column(db.String(1000))
    date = db.Column(db.String(20))

# ==========================================
#  API エンドポイント
# ==========================================

@app.route('/')
def home():
    return "古着屋マップAPIサーバー稼働中！"

@app.route('/api/geocode', methods=['GET'])
def geocode():
    address = request.args.get('address', '')
    if not address:
        return jsonify({"error": "住所が指定されていません"}), 400
    try:
        geolocator = Nominatim(user_agent="furugiya_map_v2")
        location = geolocator.geocode(address, timeout=10)
        if location:
            return jsonify({"latitude": location.latitude, "longitude": location.longitude})
    except Exception:
        pass
    return jsonify({"error": "住所から座標を取得できませんでした"}), 404

@app.route('/api/shops', methods=['GET'])
def get_shops():
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
            "nearestStation": shop.nearest_station or '',
            "placeId": shop.place_id or '',
            "plusCode": shop.plus_code or '',
            "homepageUrl": shop.homepage_url or '',
            "snsUrl": shop.sns_url or '',
            "hours": shop.hours or '',
            "description": shop.description or '',
            "priceRange": shop.price_range or '不明',
            "holiday": shop.holiday or 'なし',
            "paymentMethods": shop.payment_methods or '不明',
            "parking": shop.parking or '',
            "imageUrls": []
        })
    return jsonify(output)

@app.route('/api/shops', methods=['POST'])
def add_shop():
    data = request.json
    
    # 住所から座標を自動取得
    lat = data.get('latitude')
    lng = data.get('longitude')
    
    # もし座標が0または空なら、住所から検索して埋める
    if not lat or not lng or lat == 0:
        lat, lng = get_lat_lng(data.get('address', ''))

    genres_str = ",".join(data.get('genres', [])) if isinstance(data.get('genres'), list) else data.get('genres', '')

    new_shop = Shop(
        name=data.get('name', '店名なし'),
        address=data.get('address', ''),
        nearest_station=data.get('nearestStation', ''),
        place_id=data.get('placeId', ''),
        plus_code=data.get('plusCode', ''),
        latitude=lat,
        longitude=lng,
        genres=genres_str,
        hours=data.get('hours', ''),
        holiday=data.get('holiday', 'なし'),
        homepage_url=data.get('homepageUrl', ''),
        sns_url=data.get('snsUrl', ''),
        description=data.get('description', ''),
        price_range=data.get('priceRange', '不明'),
        payment_methods=data.get('paymentMethods', '不明'),
        parking=data.get('parking', ''),
        rating=0.0,
        review_count=0
    )
    db.session.add(new_shop)
    db.session.commit()
    return jsonify({"message": "Shop added"}), 201

@app.route('/api/shops/<int:shop_id>', methods=['PATCH'])
def update_shop(shop_id):
    shop = Shop.query.get_or_404(shop_id)
    data = request.json
    if 'name' in data:
        shop.name = data['name']
    if 'address' in data:
        shop.address = data['address']
    if 'nearestStation' in data:
        shop.nearest_station = data['nearestStation']
    if 'genres' in data:
        g = data['genres']
        shop.genres = ','.join(g) if isinstance(g, list) else g
    if 'hours' in data:
        shop.hours = data['hours']
    if 'holiday' in data:
        shop.holiday = data['holiday']
    if 'description' in data:
        shop.description = data['description']
    if 'priceRange' in data:
        shop.price_range = data['priceRange']
    if 'paymentMethods' in data:
        shop.payment_methods = data['paymentMethods']
    if 'parking' in data:
        shop.parking = data['parking']
    if 'homepageUrl' in data:
        shop.homepage_url = data['homepageUrl']
    if 'snsUrl' in data:
        shop.sns_url = data['snsUrl']
    if 'latitude' in data:
        shop.latitude = float(data['latitude'])
    if 'longitude' in data:
        shop.longitude = float(data['longitude'])
    db.session.commit()
    return jsonify({"message": "Updated"}), 200

@app.route('/api/shops/<int:shop_id>/reviews', methods=['GET'])
def get_reviews(shop_id):
    reviews = Review.query.filter_by(shop_id=shop_id).order_by(Review.id.desc()).all()
    return jsonify([{
        "id": r.id,
        "nickname": r.nickname or '匿名',
        "rating": r.rating,
        "comment": r.comment or '',
        "date": r.date or '',
    } for r in reviews])

@app.route('/api/shops/<int:shop_id>/reviews', methods=['POST'])
def add_review(shop_id):
    shop = Shop.query.get_or_404(shop_id)
    data = request.json
    review = Review(
        shop_id=shop_id,
        nickname=data.get('nickname') or '匿名',
        rating=float(data.get('rating', 3)),
        comment=data.get('comment', ''),
        date=datetime.now().strftime('%Y-%m-%d'),
    )
    db.session.add(review)
    all_reviews = Review.query.filter_by(shop_id=shop_id).all()
    total = sum(r.rating for r in all_reviews) + review.rating
    count = len(all_reviews) + 1
    shop.rating = round(total / count, 1)
    shop.review_count = count
    db.session.commit()
    return jsonify({"message": "Review added", "newRating": shop.rating, "reviewCount": shop.review_count}), 201

@app.route('/api/shops/<int:shop_id>/notices', methods=['GET'])
def get_notices(shop_id):
    notices = Notice.query.filter_by(shop_id=shop_id).order_by(Notice.id.desc()).all()
    return jsonify([{
        "id": n.id,
        "title": n.title or '',
        "content": n.content or '',
        "date": n.date or '',
    } for n in notices])

@app.route('/api/articles', methods=['GET'])
def get_articles():
    articles = Article.query.all()
    output = []
    for art in articles:
        output.append({
            "id": art.id,
            "title": art.title,
            "content": art.content,
            "genre": art.genre,
            "date": art.date
        })
    return jsonify(output)

@app.route('/api/articles', methods=['POST'])
def add_article():
    data = request.json
    password = data.get('password')
    admin = Admin.query.first()
    
    if not admin or admin.password != password:
        return jsonify({"error": "パスワードが違います"}), 401

    new_article = Article(
        title=data.get('title'),
        content=data.get('content'),
        genre=data.get('genre'),
        date=datetime.now().strftime('%Y-%m-%d')
    )
    db.session.add(new_article)
    db.session.commit()
    return jsonify({"message": "Article added"}), 201

@app.route('/api/admin/import_csv', methods=['POST'])
def admin_import_csv():
    import csv as csv_module
    data = request.json or {}
    admin = Admin.query.first()
    if not admin or admin.password != data.get('password'):
        return jsonify({"error": "NG"}), 401

    csv_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'lib', 'shops.csv')
    if not os.path.exists(csv_path):
        return jsonify({"error": "CSVファイルが見つかりません"}), 404

    Shop.query.delete()
    db.session.commit()

    imported = 0
    with open(csv_path, newline='', encoding='utf-8-sig') as f:
        reader = csv_module.DictReader(f)
        for row in reader:
            name = (row.get('name') or '').strip()
            if not name:
                continue
            def col(key, default=''):
                return (row.get(key) or default).strip()
            try:
                lat = float(row.get('latitude') or 0)
                lng = float(row.get('longitude') or 0)
            except (ValueError, TypeError):
                lat, lng = 0.0, 0.0
            db.session.add(Shop(
                name=name,
                address=col('address'),
                nearest_station=col('nearest_station'),
                place_id=col('place_id'),
                plus_code=col('plus_code'),
                genres=col('genres').strip('"'),
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
            ))
            imported += 1
    db.session.commit()
    return jsonify({"message": f"{imported}件インポートしました"}), 200

@app.route('/api/admin/login', methods=['POST'])
def login():
    password = request.json.get('password')
    admin = Admin.query.first()
    if admin and admin.password == password:
        return jsonify({"message": "OK"}), 200
    return jsonify({"error": "NG"}), 401

# ==========================================
#  🚀 便利機能：住所から座標計算 ＆ 初期データ移行
# ==========================================

def get_lat_lng(address):
    if not address: return 35.6812, 139.7671 # 東京駅
    try:
        geolocator = Nominatim(user_agent="furugiya_map_v2")
        location = geolocator.geocode(address)
        if location:
            return location.latitude, location.longitude
    except:
        pass
    return 35.6812, 139.7671

def migrate_db():
    """既存DBに不足カラムを追加する（SQLiteのみ。PostgreSQLはcreate_allで完結）"""
    if 'postgresql' in app.config['SQLALCHEMY_DATABASE_URI']:
        return
    new_columns = [
        ("nearest_station", "VARCHAR(100) DEFAULT ''"),
        ("place_id", "VARCHAR(100) DEFAULT ''"),
        ("plus_code", "VARCHAR(50) DEFAULT ''"),
        ("holiday", "VARCHAR(100) DEFAULT 'なし'"),
        ("payment_methods", "VARCHAR(200) DEFAULT '不明'"),
        ("parking", "VARCHAR(20) DEFAULT ''"),
    ]
    with db.engine.connect() as conn:
        for col_name, col_def in new_columns:
            try:
                conn.execute(db.text(f"ALTER TABLE shop ADD COLUMN {col_name} {col_def}"))
                conn.commit()
            except Exception:
                pass  # カラムが既に存在する場合は無視

def seed_aomori_shops():
    """青森県の古着屋データを初回のみ追加"""
    if Shop.query.filter_by(name='古着屋 TOY SOLDIERS').first():
        return

    aomori_shops = [
        # ── 青森市 ────────────────────────────────────────────
        {
            'name': '古着屋 TOY SOLDIERS',
            'address': '青森県青森市緑3丁目8-7',
            'nearest_station': '筒井駅',
            'genres': 'ヴィンテージ,アメカジ,US古着,レディース',
            'hours': '平日 12:00〜20:00 / 土日祝 11:00〜20:00',
            'holiday': '水曜日',
            'homepage_url': 'https://toysoldiers.base.shop/',
            'sns_url': 'https://www.instagram.com/toysoldiers_usedclothing',
            'description': '青森市の人気古着屋。ヴィンテージ・アメカジ・US古着を中心に展開。',
            'latitude': 40.8162, 'longitude': 140.7312,
        },
        {
            'name': 'FLOAT',
            'address': '青森県青森市緑3丁目10-1',
            'nearest_station': '筒井駅',
            'genres': 'レディース,ヴィンテージ,US古着,ストリート',
            'hours': '平日 12:00〜20:00 / 土日祝 11:00〜20:00',
            'holiday': '月曜日',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/float_used',
            'description': 'TOY SOLDIERSの姉妹店。青森市初のレディース特化古着屋（2024年4月オープン）。',
            'latitude': 40.8160, 'longitude': 140.7318,
        },
        {
            'name': 'ESSENCE',
            'address': '青森県青森市古川1丁目18-2 2階',
            'nearest_station': '青森駅',
            'genres': 'ヴィンテージ,アメカジ,US古着,ブランド古着',
            'hours': '11:00〜19:00',
            'holiday': '火曜日',
            'homepage_url': 'https://essence-aomori.stores.jp/',
            'sns_url': 'https://www.instagram.com/essence_aomori',
            'description': 'ヴィンテージ・アメカジ・デザイナー古着を扱うセレクト系ショップ。',
            'latitude': 40.8237, 'longitude': 140.7531,
        },
        {
            'name': 'SUN AND SEA',
            'address': '青森県青森市新町1丁目12-11 新町パークビル1-B',
            'nearest_station': '青森駅',
            'genres': 'アメカジ,ヴィンテージ,US古着',
            'hours': '11:00〜20:00（冬季 11:00〜18:00）',
            'holiday': '水曜日',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/sunandsea_aomori',
            'description': 'アメカジ・ヴィンテージ・US古着メンズ中心のショップ。',
            'latitude': 40.8244, 'longitude': 140.7465,
        },
        {
            'name': 'Stroke Clothing',
            'address': '青森県青森市古川1丁目16-4',
            'nearest_station': '青森駅',
            'genres': 'アメカジ,ワーク,ミリタリー,ヴィンテージ',
            'hours': '11:00〜20:00',
            'holiday': '木曜日',
            'homepage_url': 'https://strokeclothing.com/',
            'sns_url': 'https://www.instagram.com/stroke_clothing',
            'description': 'FREEWHEELERS・WESTRIDE・BUZZ RICKSON\'Sなど国産高級ブランドも扱うアメカジ・ワーク系ショップ。',
            'latitude': 40.8236, 'longitude': 140.7497,
        },
        {
            'name': 'KEY to the CITY BOUTIQUE',
            'address': '青森県青森市古川1丁目21-20',
            'nearest_station': '青森駅',
            'genres': 'ヴィンテージ,ブランド古着,レディース',
            'hours': '',
            'holiday': 'なし',
            'homepage_url': 'https://keytothecity.theshop.jp/',
            'sns_url': 'https://www.instagram.com/keytothecity.boutique',
            'description': '旧「AMA used clothing」が改称・リニューアル。欧米ヴィンテージ・ブランド古着を扱う。',
            'latitude': 40.8231, 'longitude': 140.7478,
        },
        {
            'name': '趣味屋',
            'address': '青森県青森市合浦2丁目11-19',
            'nearest_station': '東青森駅',
            'genres': 'US古着,アメカジ,ヴィンテージ',
            'hours': '13:00〜20:00',
            'holiday': '月曜日',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/syumiya.used',
            'description': '80s・90sのUSA古着とアメリカン雑貨専門店。',
            'latitude': 40.8029, 'longitude': 140.7630,
        },
        {
            'name': 'PICK UP（無人古着屋）',
            'address': '青森県青森市古川1丁目14-3 BLACK BOX 1F',
            'nearest_station': '青森駅',
            'genres': 'その他',
            'hours': '24時間営業',
            'holiday': '不定休',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/mujinnofurugipickup2023',
            'description': '無人販売形式の古着屋。毎日新商品大量入荷。全品5,000円以下。',
            'latitude': 40.8240, 'longitude': 140.7510,
        },
        {
            'name': 'DIG TIME',
            'address': '青森県青森市緑3丁目8-7',
            'nearest_station': '筒井駅',
            'genres': 'ヴィンテージ,アメカジ,US古着',
            'hours': '平日 12:00〜20:00 / 土日祝 11:00〜20:00',
            'holiday': '月曜日',
            'homepage_url': 'https://toysoldiers.base.shop/',
            'sns_url': 'https://www.instagram.com/toysoldiers_usedclothing',
            'description': 'TOY SOLDIERSの2号店。ヴィンテージ・アメカジ・US古着を中心に展開。',
            'latitude': 40.8163, 'longitude': 140.7313,
        },
        {
            'name': 'プライスドロップ 浜館店',
            'address': '青森県青森市浜館6丁目1-8 1階',
            'nearest_station': '東青森駅',
            'genres': 'その他',
            'hours': '11:00〜19:00',
            'holiday': '火曜日',
            'homepage_url': 'https://yorozuya-dc.com/store/shop-13/',
            'sns_url': 'https://www.instagram.com/pd.hamadate',
            'description': '萬屋グループのアウトレット専門店。古着・日用品・雑貨を取り扱う。',
            'latitude': 40.8021, 'longitude': 140.7648,
        },
        # ── 弘前市 ────────────────────────────────────────────
        {
            'name': 'SEESAW',
            'address': '青森県弘前市北瓦ケ町3-1 キョウドウ第一ビル 1階A',
            'nearest_station': '中央弘前駅',
            'genres': 'ヴィンテージ,レディース',
            'hours': '13:00〜21:00',
            'holiday': '火曜日',
            'homepage_url': 'https://seesaw0923.base.shop/',
            'sns_url': 'https://www.instagram.com/seesaw_hirosaki',
            'description': '60s〜90sのヴィンテージを中心に扱う弘前の古着屋。',
            'latitude': 40.6015, 'longitude': 140.4637,
        },
        {
            'name': 'THE FICTION',
            'address': '青森県弘前市代官町56',
            'nearest_station': '中央弘前駅',
            'genres': 'ヴィンテージ,レディース,アメカジ',
            'hours': '平日 13:00〜21:00 / 土日 12:00〜21:00',
            'holiday': '火曜日',
            'homepage_url': 'https://fiction.theshop.jp/',
            'sns_url': 'https://www.instagram.com/the_fiction___',
            'description': '60s〜90sのヴィンテージ古着・雑貨を扱う弘前の人気ショップ。',
            'latitude': 40.5992, 'longitude': 140.4743,
        },
        {
            'name': 'BUTTON UP CLOTHING',
            'address': '青森県弘前市大町3丁目10-8',
            'nearest_station': '中央弘前駅',
            'genres': 'ヴィンテージ,アメカジ,US古着',
            'hours': '13:00〜19:00',
            'holiday': '火曜日',
            'homepage_url': 'http://buttonupclothing.jp/',
            'sns_url': 'https://www.instagram.com/buttonupclothing',
            'description': 'アメリカ現地買い付けのヴィンテージ・US古着専門店。',
            'latitude': 40.6031, 'longitude': 140.4651,
        },
        {
            'name': 'CRAZY GARDENS',
            'address': '青森県弘前市取上2丁目14-1',
            'nearest_station': '弘前東高校前駅',
            'genres': 'US古着,アウトドア,ストリート',
            'hours': '平日 13:00〜20:00 / 土日祝 12:00〜20:00',
            'holiday': '水曜日',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/crazygardens',
            'description': 'ロサンゼルス買い付けのUS古着中心。ヒップホップ・レゲエが流れるラフな雰囲気。',
            'latitude': 40.5946, 'longitude': 140.4891,
        },
        {
            'name': '古着屋 B',
            'address': '青森県弘前市大町3丁目2-9 1F',
            'nearest_station': '弘前駅',
            'genres': 'ストリート,Y2K,ヴィンテージ',
            'hours': '13:00〜20:00',
            'holiday': '不定休',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/b__aomori',
            'description': 'Stussy・Nike・Adidasなどのストリート・Y2Kアイテムが中心。',
            'latitude': 40.6032, 'longitude': 140.4659,
        },
        {
            'name': 'FESTINA LENTE 弘前店',
            'address': '青森県弘前市代官町22A',
            'nearest_station': '中央弘前駅',
            'genres': 'ヴィンテージ',
            'hours': '11:00〜16:00',
            'holiday': '水曜日',
            'homepage_url': 'https://festinalente.theshop.jp/',
            'sns_url': 'https://www.instagram.com/festinalente.shop',
            'description': 'アメリカ買い付けの上質なヴィンテージ古着・アンティーク雑貨。2025年4月オープン。',
            'latitude': 40.5993, 'longitude': 140.4743,
        },
        # ── 黒石市 ────────────────────────────────────────────
        {
            'name': 'FESTINA LENTE 黒石VINTAGE',
            'address': '青森県黒石市横町14-4 ストゼン+101',
            'nearest_station': '黒石駅',
            'genres': 'ヴィンテージ',
            'hours': '土日 12:00〜18:00 / 月火 13:00〜18:00',
            'holiday': '不定休（Instagram要確認）',
            'homepage_url': 'https://festinalente.theshop.jp/',
            'sns_url': 'https://www.instagram.com/festinalente.vintage',
            'description': 'アメリカ買い付けの上質なヴィンテージ古着とアンティーク雑貨を扱う黒石の本店。',
            'latitude': 40.6432, 'longitude': 140.5978,
        },
        # ── 八戸市 ────────────────────────────────────────────
        {
            'name': 'DEMONSTRANDUM DSD',
            'address': '青森県八戸市下長3丁目9-7',
            'nearest_station': '本八戸駅',
            'genres': 'US古着,ヴィンテージ,アメカジ,ミリタリー',
            'hours': '12:00〜20:00（土日祝 12:00〜19:00）',
            'holiday': '火・水・木曜日',
            'homepage_url': 'https://demonstrandum-dsd.com/',
            'sns_url': 'https://www.instagram.com/demonstrandum.dsd',
            'description': 'US古着・ヴィンテージ・ミリタリーを扱う八戸のセレクト系古着屋。',
            'latitude': 40.5115, 'longitude': 141.4712,
        },
        {
            'name': '古着倶楽部 八戸',
            'address': '青森県八戸市青葉1丁目18-19',
            'nearest_station': '本八戸駅',
            'genres': 'ヴィンテージ,ブランド古着,US古着',
            'hours': '',
            'holiday': 'なし',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/furugiclub_hachinohe',
            'description': 'ヴィンテージ・ブランド古着・US古着を扱う。買取・委託販売も実施。',
            'latitude': 40.5057, 'longitude': 141.4876,
        },
        {
            'name': 'Yellow Bullbon',
            'address': '青森県八戸市馬場町11-1 Fine Hills 1F',
            'nearest_station': '本八戸駅',
            'genres': 'US古着,スポーツ,ヴィンテージ',
            'hours': '13:00〜19:00',
            'holiday': '不定休',
            'homepage_url': 'http://www.yellowbullbon.com',
            'sns_url': 'https://www.instagram.com/yellowbullbon',
            'description': 'Champion等アメリカンスポーツウェアのUS古着・ヴィンテージ専門店。',
            'latitude': 40.5023, 'longitude': 141.4869,
        },
        {
            'name': 'ムジンノフクヤ 八戸白銀店',
            'address': '青森県八戸市白銀町浜崖7-7',
            'nearest_station': '本八戸駅',
            'genres': 'US古着,ブランド古着',
            'hours': '24時間営業',
            'holiday': 'なし',
            'homepage_url': 'https://mujinfukuya.thebase.in/',
            'sns_url': 'https://www.instagram.com/mujinnofukuya_8shirogane',
            'description': '無人店舗（券売機精算）の古着屋。海外輸入古着を24時間販売。東北初出店。',
            'latitude': 40.5397, 'longitude': 141.5036,
        },
        {
            'name': 'OTTO',
            'address': '青森県八戸市大字鳥屋部町14-2 1F',
            'nearest_station': '本八戸駅',
            'genres': 'ヴィンテージ,その他',
            'hours': '木〜火 11:00〜20:00',
            'holiday': '水曜日',
            'homepage_url': '',
            'sns_url': '',
            'description': '服・雑貨・家具まで幅広い品揃えの知る人ぞ知る八戸の古着屋。',
            'latitude': 40.5012, 'longitude': 141.4891,
        },
        {
            'name': 'プライスドロップ 類家店',
            'address': '青森県八戸市南類家3丁目2-8',
            'nearest_station': '本八戸駅',
            'genres': 'その他',
            'hours': '〜19:00',
            'holiday': '火曜日',
            'homepage_url': 'https://yorozuya-dc.com/store/shop-14/',
            'sns_url': 'https://www.instagram.com/pricedrop8ruike',
            'description': '萬屋グループのアウトレット専門店。古着・日用品・雑貨・ホビーを取り扱う。',
            'latitude': 40.5012, 'longitude': 141.5002,
        },
        # ── 十和田市 ──────────────────────────────────────────
        {
            'name': '四次元ポケット 十和田店',
            'address': '青森県十和田市東一番町7-5',
            'nearest_station': '三沢駅',
            'genres': 'ブランド古着,その他',
            'hours': '10:00〜19:00',
            'holiday': 'なし',
            'homepage_url': 'https://www.yojigenpk.com/',
            'sns_url': 'https://www.instagram.com/yojigentowada10',
            'description': 'リサイクル全般を扱うショップ。ブランド古着・Supreme等も強化中。弘前・黒石・十和田に展開。',
            'latitude': 40.5247, 'longitude': 141.2265,
        },
    ]

    for d in aomori_shops:
        db.session.add(Shop(
            name=d['name'],
            address=d.get('address', ''),
            nearest_station=d.get('nearest_station', ''),
            genres=d.get('genres', ''),
            hours=d.get('hours', ''),
            holiday=d.get('holiday', 'なし'),
            homepage_url=d.get('homepage_url', ''),
            sns_url=d.get('sns_url', ''),
            description=d.get('description', ''),
            price_range=d.get('price_range', '不明'),
            payment_methods=d.get('payment_methods', '不明'),
            parking=d.get('parking', ''),
            latitude=d['latitude'],
            longitude=d['longitude'],
            rating=0.0,
            review_count=0,
            place_id='',
            plus_code='',
        ))
    db.session.commit()
    print(f"✅ 青森県の古着屋 {len(aomori_shops)} 件を追加しました")


def seed_data():
    db.create_all()
    migrate_db()

    if Article.query.count() == 0:
        print("🌱 記事データを移行中...")
        initial_articles = [
            {
                "title": "古着屋マップについて",
                "content": "年に数百店舗以上巡る、学生が作る古着屋マップとなっています。情報がまだ足りないところもあり、まだ未完成となっています。将来的にはアプリ化も目指しています！各種SNSも始めるので、ぜひフォローよろしくお願いします。自分自身学生で、お金が少ないときもバイトで稼いだお金でいろんな古着屋を回ってきました。その中で今のSNSやグーグルマップを頼りに商品をディグリにめぐりました。しかし、実際に行っても自分の求めている店舗には巡り合わせることは難しく、お気に入りを見つけるのに苦戦しました。自分だけでなく全国の古着好きに新しい古着屋を見つけてもらいたいという思いでマップを作っています。まだまだ不備はたくさんありますが、ぜひ利用してレビューしていただきたいです。",
                "genre": "古着屋マップ公式",
                "date": "2025-12-14"
            },
            {
                "title": "セカストウィーク！",
                "content": "2025/12/05～2025/12/14でセカストウィーク開催中！...",
                "genre": "デニム",
                "date": "2025-12-04"
            },
            {
                "title": "下北沢のおすすめランチ",
                "content": "古着屋巡りの合間に行きたい、美味しいカレー屋さんを紹介...",
                "genre": "コラム",
                "date": "2025-01-20"
            }
        ]
        for a in initial_articles:
            art = Article(**a)
            db.session.add(art)
        db.session.commit()
        print("✅ 記事データの移行完了！")

    if Admin.query.count() == 0:
        db.session.add(Admin(password="admin"))
        db.session.commit()
        print("✅ 管理者パスワード設定完了（admin）")

    seed_aomori_shops()

# gunicorn・直接実行どちらでも起動時にDB初期化
with app.app_context():
    seed_data()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)