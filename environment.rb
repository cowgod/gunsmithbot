require 'otr-activerecord'

# Recursively requires all files in ./lib and down that end in .rb
Dir['./lib/**/*.rb', base: __dir__].each do |file|
  require_relative file
end


# db_config = YAML.safe_load(File.open(File.expand_path(__dir__, '../config/database.yml')))
# puts db_config
# ActiveRecord::Base.establish_connection(db_config)


# ActiveRecord::Base.establish_connection(
#   adapter:  'mysql2',
#   host:     ENV['GUNSMITH_DB_HOST'],
#   username: ENV['GUNSMITH_DB_USER'],
#   password: ENV['GUNSMITH_DB_PASS'],
#   database: ENV['GUNSMITH_DB_NAME']
# )


OTR::ActiveRecord.configure_from_file! 'config/database.yml'

