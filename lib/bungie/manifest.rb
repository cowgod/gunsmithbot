# frozen_string_literal: true

require 'json'

module Bungie
  class Manifest
    def initialize(manifest_url)
      raise 'Invalid Manifest URL provided' unless manifest_url

      load_manifest(manifest_url)
    end


    def lookup_item(hash)
      lookup_item_in_table('DestinyInventoryItemDefinition', hash)
    end


    def lookup_socket_category(hash)
      lookup_item_in_table('DestinySocketCategoryDefinition', hash)
    end


    def lookup_item_category(hash)
      lookup_item_in_table('DestinyItemCategoryDefinition', hash)
    end


    def lookup_activity(hash)
      lookup_item_in_table('DestinyActivityDefinition', hash)
    end


    def lookup_stat(hash)
      lookup_item_in_table('DestinyStatDefinition', hash)
    end


    def lookup_energy_type(hash)
      lookup_item_in_table('DestinyEnergyTypeDefinition', hash)
    end


    def lookup_objective(hash)
      lookup_item_in_table('DestinyObjectiveDefinition', hash)
    end


    private


    def load_manifest(manifest_url)
      Cowgod::Logger.log "#{self.class}.#{__method__} - Downloading Manifest..."

      manifest_zipfile = Tempfile.new('manifest_zip', encoding: 'ascii-8bit')
      manifest_zipfile.write HTTParty.get(manifest_url).body

      manifest_db_file = Tempfile.new('manifest_db', encoding: 'ascii-8bit')

      Zip::File.open_buffer(manifest_zipfile) do |zip_file|
        entry = zip_file.glob('world_sql_content_*').first
        manifest_db_file.write entry.get_input_stream.read
      end

      Cowgod::Logger.log "#{self.class}.#{__method__} - Done."


      Cowgod::Logger.log "#{self.class}.#{__method__} - Opening DB connection to local manifest..."
      @manifest = SQLite3::Database.open manifest_db_file.path
      Cowgod::Logger.log "#{self.class}.#{__method__} - Done."
    end


    def lookup_item_in_table(table_name, id)
      # CASE
      #   WHEN id < 0 THEN id + 4294967296
      #   ELSE id
      # END AS id,
      sql = <<SQL
      SELECT
        json
      FROM #{table_name}
      WHERE id =
        CASE
          WHEN ? > 2147483646 THEN ? - 4294967296
          ELSE ?
        END
SQL

      json = @manifest.get_first_value(sql, id.to_i, id.to_i, id.to_i)

      json ? JSON.parse(json) : nil
    end
  end
end