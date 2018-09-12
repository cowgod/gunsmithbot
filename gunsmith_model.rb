class GunsmithModel < SlackRubyBot::MVC::Model::Base
  define_callbacks :sanitize
  set_callback :sanitize, :around, :sanitize_resource
  attr_accessor :_resource

  def initialize
    @db = setup_database_connection
  end

  def read(resource)
    self._resource = resource
    run_callbacks :sanitize do
      @db.select(:column1 => resource)
      # ... do some expensive work
    end
  end

  private

  def sanitize_resource
    self._resource.downcase
    result = yield
    puts "After read, result is #{result.inspect}"
  end
end
