module SoracomSummary
  class Subscriber
    attr_accessor :imsi, :created_at, :tags, :status, :sessions
    class << self
      def summary(subscribers, time, category_tag = nil, session_analyze_enable = false)
        # 指定期間内に登録されていたSIMのみ対象とする
        target_subscribers = subscribers.select do |subscriber|
          subscriber.created_at < time.to_i * 1000 + Const::ONE_DAY_MSEC
        end

        subscribers_summary = {
          'subscribers-total' => target_subscribers.length
        }

        # ステータスでの分類
        subscribers_count_by_status = target_subscribers
          .group_by { |subscriber| subscriber.status }
          .map { |status, group| ["subscribers-status-#{status}", group.length ]}
          .to_h
        subscribers_summary.merge!(subscribers_count_by_status)
        
        # 分類対象のタグがセットされていたらタグで分類する
        if !category_tag.nil?
          subscribers_count_by_tag = target_subscribers
            .group_by { |subscriber| subscriber.tags[category_tag] }
            .map { |tag, group| ["subscribers-#{category_tag}-#{(tag.nil? ? "none" : tag)}", group.length ]}
            .to_h
          subscribers_summary.merge!(subscribers_count_by_tag)
        end

        # セッション状態での分類
        if session_analyze_enable
          subscribers_count_by_active = target_subscribers
            .group_by { |subscriber| subscriber.active?(time) }
            .map { |active, group| ["subscribers-#{active ? 'active' : 'inactive'}", group.length ]}
            .to_h
          subscribers_summary.merge!(subscribers_count_by_active)
        end
        subscribers_summary
      end

      # imsiごとのセッション数を取得する
      def sessions_count_by_imsi(subscribers, time)
        subscribers
          .map { |subscriber| [ subscriber.imsi, subscriber.sessions_count(time) ]}
          .to_h
      end
    end

    def initialize(
        imsi:,
        created_at:,
        tags:,
        status:)
      @imsi = imsi
      @created_at = created_at
      @tags = tags
      @status = status
      @sessions = []
    end

    def active?(time)
      from_timestamp_ms = time.to_i * 1000
      to_timestamp_ms = time.to_i * 1000 + Const::ONE_DAY_MSEC

      # 対象期間内にCreatedのイベントがあればアクティブ
      judge = @sessions.any? do |session|
        session['time'] >= from_timestamp_ms && session['time'] < to_timestamp_ms && session['event'] == 'Created'
      end
      return true if judge == true
      
      # 対象期間内の直前のイベントがCreatedであればアクティブ
      sessions_before_from = @sessions.select { |session| session['time'] < from_timestamp_ms }
      return false if sessions_before_from.length == 0
      sessions_before_from.first['event'] == 'Created'
    end

    def sessions_count(time)
      from_timestamp_ms = time.to_i * 1000
      to_timestamp_ms = time.to_i * 1000 + Const::ONE_DAY_MSEC

      created_sessions = @sessions.select do |session|
        session['time'] >= from_timestamp_ms && session['time'] < to_timestamp_ms && session['event'] == 'Created'
      end
      created_sessions.length
    end
  end
end