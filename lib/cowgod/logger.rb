# frozen_string_literal: true

module Cowgod
  class Logger
    def self.log(message)
      puts "#{Time.current.strftime('%F %T')} - #{message}"
    end
  end
end
