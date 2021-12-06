require 'sqlite3'

# Common class to be used by scoring scripts
class DB_Helper
  SELECT_SQL = 'SELECT * FROM layouts'
  UPDATE_SQL = 'UPDATE layouts SET score = ? WHERE layout =?'

  attr_reader :db

  def initialize(file)
    unless File.file? file
      warn("not a file '#{file}'")
      exit 1
    end
    @db = SQLite3::Database.open(file)
    @db.results_as_hash = true
  end

  # Selects and updates
  def update
    @db.execute(SELECT_SQL) do |row|
      yield row
      @db.execute(UPDATE_SQL, row['score'], row['layout'])
    end
  end


  def select
    @db.execute(SELECT_SQL) do |row|
      yield row
    end
  end
end


