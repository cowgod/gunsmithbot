require 'json'


class BungieManifest
  TABLES = %w[
    DestinySocketCategoryDefinition
    DestinyInventoryItemDefinition
  ].freeze


  def initialize(manifest_url)
    raise 'Invalid Manifest URL provided' unless manifest_url
    load_manifest(manifest_url)
  end


#   def lookup_item(id)
#     # CASE
#     #   WHEN id < 0 THEN id + 4294967296
#     #   ELSE id
#     # END AS id,
#     sql = <<SQL
#       SELECT
#         json
#       FROM DestinyInventoryItemDefinition
#       WHERE id =
#         CASE
#           WHEN ? > 2147483647 THEN ? - 4294967297
#           ELSE ?
#         END
# SQL
# 
#     json = @manifest.get_first_value(sql, id, id, id)
# 
#     json ? JSON.parse(json) : nil
#   end


  def lookup_item(hash)
    @manifest['DestinyInventoryItemDefinition'][hash.to_s]
  end

  def lookup_socket_category(hash)
    @manifest['DestinySocketCategoryDefinition'][hash.to_s]
  end


  private

  def load_manifest(manifest_url)
    print 'Downloading Manifest... '
    manifest_zipfile = Tempfile.new('manifest_zip')
    manifest_zipfile.write HTTParty.get(manifest_url).body

    manifest_db = Tempfile.new('manifest_db')

    Zip::File.open_buffer(manifest_zipfile) do |zip_file|
      entry = zip_file.glob('world_sql_content_*').first
      manifest_db.write entry.get_input_stream.read
    end

    @manifest = {}

    puts 'Done.'
    print 'Processing Manifest... '

    SQLite3::Database.open manifest_db.path do |db|
      begin
        TABLES.each do |table|
          @manifest[table] = {}

          db.execute "SELECT json FROM #{table}" do |row|
            next unless row
            item_detail = JSON.parse row[0]
            next unless item_detail.dig('hash')
            @manifest[table][item_detail.dig('hash').to_s] = item_detail
          end
        end
      rescue SQLite3::Exception => e
        puts 'Exception occurred'
        puts e
      ensure
        db.close if db
      end
    end

    puts 'Done.'

    @manifest
  end
end


