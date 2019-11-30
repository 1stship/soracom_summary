module SoracomSummary
  class Traffic
    attr_accessor :imsi, :date, :type, :upload_byte_size_total, :download_byte_size_total
    class << self
      def summary(traffics, time)
        month_text = time.strftime('%Y%m')
        day = time.strftime('%Y%m%d').to_i

        # 対象期間の請求をフィルタする
        month_traffics = traffics.select { |traffic| traffic.date[0, 6] == month_text && traffic.date.to_i <= day }
        day_traffics = traffics.select { |traffic| traffic.date.to_i == day }

        traffic_summary = {
          'traffics-month-total' => sum(month_traffics),
          'traffics-month-upload' => upload_sum(month_traffics),
          'traffics-month-download' => download_sum(month_traffics),
          'traffics-day-total' => sum(day_traffics),
          'traffics-day-upload' => upload_sum(day_traffics),
          'traffics-day-download' => download_sum(day_traffics)
        }

        # 通信量を種類ごとにグループ化する
        month_traffics_by_type = month_traffics
          .group_by { |traffic| traffic.type }
          .map do |type, group|
            [
              "traffics-month-total-#{type}", sum(group),
              "traffics-month-upload-#{type}", upload_sum(group),
              "traffics-month-download-#{type}", download_sum(group)
            ]
          end.flatten
        traffic_summary.merge!(Hash[*month_traffics_by_type])

        day_traffics_by_type = day_traffics
          .group_by { |traffic| traffic.type }
          .map do |type, group|
            [
              "traffics-day-total-#{type}", sum(group),
              "traffics-day-upload-#{type}", upload_sum(group),
              "traffics-day-download-#{type}", download_sum(group)
            ]
          end.flatten
        traffic_summary.merge!(Hash[*day_traffics_by_type])

        traffic_summary
      end

      def group_by_imsi(traffics, time)
        day = time.strftime('%Y%m%d')

        # 対象期間の請求をフィルタする
        day_traffics = traffics.select { |traffic| traffic.date == day }
        
        day_traffics_by_imsi = day_traffics
        .group_by { |traffic| traffic.imsi }
        .map { |imsi, group| [imsi, sum(group)] }
        .to_h

        day_traffics_by_imsi
      end

      def sum(traffics)
        traffics.inject(0) do |sum, traffic|
          sum + traffic.upload_byte_size_total.to_i + traffic.download_byte_size_total.to_i
        end
      end

      def upload_sum(traffics)
        traffics.inject(0) { |sum, traffic| sum + traffic.upload_byte_size_total.to_i }
      end

      def download_sum(traffics)
        traffics.inject(0) { |sum, traffic| sum + traffic.download_byte_size_total.to_i }
      end
    end

    def initialize(
      imsi:,
      date:,
      type:,
      upload_byte_size_total:,
      download_byte_size_total:)
      @imsi = imsi
      @date = date
      @type = type
      @upload_byte_size_total = upload_byte_size_total
      @download_byte_size_total = download_byte_size_total
    end
  end
end