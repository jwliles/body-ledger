class NutritionPayload < ApplicationRecord
  include ImmutableRecord

  self.primary_key = :health_event_id

  belongs_to :health_event

  MEAL_TYPES = %w[breakfast lunch dinner snack supplement].freeze

  validates :meal_type, inclusion: { in: MEAL_TYPES }, allow_nil: true

  [ :calories_kcal, :protein_g, :fat_g, :carbohydrate_g,
    :fiber_g, :sugar_g, :sodium_mg ].each do |macro|
    validates macro, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  end
end
