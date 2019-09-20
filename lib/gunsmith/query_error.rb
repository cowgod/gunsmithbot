class QueryError < StandardError
  def initialize(msg = 'Unspecified query error')
    super
  end
end
