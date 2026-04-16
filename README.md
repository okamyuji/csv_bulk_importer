# csv_bulk_importer

## 概要

このアプリケーションは、ECS FargateとAurora MySQLの環境において、複数のユーザーが数千から数万行規模のCSVファイルを同時にアップロードし、OOMを起こさずに並行処理でデータベースへ登録するためのRails 8アプリケーションです。処理に失敗したチャンクは個別にリトライできるため、部分的な障害からの復旧が可能です。

## 技術スタック

| レイヤ | 採用技術 |
|---|---|
| バックエンド | Ruby 3.4.8 / Rails 8.1.3 / Puma |
| データベース | MySQL 8.0（開発環境はDockerコンテナ、本番はAurora MySQL） |
| ジョブキュー | Solid Queue（Rails 8の標準機能） |
| リアルタイム通信 | Solid Cable（ActionCable） |
| ファイルストレージ | ActiveStorageを経由してS3へ保存します（開発環境ではLocalStackを使用します） |
| フロントエンド | Vite 7 + React 19 + TypeScript + Tailwind CSS v4 |
| 認証 | DeviseとDevise-JWTを組み合わせたBearerトークン認証です |
| 型検査 | Sorbetを`typed: true`で適用し、Tapiocaで型定義を生成しています |
| リント・フォーマット | RuboCop（omakase）、Syntax Tree、ESLint、Prettier、Stylelint、erb_lintを使用しています |
| テスト | RSpec（40件のテスト）とPlaywright E2E（5シナリオ）で検証しています |
| ローカルCI | lefthookによるpre-commitフックとpre-pushフックを設定しています |
| インフラ | Terraformを8モジュールに分割し、ECS FargateとDockerマルチステージビルドで構成しています |

## 前提条件

以下のツールが事前にインストールされている必要があります。

- macOS（Apple Silicon）またはLinux
- miseによるRuby 3.4.8の管理（ https://mise.jdx.dev/ ）
- Docker Desktop。MySQL 8.0のコンテナが`mysql8-mysql-1`という名前で起動しており、`mysql8_default`ネットワークに接続されている必要があります
- Node.js 22以降とpnpm 10以降
- lefthook（`brew install lefthook`でインストールできます）
- Terraform 1.5以降（インフラの検証に使用します）

## セットアップ手順

以下のコマンドで初回セットアップをすべて実行できます。

```bash
make setup
```

手動でセットアップする場合は、以下の順序で実行してください。

```bash
# Rubyの依存パッケージをインストールします
bundle install

# LocalStackコンテナを起動します（S3互換のストレージとして使用します）
docker compose up -d

# データベースを作成し、マイグレーションを実行します
bin/rails db:prepare

# フロントエンドの依存パッケージをインストールします
pnpm --dir frontend install --frozen-lockfile

# Gitフックを登録します
lefthook install
```

## 開発サーバーの起動方法

以下のコマンドで、Railsサーバー（ポート3000）、Solid Queueワーカー、Vite開発サーバー（ポート5173）が同時に起動します。

```bash
make dev
```

起動後は、ブラウザで http://localhost:5173 を開いてください。

## makeターゲットの一覧

| ターゲット | 説明 |
|---|---|
| `make setup` | 初回セットアップを実行します（bundle、pnpm、DB作成、Docker起動、フック登録） |
| `make dev` | 開発サーバーを起動します（Rails + Vite + ワーカー） |
| `make test` | RSpecテストを実行します |
| `make e2e` | Playwright E2Eテストを実行します |
| `make quality` | 8種類の品質チェックを一括で実行します |
| `make lint` | RuboCopとESLintのみを実行します |
| `make typecheck` | SorbetとTypeScriptの型検査を実行します |
| `make format` | RubyファイルをSyntax Treeで、JS/TSファイルをPrettierで自動整形します |
| `make up` | LocalStackのDockerコンテナを起動します |
| `make down` | LocalStackのDockerコンテナを停止します |
| `make migrate` | データベースマイグレーションを実行します |
| `make console` | Railsコンソールを開きます |
| `make build` | 本番用のDockerイメージ（webとworker）をビルドします |
| `make tf.init` | Terraformの初期化を実行します（dev環境） |
| `make tf.plan` | Terraformのプランを実行します（dev環境） |
| `make clean` | 一時ファイルやログ、カバレッジレポートを削除します |

