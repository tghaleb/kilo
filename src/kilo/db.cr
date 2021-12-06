class SQLite3::ResultSet < DB::ResultSet
  def read(t : Int16.class) : Int16
    read(Int64).to_i16
  end

  def read(t : Union(Int16 | Nil).class)
    # maybe we need to test for Nil here and return 0
    # but for now leave like so
    read(Int64).to_i16
  end
end

class SQLite3::Statement < DB::Statement
  private def bind_arg(index, value : Int16)
    check LibSQLite3.bind_int(self, index, value.to_i32)
  end
end

module Kilo
  class DB_Helper
    getter db
    getter db_args
    getter file

    @db_args = Array(DB::Any).new
    @db : DB::Database
    #    @tmp : File = Comandante::Cleaner.tempfile
    @file = ""

    def initialize(file : String = ":memory:")
      #      if file == ":tmp:"
      #        @db = DB.open "sqlite3://#{@tmp.path}"
      if file == ":memory:"
        #        @tmp.delete
        @db = DB.open "sqlite3::memory:"
      else
        # we work in tmp because it is faster at least in linux
        @file = File.expand_path(file)
        #        if File.file? file
        #          FileUtils.cp(file, @tmp.path)
        #        end
        # @db = DB.open "sqlite3://#{@tmp.path}"
        @db = DB.open "sqlite3://#{@file}"
      end

      Comandante::Cleaner.register(->{ self.close })
    end

    # safer query will cleanup
    def query(stmt)
      begin
        @db.query(stmt) do |rs|
          yield rs
        end
      rescue e
        @db.close
        raise e
      end
    end

    # Returns the path for an open db
    def current_path
      # return @tmp.path
      return @file
    end

    def close
      @db.close
      #      if (@file != "") && (File.file? @tmp.path)
      #        FileUtils.mv(@tmp.path, @file)
      #      end
    end

    def finalize
      close
    end
  end
end
