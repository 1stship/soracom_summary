require 'optparse'
require 'date'

module SoracomSummary
  class CLI
    class << self
      def run(argv)
        # ソラコム内では時間はUTCで表現されるため、タイムゾーンをUTCにしておく
        ENV['TZ'] = 'UTC'
        parse!(argv)
      end

      private

      def parse!(argv)
        options = {}
        parser = create_parser(options)
        parser.order!(argv)

        if options.key?('from')
          @from = Time.parse(options['from'])
        else
          @from = Date.today.to_time - Const::ONE_DAY_SEC
        end

        if options.key?('to')
          @to = Time.parse(options['to']) + Const::ONE_DAY_SEC
        else
          @to = Date.today.to_time
        end

        if @from >= @to
          raise ArgumentError, 'from must be less or equal to'
        end
        
        # 分類に使用するタグの設定
        if options.key?('category_tag')
          @category_tag = options['category_tag']
        end

        # セッション分析を実施するか
        # 取得に時間を要するためオプションとする
        if options.key?('session')
          @session_analyze_enable = options['session']
        end

        scrape
      end 

      def create_parser(options)
        OptionParser.new do |opt|
          opt.on_head('-v', '--version', 'display version') do
            puts "soracom_summary #{VERSION}"
            exit
          end 
          opt.on('--from from_date', 'set from_date to scrape(default: today)') { |v| options['from'] = v }
          opt.on('--to to_date', 'set to_date to scrape(default: today)') { |v| options['to'] = v }
          opt.on('--tag category_tag', 'select tag to categorize(default: nil)') { |v| options['category_tag'] = v }
          opt.on('--session', 'enable session analyze(default: false)') { |v| options['session'] = v }
        end 
      end

      def scrape
        raise ArgumentError, 'need SORACOM_AUTH_KEY_ID environment' unless ENV.key?('SORACOM_AUTH_KEY_ID')
        raise ArgumentError, 'need SORACOM_AUTH_KEY environment' unless ENV.key?('SORACOM_AUTH_KEY')
        raise ArgumentError, 'need SORACOM_SUMMARY_DEVICE_ID environment' unless ENV.key?('SORACOM_SUMMARY_DEVICE_ID')
        raise ArgumentError, 'need SORACOM_SUMMARY_DEVICE_SECRET environment' unless ENV.key?('SORACOM_SUMMARY_DEVICE_SECRET')

        client = SoracomSummary::ApiClient.new(
          auth_key_id: ENV['SORACOM_AUTH_KEY_ID'],
          auth_key: ENV['SORACOM_AUTH_KEY'])

        subscribers = client.get_subscribers

        # セッション分析を実行する場合
        if @session_analyze_enable == true
          subscribers.each do |subscriber|
            sessions = client.get_sessions(subscriber.imsi, @from, @to )
            subscriber.sessions = sessions
          end
        end

        target_months = get_target_months(@from, @to)
        billings = client.get_billing(target_months)
        traffics = client.get_traffic(target_months)
        logs = client.get_logs(@from, @to)
        
        time = @from
        loop do
          summary = get_summary(subscribers, billings, traffics, logs, time)
          client.upload_harvest(ENV['SORACOM_SUMMARY_DEVICE_ID'], ENV['SORACOM_SUMMARY_DEVICE_SECRET'], time, summary)

          if @session_analyze_enable == true && ENV.key?('SORACOM_SESSION_DEVICE_ID') && ENV.key?('SORACOM_SESSION_DEVICE_SECRET')
            sessions_count_by_imsi = Subscriber.sessions_count_by_imsi(subscribers, time)
            client.upload_harvest(ENV['SORACOM_SESSION_DEVICE_ID'], ENV['SORACOM_SESSION_DEVICE_SECRET'], time, sessions_count_by_imsi)
          end

          if ENV.key?('SORACOM_BILLING_DEVICE_ID') && ENV.key?('SORACOM_BILLING_DEVICE_SECRET')
            billing_by_origin = Billing.group_by_origin(billings, time)
            client.upload_harvest(ENV['SORACOM_BILLING_DEVICE_ID'], ENV['SORACOM_BILLING_DEVICE_SECRET'], time, billing_by_origin)
          end

          if ENV.key?('SORACOM_TRAFFIC_DEVICE_ID') && ENV.key?('SORACOM_TRAFFIC_DEVICE_SECRET')
            traffic_by_imsi = Traffic.group_by_imsi(traffics, time)
            client.upload_harvest(ENV['SORACOM_TRAFFIC_DEVICE_ID'], ENV['SORACOM_TRAFFIC_DEVICE_SECRET'], time, traffic_by_imsi)
          end

          time += Const::ONE_DAY_SEC
          break if time >= @to
        end
      end

      def get_summary(subscribers, billings, traffics, logs, time)
        subscribers_summary = Subscriber.summary(subscribers, time, @category_tag, @session_analyze_enable)
        billings_summary = Billing.summary(billings, time)
        traffics_summary = Traffic.summary(traffics, time)
        logs_summary = summary_log(logs, time)
        
        result = subscribers_summary
          .merge(billings_summary)
          .merge(traffics_summary)
          .merge(logs_summary)
        result
      end

      def get_target_months(from, to)
        target_months = []
        time = from
        loop do
          target_months.push(time.strftime('%Y%m'))
          time += Const::ONE_DAY_SEC
          break if time >= to
        end
        target_months.uniq
      end

      def summary_log(logs, time)
        target_logs = logs.select do |log|
          log['time'] >= time.to_i * 1000 && log['time'] < time.to_i * 1000 + Const::ONE_DAY_MSEC
        end
        { 'error-log-count' => target_logs.length }
      end
    end
  end
end