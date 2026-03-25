class PasswordComplexityValidator < ActiveModel::EachValidator
  UPPER   = /[A-Z]/
  LOWER   = /[a-z]/
  DIGIT   = /[0-9]/
  SPECIAL = /[^a-zA-Z0-9]/

  def validate_each(record, attribute, value)
    return if value.blank?

    record.errors.add(attribute, "must contain an uppercase letter")    unless value.match?(UPPER)
    record.errors.add(attribute, "must contain a lowercase letter")     unless value.match?(LOWER)
    record.errors.add(attribute, "must contain a digit")                unless value.match?(DIGIT)
    record.errors.add(attribute, "must contain a special character")    unless value.match?(SPECIAL)

    if value.length >= 2
      first = char_type(value[0])
      last  = char_type(value[-1])
      if first == last
        record.errors.add(attribute, "cannot start and end with the same character type (#{first})")
      end
    end

    result = Zxcvbn.test(value)
    if result.score < 3
      hint = result.feedback.warning.presence || "try a longer or more varied password"
      record.errors.add(attribute, "is not strong enough — #{hint}")
    end
  end

  private

  def char_type(c)
    if c.match?(DIGIT)
      "digit"
    elsif c.match?(UPPER) || c.match?(LOWER)
      "letter"
    else
      "special character"
    end
  end
end
