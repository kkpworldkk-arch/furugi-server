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
    "methods": ["GET", "POST", "OPTIONS"]
}})

# データベース設定 (データをファイルとして保存)
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
    homepage_url = db.Column(db.String(200))
    sns_url = db.Column(db.String(200))
    hours = db.Column(db.String(100))
    description = db.Column(db.String(1000))
    # ★追加：価格帯
    price_range = db.Column(db.String(50), default='不明')

class Article(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100))
    content = db.Column(db.Text)
    genre = db.Column(db.String(50))
    date = db.Column(db.String(20))

class Admin(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    password = db.Column(db.String(100))

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
            "homepageUrl": shop.homepage_url,
            "snsUrl": shop.sns_url,
            "hours": shop.hours,
            "description": shop.description,
            "priceRange": shop.price_range, # ★価格帯を返す
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
        latitude=lat,
        longitude=lng,
        genres=genres_str,
        hours=data.get('hours', ''),
        homepage_url=data.get('homepageUrl', ''),
        sns_url=data.get('snsUrl', ''),
        description=data.get('description', ''),
        price_range=data.get('priceRange', '不明'), # ★価格帯を保存
        rating=0.0,
        review_count=0
    )
    db.session.add(new_shop)
    db.session.commit()
    return jsonify({"message": "Shop added"}), 201

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

def seed_data():
    # データベースを作り直す
    db.create_all()

    # ▼ データが空っぽの時だけ、送ってくれたデータを注入する ▼
    if Shop.query.count() == 0:
        print("🌱 以前のデータをデータベースに移行します...")
        
        initial_shops = [
            {
                "name": "古着屋JAM 原宿店",
                "genres": "アメカジ,ヴィンテージ",
                "rating": 4.5, "review_count": 120,
                "address": "東京都渋谷区神宮前6-28-5",
                "latitude": 35.6645, "longitude": 139.7045,
                "homepage_url": "https://jamtrading.jp/",
                "sns_url": "https://instagram.com/furugiya_jam_official",
                "hours": "11:00 - 20:00",
                "description": "国内最大級の古着屋JAMの原宿店。初心者からマニアまで楽しめる圧倒的な品揃えが魅力です。",
                "price_range": "\3000 ~ 15000"
            },
            {
                "name": "Chicago 表参道店",
                "genres": "着物,アメカジ,ヨーロッパ",
                "rating": 4.2, "review_count": 85,
                "address": "東京都渋谷区神宮前4-26-26",
                "latitude": 35.6685, "longitude": 139.7065,
                "homepage_url": "https://www.chicago.co.jp/",
                "sns_url": "",
                "hours": "11:00 - 20:00",
                "description": "原宿・表参道エリアの老舗。着物の取り扱いも豊富で、海外からの観光客にも人気のお店です。",
                "price_range": "¥3,000 ~ ¥15,000"
            },
            {
                "name": "Flamingo 下北沢店",
                "genres": "US古着,レディース",
                "rating": 4.0, "review_count": 200,
                "address": "東京都世田谷区北沢2-25-12",
                "latitude": 35.6620, "longitude": 139.6670,
                "homepage_url": "",
                "sns_url": "",
                "hours": "12:00 - 21:00",
                "description": "下北沢のシンボル的な古着屋。フラミンゴのネオンサインが目印。質の良いUS古着が揃います。",
                "price_range": "¥3,000 ~ ¥15,000"
            },
            {
                "name": "USED SNEAKERS KAI",
                "genres": "スニーカー,ストリート",
                "rating": 4.8, "review_count": 15,
                "address": "埼玉県川口市芝中田1-1-14",
                "latitude": 35.8315, "longitude": 139.6963,
                "homepage_url": "https://used-sneakers.com/",
                "sns_url": "https://www.instagram.com/usedsneakers_kai/",
                "hours": "13:00 - 20:00",
                "description": "京浜東北線の蕨駅東口から徒歩9分の場所、埼玉県川口市（埼玉県川口市芝中田1丁目1-14）にある、USED（中古）専門のスニーカーショップです。靴専門の古着屋というイメージです。 店内に並べているスニーカーは、最近のスニーカーではなく、何年、何十年も前に発売されたものがメインとなります。 『スニーカー=高額』というイメージがございますが、当店はリーズナブルな価格帯のものが多いです。 古くて珍しいもの、他とは被らないもの、海外限定もの、などなど様々置いております。 今はネットでポチッと簡単にスニーカーが買える時代ですが、昔のスニーカーはそう簡単に巡り会えません。 ネットで抽選して最近のスニーカーを手に入れるのも良いですが、スニーカー本来の楽しみ方は、自分の足で店を回って、好みのスニーカーとの出会いを探すことかなと思います。 僕は誰もが知っている最近のスニーカーよりも、誰も知らない、見たことない、被らない、珍しいスニーカーを履くのが好きで、そんなスニーカーがたくさんあるお店があったら良いなと思い、オープンしました。",
                "price_range": "¥3000 ~"
            },
            {
                "name": "古着83 十条店",
                "genres": "ヴィンテージ,レギュラー",
                "rating": 4.3, "review_count": 30,
                "address": "東京都北区十条仲原1-2-5 赤のれんビル2F",
                "latitude": 35.7634, "longitude": 139.7212,
                "homepage_url": "https://furugi83.thebase.in/",
                "sns_url": "https://www.instagram.com/furu.gi83/",
                "hours": "12:00 - 20:00",
                "description": "十条商店街にあるアットホームな古着屋。良心的な価格設定と気さくな店主が魅力です。",
                "price_range": "¥1,000 ~"
            }
        ]

        for s in initial_shops:
            shop = Shop(**s)
            db.session.add(shop)
        
        db.session.commit()
        print("✅ 店舗データの移行完了！")

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

if __name__ == '__main__':
    with app.app_context():
        seed_data()
    app.run(host='0.0.0.0', port=5000, debug=True)