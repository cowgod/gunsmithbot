# frozen_string_literal: true

module PresenceUtils
  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end

  def present?
    !blank?
  end
end

Object.include(PresenceUtils)


module NumericComparisonUtils
  def integer?
    /\A[-+]?\d+\z/ === self
  end

  def positive_integer?
    /\A\d+\z/ === self
  end
end

String.include(NumericComparisonUtils)


module NumericFormattingUtils
  # Add commas every 3 digits
  def to_formatted_s
    to_s.reverse.gsub(/...(?!-)(?=.)/, '\&,').reverse
  end
end

Integer.include(NumericFormattingUtils)