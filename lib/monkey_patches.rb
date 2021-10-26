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


  def to_offset_string
    seconds = self % 60
    minutes = (self / 60) % 60
    hours   = self / (60 * 60)

    output = "#{seconds}s"
    output = "#{minutes}m#{output}" if minutes.positive?
    output = "#{hours}h#{output}" if hours.positive?

    output
  end


  def clamp(min, max)
    [self, min, max].sort[1]
  end
end

Integer.include(NumericFormattingUtils)


module UriEncodingUtils
  require 'cgi'


  def uri_encode
    CGI.escape(to_s).gsub('+', '%20')
  end
end

String.include(UriEncodingUtils)
Integer.include(UriEncodingUtils)

