# frozen_string_literal: true


require 'mysql2'


# The Model contains all business logic.
#
# ActiveSupport::Callbacks support is included for before, after,
# or around hooks.
#
# The Model has access to the `client`, `data`, and `match` objects.
#
class SlackUser < SlackRubyBot::MVC::Model::Base
  # define_callbacks :fixup
  # set_callback :fixup, :before, :normalize_data
  # attr_accessor :_line
  attr_accessor :user_id, :team_id

  def initialize
    ##### TODO -- receive the connection via an argument instead of establishing it here.
    # TODO - Switch the class to use mysql instead of sqlite
    @db = Mysql2::Database.new ':memory'
    @db.results_as_hash = true
    @db.execute 'CREATE TABLE IF NOT EXISTS Inventory(Id INTEGER PRIMARY KEY,
            Name TEXT, Quantity INT, Price INT)'

    s = @db.prepare 'SELECT * FROM Inventory'
    results = s.execute
    count = 0
    count += 1 while results.next
    return if count < 4

    add_item "'Audi',3,52642"
    add_item "'Mercedes',1,57127"
    add_item "'Skoda',5,9000"
    add_item "'Volvo',1,29000"
  end

  def add_item(line)
    self._line = line # make line accessible to callback
    run_callbacks :fixup do
      name, quantity, price = parse(_line)
      row = @db.prepare('SELECT MAX(Id) FROM Inventory').execute
      max_id = row.next_hash['MAX(Id)']
      @db.execute "INSERT INTO Inventory VALUES(#{max_id + 1},'#{name}',#{quantity.to_i},#{price.to_i})"
    end
  end

  def read_item(line)
    self._line = line
    run_callbacks :fixup do
      name, _other = parse(_line)
      statement = if name == '*'
                    @db.prepare 'SELECT * FROM Inventory'
                  else
                    @db.prepare("SELECT * FROM Inventory WHERE Name='#{name}'")
      end

      results = statement.execute
      a = []
      results.each do |row|
        a << { id: row['Id'], name: row['Name'], quantity: row['Quantity'], price: row['Price'] }
      end
      a
    end
  end

  def update_item(line)
    self._line = line
    run_callbacks :fixup do
      name, quantity, price = parse(_line)
      statement = if price
                    @db.prepare "UPDATE Inventory SET Quantity=#{quantity}, Price=#{price} WHERE Name='#{name}'"
                  else
                    @db.prepare "UPDATE Inventory SET Quantity=#{quantity} WHERE Name='#{name}'"
      end
      statement.execute
      read_item(_line)
    end
  end

  def delete_item(line)
    self._line = line
    run_callbacks :fixup do
      name, _other = parse(_line)
      before_count = row_count
      statement = @db.prepare "DELETE FROM Inventory WHERE Name='#{name}'"
      statement.execute
      before_count != row_count
    end
  end

  private

  def row_count
    statement = @db.prepare 'SELECT COUNT(*) FROM Inventory'
    result = statement.execute
    result.next_hash['COUNT(*)']
  end

  def parse(line)
    line.split(',')
  end

  def normalize_data
    name, quantity, price = parse(_line)
    self._line = [name.capitalize, quantity, price].join(',')
  end
end
