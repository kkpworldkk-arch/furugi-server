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
    "methods": ["GET", "POST", "PATCH", "DELETE", "OPTIONS"]
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

class ShopMedia(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    shop_id = db.Column(db.Integer, db.ForeignKey('shop.id'), nullable=False)
    title = db.Column(db.String(200))
    source = db.Column(db.String(100))   # 掲載メディア名
    url = db.Column(db.String(500), default='')
    description = db.Column(db.String(500), default='')
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

@app.route('/api/shops/<int:shop_id>', methods=['DELETE'])
def delete_shop(shop_id):
    shop = Shop.query.get_or_404(shop_id)
    Review.query.filter_by(shop_id=shop_id).delete()
    Notice.query.filter_by(shop_id=shop_id).delete()
    ShopMedia.query.filter_by(shop_id=shop_id).delete()
    db.session.delete(shop)
    db.session.commit()
    return jsonify({"message": "Deleted"}), 200

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

@app.route('/api/shops/<int:shop_id>/media', methods=['GET'])
def get_media(shop_id):
    items = ShopMedia.query.filter_by(shop_id=shop_id).order_by(ShopMedia.id.desc()).all()
    return jsonify([{
        "id": m.id,
        "title": m.title or '',
        "source": m.source or '',
        "url": m.url or '',
        "description": m.description or '',
        "date": m.date or '',
    } for m in items])

@app.route('/api/shops/<int:shop_id>/media', methods=['POST'])
def add_media(shop_id):
    Shop.query.get_or_404(shop_id)
    data = request.json
    media = ShopMedia(
        shop_id=shop_id,
        title=data.get('title', ''),
        source=data.get('source', ''),
        url=data.get('url', ''),
        description=data.get('description', ''),
        date=datetime.now().strftime('%Y-%m-%d'),
    )
    db.session.add(media)
    db.session.commit()
    return jsonify({"message": "Media added"}), 201

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

@app.route('/api/admin/seed_akita', methods=['POST'])
def admin_seed_akita():
    data = request.json or {}
    admin = Admin.query.first()
    if not admin or admin.password != data.get('password'):
        return jsonify({"error": "NG"}), 401
    with app.app_context():
        seed_akita_shops()
    count = Shop.query.filter(Shop.address.like('%秋田%')).count()
    return jsonify({"message": "完了", "akita_count": count}), 200

@app.route('/api/admin/seed_iwate', methods=['POST'])
def admin_seed_iwate():
    data = request.json or {}
    admin = Admin.query.first()
    if not admin or admin.password != data.get('password'):
        return jsonify({"error": "NG"}), 401
    seed_iwate_shops()
    count = Shop.query.filter(Shop.address.like('%岩手%')).count()
    return jsonify({"message": "完了", "iwate_count": count}), 200

@app.route('/api/admin/seed_aomori', methods=['POST'])
def admin_seed_aomori():
    data = request.json or {}
    admin = Admin.query.first()
    if not admin or admin.password != data.get('password'):
        return jsonify({"error": "NG"}), 401
    with app.app_context():
        seed_aomori_shops()
    count = Shop.query.filter(Shop.address.like('%青森%')).count()
    return jsonify({"message": "完了", "aomori_count": count}), 200

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
    """青森県の古着屋データを追加（各店舗ごとに重複チェック）"""
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

    added = 0
    for d in aomori_shops:
        if Shop.query.filter_by(name=d['name']).first():
            continue
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
        added += 1
    db.session.commit()
    print(f"✅ 青森県の古着屋 {added} 件を追加しました（スキップ: {len(aomori_shops) - added} 件）")


def seed_akita_shops():
    """秋田県の古着屋データを追加（各店舗ごとに重複チェック）"""
    akita_shops = [
        # ── 秋田市 ────────────────────────────────────────────
        {
            'name': '古着屋Alright（オールライト）',
            'address': '秋田県秋田市中通2-8-1 フォンテAKITA 2F',
            'nearest_station': '秋田駅',
            'genres': 'US古着,ヴィンテージ,アメカジ,レディース',
            'hours': '10:00〜20:00',
            'holiday': '不定休（フォンテAKITAに準ずる）',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/alright_worldwide_recycle/',
            'description': '秋田駅西口から徒歩約2分、フォンテAKITA2階。80s〜90s USA製スウェット・ナイロンジャケット・リーバイスなど、コスパに優れたレギュラーヴィンテージが中心。価格帯3,000〜8,000円。',
            'latitude': 39.7188, 'longitude': 140.1028,
        },
        {
            'name': 'BUP 秋田OPA店',
            'address': '秋田県秋田市千秋久保田町4-2 秋田OPA 5F',
            'nearest_station': '秋田駅',
            'genres': 'US古着,ヴィンテージ',
            'hours': '10:00〜20:00',
            'holiday': '不定休（OPAに準ずる）',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/bup_japan_akita/',
            'description': '秋田OPA5階に入る古着専門店。アメリカ古着を低価格で展開。アクセサリーやアートアイテムも取り扱う。秋田駅西口から徒歩約3分。',
            'latitude': 39.7199, 'longitude': 140.1021,
        },
        {
            'name': 'DINER018 秋田駅前本店',
            'address': '秋田県秋田市大町2丁目4-23',
            'nearest_station': '秋田駅',
            'genres': 'ヴィンテージ,アメカジ,US古着',
            'hours': '平日14:00〜20:00 / 土日祝13:00〜19:00',
            'holiday': '不定休（Instagramで告知）',
            'homepage_url': 'https://diner018.thebase.in/',
            'sns_url': 'https://www.instagram.com/diner018.akita/',
            'description': 'アメリカから直接買い付けたリアルなヴィンテージアイテムをキュレーションするアメカジ専門店。オンラインショップも運営。',
            'latitude': 39.7168, 'longitude': 140.0987,
        },
        {
            'name': 'BOROS',
            'address': '秋田県秋田市中通3丁目4-5',
            'nearest_station': '秋田駅',
            'genres': 'ヴィンテージ,US古着,レディース',
            'hours': '平日14:00〜19:00 / 土日祝13:00〜20:00',
            'holiday': '不定休（Instagramで告知）',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/boros_vintage/',
            'description': '秋田市中通に位置する個性派ビンテージショップ。アメリカ・ヨーロッパのビンテージを中心に、メンズ・レディース問わず幅広く取り揃える。',
            'latitude': 39.7178, 'longitude': 140.1002,
        },
        {
            'name': 'FANCYWALK',
            'address': '秋田県秋田市中通5-5-31 芙水ビル1F',
            'nearest_station': '秋田駅',
            'genres': 'ヴィンテージ,アメカジ,レディース',
            'hours': '13:00〜19:00',
            'holiday': '不定休',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/fancywalk57/',
            'description': '1940年代〜80年代を中心としたヴィンテージ古着を専門に扱う、秋田有数の本格派ショップ。アンティーク雑貨も併せて展開。',
            'latitude': 39.7155, 'longitude': 140.1010,
        },
        {
            'name': '古着屋アンディ&キャロライン',
            'address': '秋田県秋田市中通6丁目14-11',
            'nearest_station': '秋田駅',
            'genres': 'ヴィンテージ,レディース',
            'hours': '不定期営業（Instagramで確認）',
            'holiday': '不定休',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/andy00caroline/',
            'description': 'オーナー自ら手を加えた世界にひとつだけのリメイクピースを展開するユニーク古着店。',
            'latitude': 39.7142, 'longitude': 140.1015,
        },
        {
            'name': 'GB Vintage shop',
            'address': '秋田県秋田市保戸野中町1-2',
            'nearest_station': '秋田駅',
            'genres': 'US古着,ストリート,アメカジ,アウトドア,レディース',
            'hours': '13:00〜19:00',
            'holiday': '不定休',
            'homepage_url': 'https://gbvintage.base.shop/',
            'sns_url': 'https://www.instagram.com/gb_vintage_shop/',
            'description': '海外輸入古着を中心にストリート・アメカジ・アウトドアなど幅広いジャンルを男女問わず展開。美容室が併設されたユニークな複合スペース。',
            'latitude': 39.7225, 'longitude': 140.1098,
        },
        {
            'name': 'SINUS.',
            'address': '秋田県秋田市東通仲町9-5',
            'nearest_station': '秋田駅',
            'genres': 'US古着,ヴィンテージ,レディース',
            'hours': '12:00〜19:00',
            'holiday': '不定休',
            'homepage_url': 'https://sinus60.thebase.in/',
            'sns_url': 'https://www.instagram.com/sinus.used/',
            'description': '秋田駅東口近くにある古着屋。アメリカ・ヨーロッパの個性豊かなデザインの古着を中心に取り揃え。素材の質感や着心地を重視した買い付けが特徴。',
            'latitude': 39.7192, 'longitude': 140.1075,
        },
        {
            'name': 'いいべ',
            'address': '秋田県秋田市中通3-3-1',
            'nearest_station': '秋田駅',
            'genres': 'ヴィンテージ,US古着,レディース',
            'hours': '10:30〜18:00（火・水は〜17:00）',
            'holiday': '月曜（祝日の場合は翌日休）',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/iibe__akita/',
            'description': '都内セレクトショップ勤務経験を持つ夫婦が秋田に移住して開業。秋田の四季に合わせた古着を3,000円台〜でセレクト。店内に郷土玩具など秋田の特産品も並ぶ。',
            'latitude': 39.7175, 'longitude': 140.1003,
        },
        {
            'name': 'Gallant-doo',
            'address': '秋田県秋田市広面字昼寝46-4',
            'nearest_station': '秋田駅',
            'genres': 'ヴィンテージ,ミリタリー,US古着',
            'hours': '月・金 15:00〜19:00 / 土・日 10:00〜19:00',
            'holiday': '火・水・木曜日',
            'homepage_url': 'https://gallant-doo.com/',
            'sns_url': '',
            'description': '欧米から直接仕入れたデイリーウエア・ミリタリー・ヴィンテージ・アンティークを1,000点以上取り揃えるセレクト店。ヴィンテージ腕時計・ジュエリー・雑貨も展開。',
            'latitude': 39.7130, 'longitude': 140.1162,
        },
        {
            'name': 'REAL MOON 秋田店',
            'address': '秋田県秋田市東通5-8-25',
            'nearest_station': '秋田駅',
            'genres': 'アメカジ,ヴィンテージ,US古着',
            'hours': '11:00〜19:00',
            'holiday': '毎週火曜・水曜',
            'homepage_url': 'https://www.realmoon.co.jp/',
            'sns_url': 'https://www.instagram.com/realmoon_store/',
            'description': '1996年創業のアメカジ専門店。アメリカのクラフツマンブランドとジャパニーズブランドを中心にセレクト。湯沢に本店あり。',
            'latitude': 39.7215, 'longitude': 140.1082,
        },
        # ── 大仙市 ────────────────────────────────────────────
        {
            'name': 'sit in',
            'address': '秋田県大仙市大曲通町2-31',
            'nearest_station': '大曲駅',
            'genres': 'ヴィンテージ,US古着,レディース',
            'hours': '11:00〜18:00',
            'holiday': '水曜日',
            'homepage_url': 'https://akita-sitin.shopinfo.jp/',
            'sns_url': 'https://www.instagram.com/sitinclothing/',
            'description': '大仙市大曲の古着専門店。大曲駅から徒歩圏内に位置し、通販にも対応。',
            'latitude': 39.4817, 'longitude': 140.4782,
        },
        # ── 湯沢市 ────────────────────────────────────────────
        {
            'name': 'made in TIGER',
            'address': '秋田県湯沢市大町1-1-1 大友ビル1F',
            'nearest_station': '湯沢駅',
            'genres': 'US古着,アメカジ,レディース',
            'hours': '12:00〜20:00',
            'holiday': '不定休',
            'homepage_url': '',
            'sns_url': '',
            'description': '湯沢市出身の店主が地元で開業。関東から買い付けたアウター・スウェット・シャツを中心に、リーズナブルな価格帯でラインアップ。',
            'latitude': 39.1645, 'longitude': 140.4952,
        },
        {
            'name': 'REAL MOON 湯沢店',
            'address': '秋田県湯沢市元清水2-5-8',
            'nearest_station': '湯沢駅',
            'genres': 'アメカジ,ヴィンテージ,US古着',
            'hours': '11:00〜19:00',
            'holiday': '毎週木曜・金曜',
            'homepage_url': 'https://www.realmoon.co.jp/',
            'sns_url': 'https://www.instagram.com/realmoon_store/',
            'description': '1996年創業のREAL MOON本店。アメリカン・ゴールデンエイジのヴィンテージからインスパイアされた商品とアメカジブランド正規品を販売。',
            'latitude': 39.1638, 'longitude': 140.4928,
        },
    ]

    added = 0
    for d in akita_shops:
        if Shop.query.filter_by(name=d['name']).first():
            continue
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
        added += 1
    db.session.commit()
    print(f"✅ 秋田県の古着屋 {added} 件を追加しました（スキップ: {len(akita_shops) - added} 件）")


def seed_iwate_shops():
    """岩手県の古着屋データを追加（各店舗ごとに重複チェック）"""
    iwate_shops = [
        # ── 盛岡市 ────────────────────────────────────────────
        {
            'name': 'Brownstone',
            'address': '岩手県盛岡市開運橋通り1-2 アイビルK1F',
            'nearest_station': '盛岡駅',
            'genres': 'ヴィンテージ,アメカジ,US古着',
            'hours': '月〜土 11:00〜20:00 / 日 11:00〜19:00',
            'holiday': '年末年始',
            'homepage_url': 'http://brs.brownstone.jp/',
            'sns_url': 'https://www.instagram.com/morioka_brownstone/',
            'description': '海外から直接買い付けた幅広いラインナップの古着屋。「いい洋服屋を目指している」をコンセプトに、90年代ファッションやレトロアイテムを中心にセレクト。盛岡を代表するヴィンテージショップ。',
            'latitude': 39.7034, 'longitude': 141.1380,
        },
        {
            'name': 'LOVELOCK',
            'address': '岩手県盛岡市開運橋通1-40',
            'nearest_station': '盛岡駅',
            'genres': 'ヴィンテージ,US古着,レディース',
            'hours': '月〜土 11:00〜20:00 / 日 11:00〜19:00',
            'holiday': '年末年始',
            'homepage_url': 'https://lvl.brownstone.jp/',
            'sns_url': 'https://www.instagram.com/lovelock_morioka/',
            'description': 'Brownstoneの姉妹店。アメリカから直接買い付けたUsed&Vintageを中心に、アジアンテイストの海外ヴィンテージも取り扱うレディース中心のショップ。',
            'latitude': 39.7036, 'longitude': 141.1378,
        },
        {
            'name': 'cheapchic',
            'address': '岩手県盛岡市中央通1丁目12-1',
            'nearest_station': '盛岡駅',
            'genres': 'ヴィンテージ,US古着,レディース',
            'hours': '11:00〜19:00',
            'holiday': '不定休',
            'homepage_url': 'https://www.cheapchic-japan.com/',
            'sns_url': 'https://www.instagram.com/cheapchic_used/',
            'description': 'アメリカ・ヨーロッパから直接買い付けたヴィンテージが並ぶ。70年代ヴィンテージを中心に衣類・靴・アンティーク雑貨まで揃い、パリの蚤の市のような空間が魅力。',
            'latitude': 39.7066, 'longitude': 141.1430,
        },
        {
            'name': 'gee,jee 盛岡',
            'address': '岩手県盛岡市大通1-4-10 照井ビル2F',
            'nearest_station': '上盛岡駅',
            'genres': 'ブランド古着,アメカジ,レディース',
            'hours': '平日 11:00〜19:30 / 日・祝 11:00〜19:00',
            'holiday': '木曜日',
            'homepage_url': 'https://happypoint.jp/geejee/',
            'sns_url': 'https://www.instagram.com/geejee_morioka/',
            'description': '東北最大級のブランド古着専門店。DCブランド・アメカジブランド・国内ブランドの衣類・小物・アクセサリー・靴を幅広く取り扱う。高価買取・宅配買取にも対応。',
            'latitude': 39.7057, 'longitude': 141.1415,
        },
        {
            'name': 'レトロブティックことり',
            'address': '岩手県盛岡市城西町13-15',
            'nearest_station': '盛岡駅',
            'genres': 'ヴィンテージ,レディース,その他',
            'hours': '日〜金 12:00〜19:00 / 土 12:00〜20:00',
            'holiday': '火曜日',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/cobicobi1129/',
            'description': '「真剣にふざける」をモットーとした個性派古着屋。海外レトロアイテムから和柄ファッションまで取り扱い、オリジナルリメイクブランド「COBICOBI」・昭和レトロ雑貨も販売。',
            'latitude': 39.7042, 'longitude': 141.1328,
        },
        {
            'name': 'one and only',
            'address': '岩手県盛岡市本宮3丁目10-11',
            'nearest_station': '盛岡駅',
            'genres': 'ヴィンテージ,US古着,アメカジ,ストリート',
            'hours': '月・木〜日 12:00〜20:00',
            'holiday': '火曜日・水曜日',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/one_and_only_2007/',
            'description': '盛岡のヴィンテージ・アメカジ系古着の人気店。アメリカンヴィンテージを中心に幅広いジャンルを取り扱う。駐車場完備。',
            'latitude': 39.7100, 'longitude': 141.1290,
        },
        {
            'name': 'JIKAI',
            'address': '岩手県盛岡市長田町2-24 シャトルながまち1F',
            'nearest_station': '盛岡駅',
            'genres': 'ストリート,ブランド古着,レディース',
            'hours': '12:00〜19:00',
            'holiday': '不定休',
            'homepage_url': 'https://jikaionline.com/',
            'sns_url': 'https://www.instagram.com/jikai_morioka/',
            'description': '古着×デザイナーズブランドのハイブリッドセレクトショップ。SUGARHILL・NVRFRGTなど国内外の注目ブランドを20社以上取り扱う盛岡発のセレクトショップ。',
            'latitude': 39.7115, 'longitude': 141.1240,
        },
        {
            'name': 'Jeans Shop 3rd Down',
            'address': '岩手県盛岡市三本柳5地割31-1 セブンハイツ103',
            'nearest_station': '岩手飯岡駅',
            'genres': 'ヴィンテージ,アメカジ,ミリタリー,ワーク',
            'hours': '12:00〜19:00',
            'holiday': '木曜日',
            'homepage_url': 'https://jeans3rddown.base.shop/',
            'sns_url': 'https://www.instagram.com/jeans_shop_3rd_down/',
            'description': '日本製ジーンズ専門。SUGAR CANE・BUZZ RICKSON\'Sなどアメリカンヴィンテージレプリカブランドを中心にセレクト。チェーンステッチミシンによる裾上げサービスも実施。',
            'latitude': 39.7180, 'longitude': 141.1550,
        },
        {
            'name': 'NORA antiques',
            'address': '岩手県盛岡市鉈屋町2-19',
            'nearest_station': '仙北町駅',
            'genres': 'ヴィンテージ,レディース,その他',
            'hours': '不定期（Instagram参照）',
            'holiday': '不定休',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/nora1985cat/',
            'description': '古布（ボロ）を使ったリメイクアイテムとフランスヴィンテージ古着を専門とするアトリエ兼ショップ。古い布に新たな命を吹き込むリメイク作品が人気。盛岡の歴史ある鉈屋町エリアに位置する。',
            'latitude': 39.7048, 'longitude': 141.1468,
        },
        # ── 花巻市 ────────────────────────────────────────────
        {
            'name': 'BLEND STORE',
            'address': '岩手県花巻市上町13-34 1階',
            'nearest_station': '花巻駅',
            'genres': 'ヴィンテージ,US古着,ストリート,レディース',
            'hours': '平日 13:00〜19:00 / 土日祝 12:00〜19:00',
            'holiday': '月曜日',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/blend___store/',
            'description': 'ダンススタジオと古着屋を兼ねた複合スペース。個性的な品揃えで地元カルチャーの発信拠点となっている。',
            'latitude': 39.3880, 'longitude': 141.1160,
        },
        # ── 奥州市 ────────────────────────────────────────────
        {
            'name': 'VILLAGE IMPORT',
            'address': '岩手県奥州市水沢後田17-5',
            'nearest_station': '水沢駅',
            'genres': 'US古着,アメカジ,ヴィンテージ',
            'hours': '平日 14:00〜19:00 / 土日祝 11:00〜19:00',
            'holiday': '水曜日',
            'homepage_url': 'https://village-import.com/',
            'sns_url': 'https://www.instagram.com/village.import/',
            'description': 'アメリカ古着・雑貨の専門店。本場アメリカから直輸入したUS古着やアメリカン雑貨を豊富に取り揃える。',
            'latitude': 39.1430, 'longitude': 141.1370,
        },
        {
            'name': '古着天国 OLD ROCKET',
            'address': '岩手県奥州市水沢真城柿ノ木下59-3',
            'nearest_station': '水沢駅',
            'genres': 'ヴィンテージ,US古着,アメカジ',
            'hours': '平日 12:00〜18:00 / 土日祝 11:00〜18:00',
            'holiday': '水曜日',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/furugi_paradise.oldrocket/',
            'description': '奥州市水沢エリアの古着屋。海外輸入ヴィンテージ古着・雑貨・小物を中心に取り扱い、取り置きサービスにも対応（DM・電話可）。',
            'latitude': 39.1350, 'longitude': 141.1340,
        },
    ]

    added = 0
    for d in iwate_shops:
        if Shop.query.filter_by(name=d['name']).first():
            continue
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
        added += 1
    db.session.commit()
    print(f"✅ 岩手県の古着屋 {added} 件を追加しました（スキップ: {len(iwate_shops) - added} 件）")


def seed_yamagata_shops():
    """山形県の古着屋データを追加（各店舗ごとに重複チェック）"""
    yamagata_shops = [
        # ── 山形市 ────────────────────────────────────────────
        {
            'name': '無人古着屋NOTIME 山形店',
            'address': '山形県山形市美畑町12-27 南栄ビル1階',
            'nearest_station': '山形駅',
            'genres': 'アメカジ,ベーシック',
            'hours': '24時間営業',
            'holiday': 'なし',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/notime_yamagata/',
            'description': '山形市初の24時間365日営業無人古着屋。LINE解錠式で入店しセルフレジで決済。ベーシックなアメカジを中心に手頃な価格で展開。駐車場9台完備。',
            'price_range': '不明',
            'payment_methods': '電子マネー・スマホバーコード決済',
            'parking': 'あり（9台）',
            'latitude': 38.2351, 'longitude': 140.3262,
        },
        {
            'name': 'SQUAT（スクワット）',
            'address': '山形県山形市十日町4-3-14',
            'nearest_station': '山形駅',
            'genres': 'ヨーロッパヴィンテージ,ミリタリー,ワークウェア',
            'hours': '11:00-20:00',
            'holiday': '不定休',
            'homepage_url': 'https://squat.shop-pro.jp/',
            'sns_url': 'https://www.instagram.com/squat_used_clothing/',
            'description': '1900年代〜1980年代のヨーロッパ直輸入ヴィンテージ専門店。ワークウェア・ミリタリー・欧州アヴァンギャルドを中心に展開する山形の老舗。仙台にも姉妹店あり。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2523, 'longitude': 140.3572,
        },
        {
            'name': 'MUNDO NOVO（ムンドノーボ）',
            'address': '山形県山形市南三番町11-26',
            'nearest_station': '山形駅',
            'genres': 'レディース,ヨーロッパヴィンテージ',
            'hours': '13:00-19:00',
            'holiday': '不定休',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/mundonovo___/',
            'description': 'SQUATオーナーが営むレディース向けヨーロッパ古着セレクトショップ。手頃な価格でヨーロッパの古着・小物を厳選。全国でも珍しい欧州レディース専門店。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': 'あり（3台）',
            'latitude': 38.2472, 'longitude': 140.3598,
        },
        {
            'name': 'antique store LIFE（ライフ）',
            'address': '山形県山形市緑町3-16-5',
            'nearest_station': '山形駅',
            'genres': 'アメリカンヴィンテージ,ネイティブジュエリー',
            'hours': '12:00-19:00',
            'holiday': '不定休',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/lifeyamagata/',
            'description': 'アメリカで買い付けたヴィンテージ古着とネイティブアメリカンジュエリーを専門に扱うセレクトショップ。アンティーク雑貨も豊富。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2538, 'longitude': 140.3424,
        },
        {
            'name': 'Sunny Collection（サニーコレクション）',
            'address': '山形県山形市西田2-4-13',
            'nearest_station': '山形駅',
            'genres': 'アメカジ,ミリタリー,アウトドア',
            'hours': '10:30-19:00',
            'holiday': '月曜・火曜・水曜',
            'homepage_url': 'https://sunnycollection.jp/',
            'sns_url': 'https://www.instagram.com/sunnycollection/',
            'description': '山形市西バイパス沿いのアメカジ専門古着屋。カフェ併設で80〜90年代を中心とした厳選ヴィンテージをゆったりと選べる。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': 'あり',
            'latitude': 38.2383, 'longitude': 140.3142,
        },
        {
            'name': 'hawdacot（ハウダコット）山形',
            'address': '山形県山形市本町1-4-23 細谷ビル1F',
            'nearest_station': '山形駅',
            'genres': 'ヴィンテージ,US古着,レディース',
            'hours': '12:00-20:00',
            'holiday': '不定休',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/hawdacot_yamagata/',
            'description': '90年代以降の良質なヴィンテージを幅広く展開。埼玉発の古着ブランドが山形に出店。全年代・男女問わず楽しめる。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2499, 'longitude': 140.3548,
        },
        {
            'name': 'Drops（ドロップス）',
            'address': '山形県山形市七日町2-4-1 1F',
            'nearest_station': '山形駅',
            'genres': 'レディース,アメリカ古着',
            'hours': '12:00-19:00',
            'holiday': '火曜・水曜',
            'homepage_url': '',
            'sns_url': '',
            'description': 'レンガビルが目印の七日町のレディース専門古着屋。アメリカ・カナダの古着とアクセサリーを取り扱う。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2494, 'longitude': 140.3542,
        },
        {
            'name': 'JAMMING（ジャミング）',
            'address': '山形県山形市本町1-7-20',
            'nearest_station': '山形駅',
            'genres': 'ヴィンテージ,US古着,アクセサリー',
            'hours': '11:30-19:00',
            'holiday': '不定休',
            'homepage_url': 'http://www.jamming-ymgt.com/',
            'sns_url': '',
            'description': 'ヴィンテージから新品まで扱う山形の古着屋。Ralph Lauren・J CREW・Levi\'sなどUSブランドや家具・アクセサリーも取り扱う。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2497, 'longitude': 140.3551,
        },
        {
            'name': 'one day store yamagata',
            'address': '山形県山形市七日町3-2-27',
            'nearest_station': '山形駅',
            'genres': 'US古着,80年代,90年代',
            'hours': '12:00-20:00',
            'holiday': '水曜',
            'homepage_url': 'https://onedaystore.official.ec/',
            'sns_url': 'https://www.instagram.com/one_day_store_yamagata/',
            'description': '新潟発の人気古着ショップの山形店。アメリカ直買い付けの80〜90年代ヴィンテージが中心。北米未発売のブランドアイテムも揃う。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2489, 'longitude': 140.3535,
        },
        {
            'name': 'ドンドンダウンオンウェンズデイ 山形バイパス店',
            'address': '山形県山形市上山家町字下宿760-1',
            'nearest_station': '山形駅',
            'genres': 'ヴィンテージ,ストリート,ハイブランド',
            'hours': '11:00-20:00',
            'holiday': '月曜',
            'homepage_url': '',
            'sns_url': '',
            'description': '山形バイパス沿いの大型古着店。ヴィンテージ・ストリート系からハイブランドまで幅広く取り扱う。価格は水曜日に全品値下げ。',
            'price_range': '¥5000~',
            'payment_methods': '現金・クレジット',
            'parking': 'あり',
            'latitude': 38.2558, 'longitude': 140.3821,
        },
        {
            'name': 'セカンドストリート 山形南館店',
            'address': '山形県山形市南館5丁目4-23',
            'nearest_station': '山形駅',
            'genres': 'ブランド,古着全般',
            'hours': '10:00-21:00',
            'holiday': 'なし',
            'homepage_url': '',
            'sns_url': '',
            'description': '山形市南部の大型セカンドストリート。駐車場133台完備。メンズ・レディース・キッズの古着・ブランド品を幅広く取り扱う。',
            'price_range': '¥1000~',
            'payment_methods': 'クレジットカード・スマホバーコード決済・現金',
            'parking': 'あり（133台）',
            'latitude': 38.2148, 'longitude': 140.3548,
        },
        {
            'name': 'お宝中古市場 山形南店',
            'address': '山形県山形市南館4-1-1',
            'nearest_station': '山形駅',
            'genres': '格安古着,リサイクル全般',
            'hours': '9:00-深夜2:00',
            'holiday': 'なし',
            'homepage_url': '',
            'sns_url': '',
            'description': '深夜まで営業する大型リサイクルショップ。格安古着から家電・家具まで幅広く取り扱う。',
            'price_range': '¥500~',
            'payment_methods': '現金・クレジット',
            'parking': 'あり',
            'latitude': 38.2155, 'longitude': 140.3536,
        },
        # ── 天童市 ────────────────────────────────────────────
        {
            'name': 'セカンドストリート 天童店',
            'address': '山形県天童市桜町11-30',
            'nearest_station': '天童駅',
            'genres': 'ブランド,古着全般',
            'hours': '10:00-21:00',
            'holiday': 'なし',
            'homepage_url': '',
            'sns_url': '',
            'description': '天童市の大型セカンドストリート。駐車場62台完備。古着・ブランド品・家電・家具を幅広く扱うリユースショップ。',
            'price_range': '¥1000~',
            'payment_methods': 'クレジットカード・スマホバーコード決済・現金',
            'parking': 'あり（62台）',
            'latitude': 38.3564, 'longitude': 140.3832,
        },
        {
            'name': '古着倉庫 イオンモール天童店',
            'address': '山形県天童市芳賀タウン北4丁目1-1 イオンモール天童2F',
            'nearest_station': '天童駅',
            'genres': 'USA古着,レギュラー古着,雑貨',
            'hours': '10:00-21:00',
            'holiday': 'なし',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/furugisouko_aeon_tendo_2023/',
            'description': 'イオンモール天童2Fに入る大型古着店。常時30000アイテム以上の品揃えでUSA古着を中心に新品・雑貨も取り扱う。',
            'price_range': '¥1000~',
            'payment_methods': '現金・クレジット',
            'parking': 'あり（商業施設共用）',
            'latitude': 38.3516, 'longitude': 140.3728,
        },
        # ── 米沢市 ────────────────────────────────────────────
        {
            'name': '古着倉庫 米沢店',
            'address': '山形県米沢市中田町514-1',
            'nearest_station': '米沢駅',
            'genres': 'USA古着,レギュラー古着',
            'hours': '平日12:00-19:30 / 土日祝11:00-19:00',
            'holiday': '不定休',
            'homepage_url': 'https://souko2017.thebase.in/',
            'sns_url': 'https://www.instagram.com/furugisouko2017/',
            'description': '置賜エリア最大級の古着屋。USA古着を中心にレギュラー古着も豊富に揃える。Instagramフォロワー1万超えの人気店。',
            'price_range': '¥1000~',
            'payment_methods': '現金',
            'parking': 'あり',
            'latitude': 37.9272, 'longitude': 140.1232,
        },
        # ── 酒田市 ────────────────────────────────────────────
        {
            'name': "Janky's（ジャンキーズ）",
            'address': '山形県酒田市御成町12-10',
            'nearest_station': '酒田駅',
            'genres': 'US古着,ヴィンテージ,ヨーロッパ古着',
            'hours': '12:00-20:00',
            'holiday': '火曜',
            'homepage_url': '',
            'sns_url': '',
            'description': '酒田駅から徒歩8分の穴場古着店。アメリカ・ヨーロッパの古着を直輸入。ヴィンテージからレギュラーまで豊富な品揃え。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': 'なし',
            'latitude': 38.9164, 'longitude': 139.8493,
        },
        {
            'name': 'オフハウス 酒田店',
            'address': '山形県酒田市ゆたか2-1-10',
            'nearest_station': '酒田駅',
            'genres': '古着全般,ブランド',
            'hours': '10:00-19:00',
            'holiday': 'なし',
            'homepage_url': '',
            'sns_url': '',
            'description': 'ハードオフグループの衣類専門リユースショップ。ノンブランドからハイブランド・ヴィンテージまで幅広い衣料品を取り扱う。',
            'price_range': '¥1000~',
            'payment_methods': '現金・クレジット',
            'parking': 'あり',
            'latitude': 38.9188, 'longitude': 139.8437,
        },
    ]

    added = 0
    for d in yamagata_shops:
        if Shop.query.filter_by(name=d['name']).first():
            continue
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
        added += 1
    db.session.commit()
    print(f"✅ 山形県の古着屋 {added} 件を追加しました（スキップ: {len(yamagata_shops) - added} 件）")


def seed_miyagi_shops():
    """宮城県の古着屋データを追加（各店舗ごとに重複チェック）"""
    miyagi_shops = [
        # ── 仙台市 青葉区 中央エリア ────────────────────────────
        {
            'name': '古着屋JAM 仙台店',
            'address': '宮城県仙台市青葉区中央3丁目6-10 フージャース仙台駅前ビル1F',
            'nearest_station': '仙台駅',
            'genres': 'アメカジ,インポート古着,ヴィンテージ',
            'hours': '11:00-20:00',
            'holiday': '不定休',
            'homepage_url': 'https://jamtrading.jp/',
            'sns_url': 'https://www.instagram.com/furugiya_jam_official/',
            'description': '全国展開の海外古着専門チェーン。仙台駅から徒歩1分。ノースフェイスやパタゴニアのヴィンテージが1万円以下で揃う。自社クリーニング済みで品質が高い。',
            'price_range': '¥2000~',
            'payment_methods': '現金・クレジット・電子マネー',
            'parking': '',
            'latitude': 38.2615, 'longitude': 140.8772,
        },
        {
            'name': 'Hi-smile（ハイスマイル）',
            'address': '宮城県仙台市青葉区中央2丁目5-9 庄文堂ビル1F',
            'nearest_station': '仙台駅',
            'genres': 'アメカジ,デッドストック,US古着',
            'hours': '12:00-19:00',
            'holiday': '不定休',
            'homepage_url': 'https://www.hi-smile.com/',
            'sns_url': 'https://www.instagram.com/hi_smile_sendai/',
            'description': 'アメリカ買い付けの一点物やデッドストック品が豊富。日本未販売のレアアイテムが多く、「質の良い古着」を求める上級者向けの一店。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2632, 'longitude': 140.8718,
        },
        {
            'name': 'SHACK-A-LUCK（シャカラック）',
            'address': '宮城県仙台市青葉区中央2丁目10-3 第二MTビル2F',
            'nearest_station': '仙台駅',
            'genres': 'アメリカ古着,ストリート,レギュラー古着',
            'hours': '11:00-20:00',
            'holiday': '不定休',
            'homepage_url': 'https://shack.idcom.co.jp/',
            'sns_url': 'https://www.instagram.com/shackaluck/',
            'description': '古着初心者にも入りやすい手頃な価格のアメリカ古着屋。ネルシャツ・パーカー・スウェットなど定番アイテムが充実。90〜00年代レギュラー中心。',
            'price_range': '¥2000~',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2628, 'longitude': 140.8692,
        },
        {
            'name': 'DUROC（デュロック）',
            'address': '宮城県仙台市青葉区中央2丁目10-3 第二MTビル地下1F',
            'nearest_station': '仙台駅',
            'genres': 'アメリカ古着,レディース,ユニセックス',
            'hours': '11:00-20:00',
            'holiday': '不定休',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/duroc_sendai/',
            'description': 'SHACKALUCKの系列店。メンズ・レディース・ユニセックスのレギュラー古着を中心に展開。同ビル地下に位置するディープな一角。',
            'price_range': '¥2000~',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2628, 'longitude': 140.8692,
        },
        {
            'name': 'XXNT（メメント）',
            'address': '宮城県仙台市青葉区中央2丁目1-15 仙台マンション209',
            'nearest_station': '仙台駅',
            'genres': 'トラッド,モード,アーカイブ古着',
            'hours': '平日14:00-20:00 / 休日12:00-20:00',
            'holiday': '不定休',
            'homepage_url': 'https://xxnt.official.ec/',
            'sns_url': 'https://www.instagram.com/xxnt.sendai/',
            'description': 'トラッドやモードを再解釈した古着セレクト。ストーンアイランドやステューシーのアーカイブを扱う仙台屈指のモード系古着屋。東京三軒茶屋にも系列店あり。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2641, 'longitude': 140.8769,
        },
        {
            'name': 'bad ame（アム）',
            'address': '宮城県仙台市青葉区中央2丁目1-15 仙台マンション208',
            'nearest_station': '仙台駅',
            'genres': 'ゴシック,グランジ,パンク古着',
            'hours': '平日14:00-19:00 / 休日12:00-19:00',
            'holiday': '不定休',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/bad_ame_/',
            'description': 'XXNTメメントの系列店。グランジ・フェアリーグランジ・パンクなど独自スタイルの古着専門。2024年10月に原宿店もオープン。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2641, 'longitude': 140.8769,
        },
        {
            'name': 'the loom 仙台',
            'address': '宮城県仙台市青葉区中央2丁目1-15 仙台マンション103',
            'nearest_station': '仙台駅',
            'genres': 'レギュラー古着,アメリカ古着',
            'hours': '11:00-20:00',
            'holiday': '不定休',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/the.loom_sendai/',
            'description': '手頃な価格帯のレギュラー古着を中心に扱う仙台マンション内の古着屋。気軽に入れる雰囲気が特徴。',
            'price_range': '¥1000~',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2641, 'longitude': 140.8769,
        },
        {
            'name': 'VINTAGE SELECT CLOTHING CLIMB',
            'address': '宮城県仙台市青葉区中央2丁目6-14 光翠ビル4F',
            'nearest_station': '仙台駅',
            'genres': 'ストリート,アーカイブ,ヴィンテージ',
            'hours': '平日14:00-19:00 / 休日12:00-19:00',
            'holiday': '不定休',
            'homepage_url': 'https://climb.fashionstore.jp/',
            'sns_url': 'https://www.instagram.com/climb.sendai/',
            'description': '90年代裏原ブームのアイテムやクリスチャンディオールなどのアーカイブを展開。入手困難なレアアイテムが豊富なマニア向けセレクトショップ。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2630, 'longitude': 140.8713,
        },
        {
            'name': '西海岸ANCHOR 仙台店',
            'address': '宮城県仙台市青葉区中央2丁目4-5 アルボーレ仙台1F',
            'nearest_station': '仙台駅',
            'genres': 'ストリート,スポーツヴィンテージ,アメカジ',
            'hours': '11:00-20:00',
            'holiday': '不定休',
            'homepage_url': 'https://nisikaigan.com/',
            'sns_url': 'https://www.instagram.com/anchorsendai/',
            'description': '福岡発の西海岸ANCHOR仙台店。ストリートやスポーツブランドのヴィンテージが充実。カラフルで華やかなアイテムが特徴。',
            'price_range': '¥3000~',
            'payment_methods': '現金・クレジット',
            'parking': '',
            'latitude': 38.2635, 'longitude': 140.8726,
        },
        {
            'name': "TOM'S MARKET vintage",
            'address': '宮城県仙台市青葉区中央3丁目8-5 アメ横ビル2F',
            'nearest_station': '仙台駅',
            'genres': 'アメカジ,ミリタリー,ワーク古着',
            'hours': '11:00-18:00',
            'holiday': '火曜・水曜',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/toms_market_vintage/',
            'description': '仙台アメ横ビル2Fの老舗古着屋。2022年に再オープン。アメカジ・ミリタリー・ワーク系を中心に、状態の良いヴィンテージをリペア済みで展開。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2622, 'longitude': 140.8758,
        },
        {
            'name': 'BIG TIME 仙台',
            'address': '宮城県仙台市青葉区中央2丁目5-10 1F・2F',
            'nearest_station': '仙台駅',
            'genres': 'スポーツ,アメカジ,ヴィンテージ',
            'hours': '11:00-21:00',
            'holiday': '不定休',
            'homepage_url': 'https://www.bigtime.jp/',
            'sns_url': 'https://www.instagram.com/big_time_sendai/',
            'description': '仙台最大級のヴィンテージショップ。クリスロード商店街内。スポーツ・ジャージ・アメカジ系が特に充実。1F・2Fの2フロア展開。',
            'price_range': '¥2000~',
            'payment_methods': '現金・クレジット',
            'parking': '',
            'latitude': 38.2632, 'longitude': 140.8720,
        },
        {
            'name': 'フラミンゴ 仙台店',
            'address': '宮城県仙台市青葉区中央2丁目7-15',
            'nearest_station': '仙台駅',
            'genres': 'アメリカ古着,レディース,リメイク',
            'hours': '11:00-20:00',
            'holiday': '不定休',
            'homepage_url': 'https://www.flamingo-online.jp/',
            'sns_url': 'https://www.instagram.com/flamingo_sendai/',
            'description': '下北沢発の全国チェーン・フラミンゴの仙台店。古着に加えて雑貨・オリジナルブランド・リメイク商品を展開。レディースが特に豊富。',
            'price_range': '¥3000~',
            'payment_methods': '現金・クレジット・電子マネー',
            'parking': '',
            'latitude': 38.2628, 'longitude': 140.8714,
        },
        {
            'name': 'Top of the Hill 仙台PARCO店',
            'address': '宮城県仙台市青葉区中央1丁目2-3 仙台パルコ本館6F',
            'nearest_station': '仙台駅',
            'genres': 'セレクト古着,ブランド古着,アウトドアヴィンテージ',
            'hours': '10:00-21:00',
            'holiday': '不定休（パルコに準ずる）',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/topofthehill_sendai/',
            'description': '下北沢・高円寺にも展開する古着チェーンの仙台店。仙台駅直結のパルコ本館6F。セレクトされたブランド古着・アウトドアヴィンテージが揃う。',
            'price_range': '¥5000~',
            'payment_methods': '現金・クレジット・電子マネー',
            'parking': '',
            'latitude': 38.2614, 'longitude': 140.8800,
        },
        # ── 仙台市 青葉区 本町エリア ────────────────────────────
        {
            'name': 'Utah（ユタ）',
            'address': '宮城県仙台市青葉区本町2丁目9-16 阿部勝ビル1F',
            'nearest_station': '広瀬通駅',
            'genres': 'アメリカ古着,ヨーロッパ古着,ヴィンテージ',
            'hours': '12:00-20:00',
            'holiday': '不定休',
            'homepage_url': 'https://utahltdshop.thebase.in/',
            'sns_url': 'https://www.instagram.com/utah_vintage_used_clothing/',
            'description': '2005年創業の仙台を代表する老舗古着屋。セレクトショップのような美しい陳列が特徴。アメリカ買い付けの一点物が揃う。',
            'price_range': '¥5000~',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2594, 'longitude': 140.8710,
        },
        {
            'name': 'IORI clothing by Utah',
            'address': '宮城県仙台市青葉区本町2丁目9-16',
            'nearest_station': '広瀬通駅',
            'genres': 'レディース,オールドブランド,ヴィンテージ',
            'hours': '12:00-20:00',
            'holiday': '不定休',
            'homepage_url': 'https://ioribyutah.thebase.in/',
            'sns_url': 'https://www.instagram.com/vintage_style_by_iori/',
            'description': 'Utahの姉妹店。レディース古着専門で木目と白を基調とした温かみある空間。グッチ・エルメス・ティファニーなどオールドブランドも取扱い。',
            'price_range': '¥5000~',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2594, 'longitude': 140.8710,
        },
        {
            'name': 'biscco（ビスコ）',
            'address': '宮城県仙台市青葉区本町2丁目5-16 1F',
            'nearest_station': '広瀬通駅',
            'genres': 'メンズ古着,レディース古着,ヴィンテージ',
            'hours': '12:00-19:00',
            'holiday': '不定休',
            'homepage_url': 'https://www.biscco.jp/',
            'sns_url': 'https://www.instagram.com/biscco288/',
            'description': '元・仙台駅東口の「DROP」が本町へ移転。夫婦で営まれるアットホームな古着屋。厳選古着とトレンドをミックスした品揃え。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2598, 'longitude': 140.8720,
        },
        {
            'name': 'SQUAT 仙台店',
            'address': '宮城県仙台市青葉区本町2丁目13-10 菊田屋ビル2F',
            'nearest_station': '広瀬通駅',
            'genres': 'ヨーロッパヴィンテージ,ミリタリー',
            'hours': '11:00-20:00',
            'holiday': '不定休',
            'homepage_url': 'https://squat.shop-pro.jp/',
            'sns_url': 'https://www.instagram.com/squat_used_clothing/',
            'description': 'オーナー自らヨーロッパへ買い付けに行く仙台のヴィンテージ専門店。50〜60年代のレアなヨーロピアンヴィンテージが豊富。山形にも姉妹店あり。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2588, 'longitude': 140.8701,
        },
        {
            'name': 'elie（エリー）',
            'address': '宮城県仙台市青葉区本町2丁目13-10 菊田屋ビル3F',
            'nearest_station': '広瀬通駅',
            'genres': 'レディース,リメイク古着,ヨーロッパ古着',
            'hours': '平日12:00-19:30 / 休日11:00-19:00',
            'holiday': '不定休',
            'homepage_url': 'https://ranadel.theshop.jp/',
            'sns_url': 'https://www.instagram.com/elie.sendai/',
            'description': 'アメリカ・ヨーロッパヴィンテージをリボンやフリルで可愛くリメイクした女性向けセレクト古着屋。シルエットやデザインにこだわる一店。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2588, 'longitude': 140.8701,
        },
        {
            'name': 'me 古着屋',
            'address': '宮城県仙台市青葉区本町2丁目9-8 日宝本町ビル103',
            'nearest_station': '広瀬通駅',
            'genres': 'ユーロヴィンテージ,アメリカ古着',
            'hours': '12:00-19:30',
            'holiday': '不定休',
            'homepage_url': 'https://mesendai.thebase.in/',
            'sns_url': 'https://www.instagram.com/me_sendai/',
            'description': '2017年オープン。ユーロヴィンテージとアメリカ古着を中心に、トレンドを意識した飽きのこない定番ヴィンテージを展開。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2594, 'longitude': 140.8708,
        },
        {
            'name': 'ooooo（オーズ）',
            'address': '宮城県仙台市青葉区本町2丁目14-26 保坂ビル1F',
            'nearest_station': '広瀬通駅',
            'genres': 'アメリカ古着,ヴィンテージ,ユニセックス',
            'hours': '月〜土12:00-22:00 / 日12:00-20:00',
            'holiday': '不定休',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/ooooo_sendai/',
            'description': '2ヶ月に1度アメリカ買い付けのユニセックスヴィンテージ古着屋。月〜土は22時まで営業する仙台では珍しい深夜型古着屋。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2585, 'longitude': 140.8699,
        },
        # ── 仙台市 青葉区 一番町エリア ────────────────────────────
        {
            'name': 'TRUE VINTAGE.',
            'address': '宮城県仙台市青葉区一番町1丁目6-20 ライトハウスビル102',
            'nearest_station': '広瀬通駅',
            'genres': 'アメリカ古着,ヴィンテージ,デニム',
            'hours': '11:00-20:00',
            'holiday': '不定休',
            'homepage_url': 'https://truevintage.jp/',
            'sns_url': 'https://www.instagram.com/truevintage_sendai/',
            'description': '2009年創業、2019年リニューアル。仙台トップクラスのヴィンテージ専門店。状態の良いリーバイスや革ジャンが多数。芸能人来店実績あり。',
            'price_range': '¥5000~',
            'payment_methods': '現金・クレジット',
            'parking': '',
            'latitude': 38.2661, 'longitude': 140.8710,
        },
        {
            'name': 'HOWDY（ハウディ）',
            'address': '宮城県仙台市青葉区一番町1丁目12-3',
            'nearest_station': '広瀬通駅',
            'genres': 'アメリカ古着,アウトドアヴィンテージ,雑貨',
            'hours': '平日12:00-20:00 / 休日11:00-19:00',
            'holiday': '不定休',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/howdy_88/',
            'description': '1991年創業の仙台最古参古着屋。毎月オレゴン州ポートランドへ買い付け。アウトドア系に強く雑貨も豊富。1階にお直し工房も併設。',
            'price_range': '¥3000~',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2651, 'longitude': 140.8704,
        },
        {
            'name': 'MISSION GENERAL STORE',
            'address': '宮城県仙台市青葉区一番町1丁目11-23 2F',
            'nearest_station': '広瀬通駅',
            'genres': 'アウトドアヴィンテージ,アメリカ古着,70年代',
            'hours': '11:00-20:00',
            'holiday': '不定休',
            'homepage_url': 'https://mission-gs.shop-pro.jp/',
            'sns_url': 'https://www.instagram.com/mission_general_store_/',
            'description': '2024年10月リニューアルオープン。1970〜90年代のアメリカ・ヨーロッパヴィンテージとパタゴニア・ノースフェイスなどアウトドアブランド専門。',
            'price_range': '¥5000~',
            'payment_methods': '現金・クレジット',
            'parking': '',
            'latitude': 38.2652, 'longitude': 140.8705,
        },
        {
            'name': '無人古着屋HOPE 一番町店',
            'address': '宮城県仙台市青葉区一番町1丁目14-25 一番町M・Yビル101',
            'nearest_station': '広瀬通駅',
            'genres': 'アメリカ古着,ヨーロッパ古着,格安古着',
            'hours': '24時間営業',
            'holiday': 'なし',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/mujinhurugiya_hope/',
            'description': '2023年9月オープンの24時間無人古着屋。仙台一番町店のほか北仙台・八木山にも展開。安価で購入可能。時間を気にせず古着が選べる。',
            'price_range': '¥500~',
            'payment_methods': '電子マネー・スマホバーコード決済',
            'parking': '',
            'latitude': 38.2649, 'longitude': 140.8700,
        },
        {
            'name': 'フロリダ 仙台店',
            'address': '宮城県仙台市青葉区一番町3丁目8-8 一番町ステアビル1F',
            'nearest_station': '広瀬通駅',
            'genres': 'アメリカ古着,ヨーロッパ古着,格安古着',
            'hours': '平日12:00-21:00 / 休日11:00-21:00',
            'holiday': '不定休',
            'homepage_url': 'https://www.flamingo-online.jp/',
            'sns_url': 'https://www.instagram.com/florida_sendai/',
            'description': 'フラミンゴの系列店。定番ヴィンテージを手頃な価格で販売。月末「青空市」では全品半額セールを実施する人気イベントあり。',
            'price_range': '¥1000~',
            'payment_methods': '現金・クレジット',
            'parking': '',
            'latitude': 38.2638, 'longitude': 140.8700,
        },
        {
            'name': 'i my（アイマイ）',
            'address': '宮城県仙台市青葉区一番町3丁目10-3 3F',
            'nearest_station': '広瀬通駅',
            'genres': 'レディース,レギュラー古着,80年代',
            'hours': '不明',
            'holiday': '不定休',
            'homepage_url': '',
            'sns_url': 'https://www.instagram.com/i_my_vintage/',
            'description': '一番町3丁目3階のレディース専門古着屋。80年代レギュラー古着が豊富でメンズ兼用アイテムも揃う。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2635, 'longitude': 140.8699,
        },
        {
            'name': 'gripp 仙台',
            'address': '宮城県仙台市青葉区一番町2丁目3-30 壱弐参横丁3号',
            'nearest_station': '広瀬通駅',
            'genres': 'アメリカ古着,シルバーアクセサリー,リメイク古着',
            'hours': '12:30-20:30',
            'holiday': '不定休',
            'homepage_url': 'https://gripp0219.thebase.in/',
            'sns_url': 'https://www.instagram.com/gripp_sendai/',
            'description': '国外買い付けのシルバーアクセサリーやリメイクレザージャケットなど、ここでしか手に入らないアイテムを展開。コーディネート提案も実施。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2645, 'longitude': 140.8704,
        },
        {
            'name': 'CAGERATTLERS（CRC）',
            'address': '宮城県仙台市青葉区一番町1丁目8-10 京成壱番町ビル303',
            'nearest_station': '広瀬通駅',
            'genres': 'レギュラー古着,ヴィンテージ,デザイナーズ',
            'hours': '12:00-21:00',
            'holiday': '不定休',
            'homepage_url': 'https://cagerattlers.net/',
            'sns_url': 'https://www.instagram.com/crc_japan/',
            'description': '2009年オープン。国内外の古着とセレクトブランド・自社ブランドを展開。下北沢でPOP UPも行う仙台の個性派セレクトショップ。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2657, 'longitude': 140.8708,
        },
        {
            'name': 'Green Room（グリーンルーム）仙台',
            'address': '宮城県仙台市青葉区一番町2丁目5-6 3F',
            'nearest_station': '広瀬通駅',
            'genres': 'アメリカ古着,ヨーロッパ古着',
            'hours': '11:00-20:00',
            'holiday': '不定休',
            'homepage_url': 'https://greenroom256.thebase.in/',
            'sns_url': 'https://www.instagram.com/greenroom256/',
            'description': '創業25年の老舗。アメリカ・ヨーロッパ・国内から仕入れた質の良い古着を学生にも手頃な価格で提供する穴場店舗。外階段からアクセス。',
            'price_range': '¥2000~',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2643, 'longitude': 140.8702,
        },
        {
            'name': 'sega-ru（セガル）',
            'address': '宮城県仙台市青葉区一番町3丁目1-24 3F',
            'nearest_station': '広瀬通駅',
            'genres': 'アメリカ古着,メンズ,ヴィンテージ',
            'hours': '12:00-20:00',
            'holiday': '不定休',
            'homepage_url': 'https://segaaru.base.ec/',
            'sns_url': 'https://www.instagram.com/segawa708/',
            'description': '2015年オープン。オーナーがアメリカ・国内買い付けし、プロによるクリーニング済み。古着に見えないほどクオリティの高い品揃え。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2635, 'longitude': 140.8703,
        },
        # ── 仙台市 青葉区 国分町・大町・立町エリア ────────────────────────────
        {
            'name': 'ShuShuBell（シュシュベル）仙台',
            'address': '宮城県仙台市青葉区国分町1丁目3-13 遠藤ビル1F',
            'nearest_station': '広瀬通駅',
            'genres': 'アメリカ古着,ヨーロッパ古着,ヴィンテージ',
            'hours': '平日・土12:00-20:00 / 日祝11:00-19:00',
            'holiday': '不定休',
            'homepage_url': 'https://www.shushubell.shop/',
            'sns_url': 'https://www.instagram.com/shushubell/',
            'description': '2008年創業。フランスのアパルトマンをイメージした落ち着いた店内。厳選古着が1万円で購入可能。古着詰め放題イベントが人気。',
            'price_range': '¥5000~',
            'payment_methods': '現金・クレジット',
            'parking': '',
            'latitude': 38.2661, 'longitude': 140.8696,
        },
        {
            'name': 'ShuShuBell 2（シュシュベル 2）',
            'address': '宮城県仙台市青葉区大町1丁目4-14 LAND B302',
            'nearest_station': '広瀬通駅',
            'genres': 'メンズ,ヴィンテージ,ミリタリー,レアアイテム',
            'hours': '平日・土12:00-20:00 / 日祝11:00-19:00',
            'holiday': '不定休',
            'homepage_url': 'https://www.shushubell.shop/',
            'sns_url': 'https://www.instagram.com/shushubell_2/',
            'description': 'シュシュベルのセレクトメンズ専門店。ヴィンテージリーバイス・エディバウアー・70〜80年代ミリタリーウェアなどレアアイテムが充実。',
            'price_range': '¥5000~',
            'payment_methods': '現金・クレジット',
            'parking': '',
            'latitude': 38.2645, 'longitude': 140.8690,
        },
        {
            'name': 'Room-9',
            'address': '宮城県仙台市青葉区大町1丁目3-25 4F',
            'nearest_station': '広瀬通駅',
            'genres': 'アメリカ古着,ヴィンテージ',
            'hours': '平日12:00-18:00',
            'holiday': '土日・不定休',
            'homepage_url': 'https://www.room-9sendai.com/',
            'sns_url': 'https://www.instagram.com/room____9/',
            'description': '「ちょうど良いヴィンテージ」をコンセプトに手頃な価格でヴィンテージ古着を提供。ゆったりとした雰囲気で選べる穴場の大町古着屋。',
            'price_range': '¥3000~',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2646, 'longitude': 140.8691,
        },
        {
            'name': 'ANNA（アンナ）',
            'address': '宮城県仙台市青葉区大町2丁目14-11 ファーストステージ2F',
            'nearest_station': '広瀬通駅',
            'genres': 'ヨーロッパ古着,レディース,アンティーク,キッズ',
            'hours': '12:00-18:00',
            'holiday': '不定休',
            'homepage_url': 'https://annavintage.stores.jp/',
            'sns_url': 'https://www.instagram.com/anna_antiek/',
            'description': '女優アンナ・カリーナに由来する店名のヨーロッパ古着店。アンティーク食器・フレンチリメイクアイテム・キッズアイテムも展開するユニークな一店。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2630, 'longitude': 140.8682,
        },
        {
            'name': 'BEAGLE USED & VINTAGE',
            'address': '宮城県仙台市青葉区立町21-1',
            'nearest_station': '広瀬通駅',
            'genres': 'レギュラー古着,ヴィンテージ,雑貨',
            'hours': '平日13:00-19:00 / 休日12:00-19:00',
            'holiday': '不定休',
            'homepage_url': 'https://beaglesendai.thebase.in/',
            'sns_url': 'https://www.instagram.com/beagle_sendai/',
            'description': '西公園近くの穴場古着屋。アメリカ買い付けの質の良い古着を展開。1万円以下が多くコンディション良好。',
            'price_range': '¥3000~',
            'payment_methods': '現金',
            'parking': '',
            'latitude': 38.2628, 'longitude': 140.8668,
        },
        # ── 仙台市 若林区 ────────────────────────────────────
        {
            'name': 'ブランド古着専門店LIFE 仙台中倉店',
            'address': '宮城県仙台市若林区中倉3丁目17-57',
            'nearest_station': '仙台駅',
            'genres': 'ブランド古着,ヴィンテージ,ハイブランド',
            'hours': '11:00-19:00',
            'holiday': 'なし',
            'homepage_url': 'https://lifeonline.jp/',
            'sns_url': 'https://www.instagram.com/life_shop_official_/',
            'description': '140坪の大型店。国道4号バイパス沿いで駐車場20台完備。パタゴニア・ラルフローレン・リーバイスからシャネル・エルメスまでブランド古着が豊富。宅配買取も実施。',
            'price_range': '¥5000~',
            'payment_methods': '現金・クレジット・電子マネー',
            'parking': 'あり（20台）',
            'latitude': 38.2448, 'longitude': 140.9008,
        },
        {
            'name': 'ブランド古着専門店LIFE 六丁の目店',
            'address': '宮城県仙台市若林区六丁の目東町6-25',
            'nearest_station': '六丁の目駅',
            'genres': 'スニーカー,ストリートブランド,ブランド古着',
            'hours': '11:00-19:00',
            'holiday': 'なし',
            'homepage_url': 'https://lifeonline.jp/',
            'sns_url': 'https://www.instagram.com/life_shop_official2/',
            'description': '130坪の大型店。ドンキホーテ六丁の目店敷地内。ステューシー・チャンピオン・コンバース・ノースフェイス・ゴローズなどオールドアイテムに特化。',
            'price_range': '¥5000~',
            'payment_methods': '現金・クレジット・電子マネー',
            'parking': 'あり',
            'latitude': 38.2454, 'longitude': 140.9138,
        },
        # ── 石巻市 ────────────────────────────────────────────
        {
            'name': '古着屋BLUE VACATION',
            'address': '宮城県石巻市開北1丁目1-12 ハイツE',
            'nearest_station': '石巻駅',
            'genres': 'US古着,EURO古着,リメイク古着',
            'hours': '11:00-20:00',
            'holiday': '水曜',
            'homepage_url': 'https://bluevacation.theshop.jp/',
            'sns_url': 'https://www.instagram.com/blue_vacation.ishinomaki/',
            'description': '石巻市の古着シーンを牽引する地元密着型ヴィンテージショップ。US古着・EURO古着・リメイク古着・オリジナルアイテムを展開。石巻駅から952m。',
            'price_range': '不明',
            'payment_methods': '現金',
            'parking': 'あり',
            'latitude': 38.4263, 'longitude': 141.3002,
        },
    ]

    added = 0
    for d in miyagi_shops:
        if Shop.query.filter_by(name=d['name']).first():
            continue
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
        added += 1
    db.session.commit()
    print(f"✅ 宮城県の古着屋 {added} 件を追加しました（スキップ: {len(miyagi_shops) - added} 件）")


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
    seed_akita_shops()
    seed_iwate_shops()
    seed_yamagata_shops()
    seed_miyagi_shops()

# gunicorn・直接実行どちらでも起動時にDB初期化
with app.app_context():
    seed_data()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)