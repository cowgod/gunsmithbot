# frozen_string_literal: true

class MultipleResultsError < StandardError
  def initialize(msg = 'Multiple results returned')
    super
  end
end
