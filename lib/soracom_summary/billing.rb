module SoracomSummary
  class Billing
    attr_accessor :imsi, :device_id, :date, :bill_item_name, :amount
    class << self
      def summary(billings, time)
        month_text = time.strftime('%Y%m')
        day = time.strftime('%Y%m%d').to_i

        # 対象期間の請求をフィルタする
        month_billings = billings.select { |billing| billing.date[0, 6] == month_text && billing.date.to_i <= day }
        day_billings = billings.select { |billing| billing.date.to_i == day }
        billing_summary = { 'billings-month-total' => sum(month_billings), 'billings-day-total' => sum(day_billings) }

        # 請求を項目ごとにグループ化する
        month_billings_by_item = month_billings
          .group_by { |billing| billing.bill_item_name }
          .map { |item, group| ["billings-month-item-#{item}", sum(group) ]}
          .to_h
        billing_summary.merge!(month_billings_by_item)

        day_billings_by_item = day_billings
          .group_by { |billing| billing.bill_item_name }
          .map { |item, group| ["billings-day-item-#{item}", sum(group) ]}
          .to_h
        billing_summary.merge!(day_billings_by_item)

        billing_summary
      end

      def group_by_origin(billings, time)
        day = time.strftime('%Y%m%d')

        # 対象期間の請求をフィルタする
        day_billings = billings.select { |billing| billing.date == day }
        
        day_billings_by_origin = day_billings
        .group_by { |billing| billing.imsi || billing.device_id || billing.bill_item_name }
        .map { |origin, group| [origin, sum(group)] }
        .to_h

        day_billings_by_origin
      end

      def sum(billings)
        billings.inject(0.0) { |sum, billing| sum + billing.amount.to_f }
      end
    end

    def initialize(
      imsi:,
      device_id:,
      date:,
      bill_item_name:,
      amount:)
      @imsi = imsi
      @device_id = device_id
      @date = date
      @bill_item_name = bill_item_name
      @amount = amount
    end
  end
end