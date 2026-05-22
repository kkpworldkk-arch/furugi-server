# furugiya_map_app

古着屋マップアプリ（Flutter Web）

## セットアップ・起動手順

### 1. リポジトリをクローン後、**必ずこのディレクトリに移動してから**コマンドを実行してください

```bash
cd furugiya_map_app
```

### 2. 環境変数ファイルの作成

`.env.example` をコピーして `.env` を作成し、APIキーを設定してください。

```bash
cp .env.example .env
```

`.env` を開いて `your_google_maps_api_key_here` の部分を実際のGoogle Maps APIキーに書き換えてください：

```
GOOGLE_MAPS_API_KEY=（管理者から受け取ったAPIキーを貼り付け）
```

### 3. 依存パッケージのインストール

```bash
flutter pub get
```

### 4. Chrome でアプリを起動

```bash
flutter run -d chrome
```

> **よくあるエラー:** `pubspec.yaml not found` と表示される場合、`furugiya_map_app/` ディレクトリの外でコマンドを実行しています。
> 必ず `cd furugiya_map_app` を実行してから `flutter run -d chrome` を実行してください。

---

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
