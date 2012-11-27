require "rubygems"
require "sqlite3"

class DB

  def initialize(path)
    @dbobj = SQLite3::Database.new(path)
  end

  def execute(sql)
    @dbobj.execute(sql)
  end

  def insert(table, values)
    sql = "INSERT INTO #{table} VALUES( null,"
    q = [].fill("?", 0, values.length)
    sql = sql + q.join(",") + ")"
    @dbobj.execute(sql, values)
  end

  def countAll(table)
    res = ""
    @dbobj.execute("select count(*) as c from #{table}") do |row|
      res = row
    end
    res[0].to_i
  end

  def findById(table, id)
    res = []
    sql = "select * from #{table} where id = ?"
    @dbobj.query(sql, id).each do |v|
      res << v
    end
    res
  end

end
