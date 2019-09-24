# frozen_string_literal: true

require 'otr-activerecord'

# Recursively requires all files in ./lib and down that end in .rb
Dir['./lib/**/*.rb', base: __dir__].each do |file|
  require_relative file
end


OTR::ActiveRecord.configure_from_file! 'config/database.yml'

