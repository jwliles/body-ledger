module Projections
  # Base class for metric projectors.
  # Each subclass implements #compute_summary(events) → Hash and declares
  # its metric_type.
  class BaseProjector
    attr_reader :user, :date

    def initialize(user:, date:)
      @user = user
      @date = date
    end

    # Entry point. Fetches current events for the date, computes summary,
    # upserts daily_summary row, marks it confirmed.
    def project!
      events = current_events
      return unless events.any?

      summary = compute_summary(events)

      DailySummary.upsert(
        {
          user_id:      user.id,
          summary_date: date,
          metric_type:  self.class.metric_type,
          summary_data: summary,
          status:       "confirmed",
          created_at:   Time.current,
          updated_at:   Time.current
        },
        unique_by: %i[user_id summary_date metric_type],
        update_only: %i[summary_data status updated_at]
      )
    end

    private

    def current_events
      HealthEvent
        .current
        .confirmed
        .where(user: user, date_key: date, metric_type: self.class.metric_type)
        .includes(self.class.payload_association)
    end

    # Subclasses must implement this — returns a plain Hash.
    def compute_summary(_events)
      raise NotImplementedError, "#{self.class}#compute_summary is not implemented"
    end

    class << self
      def metric_type
        raise NotImplementedError, "#{self}::metric_type is not defined"
      end

      def payload_association
        :"#{metric_type}_payload"
      end
    end
  end
end
