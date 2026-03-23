module ImmutableRecord
  extend ActiveSupport::Concern

  class ImmutableRecordError < StandardError
    def initialize(msg = "This record is immutable and cannot be modified")
      super
    end
  end

  included do
    before_update :enforce_immutability
  end

  private

  # Subclasses declare which columns may change post-insert via mutable_columns.
  # Everything else raises ImmutableRecordError.
  def enforce_immutability
    changed_fields = changed - self.class.mutable_columns.map(&:to_s)
    raise ImmutableRecordError, "Cannot modify immutable fields: #{changed_fields.join(', ')}" if changed_fields.any?
  end

  class_methods do
    # Override in including model to allow specific columns to be updated.
    def mutable_columns
      []
    end
  end
end
