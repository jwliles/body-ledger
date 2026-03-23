class SyncCursor < ApplicationRecord
  belongs_to :device

  DIRECTIONS = %w[upload download both].freeze

  validates :direction, inclusion: { in: DIRECTIONS }
end
