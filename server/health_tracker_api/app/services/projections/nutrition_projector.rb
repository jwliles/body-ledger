module Projections
  class NutritionProjector < BaseProjector
    def self.metric_type = "nutrition"

    MACRO_COLUMNS = %i[calories_kcal protein_g fat_g carbohydrate_g fiber_g sugar_g sodium_mg].freeze

    private

    def compute_summary(events)
      payloads = events.map(&:nutrition_payload)

      macro_totals = MACRO_COLUMNS.each_with_object({}) do |col, acc|
        values = payloads.filter_map { |p| p.public_send(col)&.to_f }
        acc[:"total_#{col}"] = values.sum.round(2) if values.any?
      end

      macro_totals.merge(
        meal_count:  payloads.size,
        meal_types:  payloads.filter_map(&:meal_type).uniq.sort
      )
    end
  end
end
