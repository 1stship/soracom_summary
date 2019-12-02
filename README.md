# SORACOM Summary
SORACOM Summary は、ソラコム株式会社の提供する回線サービスSORACOMの使用状況をWeb APIを用いてスクレイピングし、
取得した使用状況をSORACOM Harvestにアップロードすることにより可視化するツールです。

こちらに説明の記事を投稿しております。
https://qiita.com/drafts/0c3cfe0bc8ff6b363e9e

## インストール

```
$ gem install soracom_summary
```

ライブラリ及びsoracom_summaryコマンドがインストールされます。

## 使用方法

### ユーザー認証情報の設定
環境変数にSAMユーザーの認証キーIDと認証キーシークレットを設定します。
SAMユーザーの説明はこちら
https://dev.soracom.io/jp/start/sam/

```
$ export SORACOM_AUTH_KEY_ID='keyId-XXXX'
$ export SORACOM_AUTH_KEY='secret-XXXX'
```

SAMユーザーには、以下の権限が必要です。上記ドキュメントを参照して、権限を設定します。
- Subscriber:listSubscribers
- Subscriber:listSessionEvents
- Log:getLogs
- Billing:exportBilling
- Stats:exportAirStats

### デバイス認証情報の設定

環境変数にHarvestにアップロードするためのSORACOM InventoryのデバイスIDとデバイスシークレットを設定します。
デバイスIDとデバイスシークレットについての説明はこちら
https://dev.soracom.io/jp/start/inventory_harvest_with_keys/

集計情報用（必須）
```
$ export SORACOM_SUMMARY_DEVICE_ID='d-XXXX'
$ export SORACOM_SUMMARY_DEVICE_SECRET='XXXX'
```

セッション情報の分布用（オプション）
```
$ export SORACOM_SESSION_DEVICE_ID='d-XXXX'
$ export SORACOM_SESSION_DEVICE_SECRET='XXXX'
```

請求情報の分布用（オプション）
```
$ export SORACOM_BILLING_DEVICE_ID='d-XXXX'
$ export SORACOM_BILLING_DEVICE_SECRET='XXXX'
```

通信量の分布用（オプション）
```
$ export SORACOM_TRAFFIC_DEVICE_ID='d-XXXX'
$ export SORACOM_TRAFFIC_DEVICE_SECRET='XXXX'
```

### 使用方法
以下のコマンドを実行すると１日前の集計をします
```
$ soracom_summary
```

セッション情報を取得するには時間がかかるため、--sessionオプションで明示的に指定する必要があります
```
$ soracom_summary --session
```

指定したタグごとにSIMの枚数を集計する場合、--tagオプションを使用します
```
$ soracom_summary --tag environment
```

過去にさかのぼって集計する場合、--from、--toオプションを使用します
```
$ soracom_summary --from 2019-11-22 --to 2019-11-24
```

実行後、データはSORACOM Harvestにアップロードされ、SORACOM Lagoonにて可視化することが出来ます。

Lagoonでの可視化は以下を参照して設定します。
https://dev.soracom.io/jp/start/lagoon-panel/
