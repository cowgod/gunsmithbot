# frozen_string_literal: true

require 'otr-activerecord'

# Recursively requires all files in ./lib and down that end in .rb
Dir['./lib/**/*.rb', base: __dir__].each do |file|
  require_relative file
end


# A global variable isn't my favorite solution, but it'll work for now
$config = YAML.safe_load(File.read('./config/config.yml'))



OTR::ActiveRecord.configure_from_file! 'config/database.yml'
OTR::ActiveRecord.establish_connection!


