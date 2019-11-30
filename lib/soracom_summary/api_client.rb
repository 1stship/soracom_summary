require 'time'
require 'csv'
require 'uri'
require 'logger'

module SoracomSummary
  class ApiClient
    BASE_URL = 'https://api.soracom.io/v1/'
    def initialize(
      auth_key_id: ENV['SORACOM_AUTH_KEY_ID'],
      auth_key: ENV['SORACOM_AUTH_KEY']
      )
      @logger = Logger.new(STDERR)
      @logger.level = ENV['SORACOM_SUMMARY_DEBUG'] ? Logger::DEBUG : Logger::WARN
      @http_client = HttpClient.new(base_url: BASE_URL)
      @token = authenticate(auth_key_id, auth_key)
    end

    def get_subscribers
      @logger.debug('start get subscribers')
      subscribers = []
      path = 'subscribers'
      loop do
        response = http_access_with_token('GET', path)
        response_subscribers = response['body'].map do |subscriber|
          status = subscriber['status']
          if status == 'active'
            status = subscriber['sessionStatus']['online'] ? 'online' : 'offline'
          end
          Subscriber.new(
            imsi: subscriber['imsi'],
            created_at: subscriber['createdAt'],
            tags: subscriber['tags'],
            status: status
          )
        end
        subscribers.concat(response_subscribers)
        next_link = get_next_link(response['headers'])
        break if next_link.nil?
        path = next_link
      end

      @logger.debug('finish get subscribers')
      subscribers
    end

    def get_sessions(imsi, from, to)
      @logger.debug("start get sessions #{imsi}")
      from_timestamp_ms = from.to_i * 1000
      to_timestamp_ms = (to.to_i + Const::ONE_DAY_SEC) * 1000
      sessions = []
      path = "subscribers/#{imsi}/events/sessions"
      loop do
        response = http_access_with_token('GET', path)
        break if response['body'].empty?

        # Modifiedなど接続/切断以外のイベントは排除
        response_sessions = response['body'].select { |session| session['event'] == 'Created' || session['event'] == 'Deleted' }
        sessions.concat(response_sessions)

        # fromの時間に入る直前までのセッションが取得できていたら終了する
        break if sessions.length > 0 && sessions.last['time'] < from_timestamp_ms

        next_link = get_next_link(response['headers'])
        break if next_link.nil?
        path = next_link
      end

      # to以降のセッションは除外
      sessions = sessions.reject { |session| session['time'] >= to_timestamp_ms }

      # from以前のセッションは最後のイベントをfromの開始時のイベントとして残し、他は除外する
      before_from_sessions = sessions.select { |session| session['time'] < from_timestamp_ms }
      sessions = sessions.reject { |session| session['time'] < from_timestamp_ms }
      if before_from_sessions.length > 0
        sessions.push(before_from_sessions.first.merge({'time' => from_timestamp_ms }))
      else
        sessions.push({'event' => 'Deleted', 'time' => from_timestamp_ms} )
      end

      @logger.debug("finish get sessions #{imsi}")
      sessions
    end

    # エラーログを取得する
    # from、toの指定が効いていない？
    def get_logs(from, to)
      @logger.debug("start get logs")

      from_timestamp = from.to_i
      to_timestamp = to.to_i + Const::ONE_DAY_SEC
      logs = []
      path = "logs?from=#{from_timestamp}&to=#{to_timestamp}"

      loop do
        response = http_access_with_token('GET', path)
        break if response['body'].empty?
        logs.concat(response['body'])
        next_link = get_next_link(response['headers'])
        break if next_link.nil?
        path = next_link
      end

      @logger.debug("finish get logs")
      logs = logs.select { |log| log['time'] >= from_timestamp * 1000 && log['time'] < to_timestamp * 1000 }
      logs
    end

    def get_billing(target_months)
      @logger.debug("start get billings")
      billings = []

      target_months.each do |month|
        export_response = http_access_with_token('POST', "bills/#{month}/export?export_mode=sync")
        export_url = export_response['body']['url']

        # 1文字目はBOMのため除外する
        csv_text = HttpClient.download(export_url)
        csv_text.slice!(0)
        CSV.parse(csv_text, headers: true ) do |ln|
          billing = Billing.new(
            imsi: ln['imsi'],
            device_id: ln['deviceId'],
            date: ln['date'],
            bill_item_name: ln['billItemName'],
            amount: ln['amount']
          )
          billings.push(billing)
        end
      end

      @logger.debug("finish get billings")
      billings
    end

    def get_traffic(target_months)
      @logger.debug("start get traffics")

      traffics = []

      target_months.each do |month|
        from = Time.parse(month + '01')
        # 翌月の1日 - 1
        to = from + (32 - (from + 31 * Const::ONE_DAY_SEC).mday) * Const::ONE_DAY_SEC - 1
        body = { 'from' => from.to_i, 'to' => to.to_i, 'period' => 'day'}
        export_response = http_access_with_token('POST', "stats/air/operators/#{@token['operatorId']}/export?export_mode=sync", nil, body)
        export_url = export_response['body']['url']

        # 1文字目はBOMのため除外する
        csv_text = HttpClient.download(export_url)
        csv_text.slice!(0)
        CSV.parse(csv_text, headers: true ) do |ln|
          traffic = Traffic.new(
            imsi: ln['imsi'],
            date: ln['date'],
            type: ln['type'],
            upload_byte_size_total: ln['uploadByteSizeTotal'],
            download_byte_size_total: ln['downloadByteSizeTotal'],
          )
          traffics.push(traffic)
        end
      end

      @logger.debug("finish get traffics")
      traffics
    end

    def upload_harvest(device_id, device_secret, time, data)
      @logger.debug("start upload harvest #{device_id}")

      # device_secretはURLセーフは文字列ではないためエンコードが必要
      path = "devices/#{device_id}/publish?device_secret=#{URI.encode_www_form_component(device_secret)}"
      headers = nil
      unless time.nil?
        headers = { 'X-SORACOM-TIMESTAMP' => (time.to_i * 1000).to_s }
      end
      result = @http_client.post(path, headers, data)

      @logger.debug("finish upload harvest #{device_id}")
      result
    end

    private 

    # 認証IDと認証キーで認証する
    def authenticate(auth_key_id, auth_key)
      @logger.debug("start authenticate")

      request_body = { authKeyId: auth_key_id, authKey: auth_key }
      token_response = @http_client.post("auth", {}, request_body)

      @logger.debug("finish authenticate")
      token_response['body']
    end

    # トークン情報付でアクセスする
    def http_access_with_token(method, path, headers = nil, body = nil)
      headers = {} if headers.nil?
      headers.merge!({
          'X-SORACOM-API-KEY' => @token['apiKey'],
          'X-SORACOM-TOKEN' => @token['token']
        })
      case method
      when 'GET' then @http_client.get(path, headers)
      when 'POST' then @http_client.post(path, headers, body)
      else nil
      end
    end

    def get_next_link(headers)
      return nil unless headers.key?('link')
      link_array = headers['link'].split(/\s*,\s*/)
      next_link_text = link_array.find { |link| link.include?('rel=next') }
      return nil if next_link_text.nil?
      next_link_text[(next_link_text.index('<') + 1)...(next_link_text.index('>'))]
    end
  end
end