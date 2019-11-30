require 'net/http'
require 'uri'
require 'json'
require 'logger'

module SoracomSummary
  class HttpClient
    class << self
      def download(url)
        uri = URI.parse(url)
        request = Net::HTTP::Get.new(uri)
        response = Net::HTTP.start(uri.hostname, uri.port, { use_ssl: true }) do |http|
          http.request(request)
        end
        if (response.code.start_with?('2'))
          return response.body.force_encoding('UTF-8')
        else
          Logger.new(STDERR).warn("Cannot download csv")
          raise
        end
      end
    end

    def initialize(base_url: , interval_second: 1, retry_limit: 5)
      @logger = Logger.new(STDERR)
      @logger.level = ENV['SORACOM_SUMMARY_DEBUG'] ? Logger::DEBUG : Logger::WARN
      @base_url = base_url
      @interval_second = interval_second
      @retry_limit = retry_limit
    end

    def get(path, headers)
      uri = URI.join(@base_url, path)
      request = Net::HTTP::Get.new(uri)

      if headers.class == Hash
        headers.each do |key, value|
          request[key] = value
        end
      end

      access(uri, request)
    end

    def post(path, headers, request_body)
      uri = URI.join(@base_url, path)
      request = Net::HTTP::Post.new(uri)
      request.content_type = 'application/json'

      if headers.class == Hash
        headers.each do |key, value|
          request[key] = value
        end
      end

      if !request_body.nil?
        request.body = JSON.generate(request_body)
      end

      access(uri, request)
    end

    private

    def access(uri, request, retry_count = 0)
      response = Net::HTTP.start(uri.hostname, uri.port, { use_ssl: true }) do |http|
        http.request(request)
      end

      if (response.code.start_with?('2'))
        # 成功した場合はヘッダーとボディをそれぞれ返す
        # ヘッダーを返すのはlinkヘッダーの取得が必要となるため
        # ボディは基本的にはJSONでパースできるが、空の場合は出来ないため空文字列で返す
        # 連続してアクセスしすぎないよう規定時間スリープしてから応答する
        sleep @interval_second
        return { 'headers' => response.header, 'body' => response.body.empty? ? '' : JSON.parse(response.body)}
      elsif response.code == '429'
        # 429はAPIレート制限のため、１分待ってからエラーを発生させる
        @logger.debug("#{response.code}: #{response.body}")
        sleep 60
        raise
      else
        # その他不明なコードが返った場合はエラーを発生させる
        @logger.warn("#{response.code}: #{response.body}")
        raise
      end
    rescue => e
      @logger.warn e
      # エラーが発生した場合はリトライ回数が規定値未満であればリトライする
      retry_count += 1
      if retry_count < @retry_limit
        sleep (2 ** retry_count)
        retry
      end

      # リトライ回数が規定値を超えるとエラーを上位に報告する
      raise
    end
  end
end