## 処理の流れ

ユーザーがCSVファイルをアップロードすると、以下の順序で処理が進みます。

1. フロントエンドのSPAからmultipartのPOSTリクエストで`/api/v1/csv_imports`にファイルを送信します
2. RailsのコントローラがCsvImportレコードを作成し、ActiveStorageを通じてS3に原本を保存します
3. CsvImportJob（親ジョブ）がファイルをストリーミングで読み込みながら、500行ごとにS3へチャンクファイルを分割アップロードします
4. 各チャンクに対してCsvChunkJob（子ジョブ）が起動し、S3からチャンクを取得してCSVをパースします
5. CsvRowMapperが各行の型変換とバリデーションを実施し、ActiveRecordモデルの`valid?`で整合性を検証します
6. 有効な行のみを100件ずつ`upsert_all`でデータベースに投入します
7. CsvImportFinalizerJobが全チャンクの結果を集約し、最終ステータスを確定します
8. 各フェーズでActionCableを通じてリアルタイムの進捗イベントをブロードキャストします

## OOM対策について

このアプリケーションでは、以下の方法でメモリ消費を抑制しています。

- ファイル全体をメモリに読み込まず、`IO#each_line`でストリーミング処理します
- 500行単位でS3にチャンクを分割し、ローカルディスクへの一時保存を行いません
- データベースへの投入は100行ずつ`upsert_all`でバッチ処理します
- Solid Queueのconcurrency設定でワーカーの同時実行数を制御します
- ECSのエフェメラルストレージには依存せず、すべてS3を経由します

## 冪等性の保証について

各CSVの行にはSHA256ハッシュによる`idempotency_key`を付与しています。MySQLのUNIQUEインデックスと`upsert_all`（ON DUPLICATE KEY UPDATE）の組み合わせにより、ジョブが再実行された場合でもレコードが重複することはありません。完了済みのチャンクは処理をスキップするため、Solid Queueのat-least-once配送に対しても安全です。

## 監査ログについて

`AUDIT`プレフィックス付きのJSON形式で以下のイベントを記録しています。

- 認証に関するイベント（サインイン成功と失敗、サインアップ、サインアウト）
- CSVインポートの操作イベント（作成、リトライ、認可拒否）
- チャンク処理の結果イベント（完了、エラー付き完了、失敗）
- インポートの最終集約イベント

パスワード、JWTトークンの本体、CSVの行データは一切ログに出力されません。

## サプライチェーン攻撃への対策について

`.npmrc`で`minimum-release-age=10080`（7日間）を設定しています。npm registryに公開されてから7日未満のパッケージバージョンはインストールが拒否されます。

## テストの実行方法

```bash
# RSpecテスト（40件のテストケース）を実行します
make test

# Playwright E2Eテスト（5シナリオ）を実行します
make e2e

# 8種類の品質チェックを一括で実行します
make quality
```

## 本番イメージのビルド方法

以下のコマンドで、webとworkerの2つのDockerイメージをビルドできます。

```bash
make build
```

Dockerfileは6ステージのマルチステージビルドで構成されています。最終イメージにはビルドツール、node_modules、テストコードは含まれません。

## Terraformによるインフラ管理

以下のコマンドで、開発環境のインフラ設定を検証できます。

```bash
make tf.init      # Terraformの初期化を実行します
make tf.validate  # 設定ファイルの構文検証を実行します
make tf.plan      # インフラの変更計画を確認します
```

8つのモジュール（network、rds_aurora、s3_csv_bucket、iam、ecs_cluster、ecs_service_web、ecs_service_worker、observability）で構成されており、すべてのモジュールはvariables.tfで入力を受け取り、outputs.tfで出力を公開しています。

## ライセンス

MITライセンスで公開しています。
