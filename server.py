from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from geopy.geocoders import Nominatim
from datetime import datetime
import os
import time

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
    if 'hours' in data:
        shop.hours = data['hours']
    if 'holiday' in data:
        shop.holiday = data['holiday']
    if 'priceRange' in data:
        shop.price_range = data['priceRange']
    if 'paymentMethods' in data:
        shop.payment_methods = data['paymentMethods']
    if 'parking' in data:
        shop.parking = data['parking']
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

# gunicorn・直接実行どちらでも起動時にDB初期化
with app.app_context():
    seed_data()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)