class Database
  def self.tables
    [
      "CREATE TABLE contacts (id INTEGER NOT NULL PRIMARY KEY, name VARCHAR(255))",
      "CREATE TABLE addresses (id INTEGER NOT NULL PRIMARY KEY, contact_id INTEGER NOT NULL, country_id INTEGER NOT NULL, street VARCHAR(255))",
      "CREATE TABLE email_addresses (id INTEGER NOT NULL PRIMARY KEY, contact_id INTEGER NOT NULL, address VARCHAR(255))",
      "CREATE TABLE countries (id INTEGER NOT NULL PRIMARY KEY, name VARCHAR(255))",
    ]
  end

  def self.build!
    tables.each do |table|
      ActiveRecord::Base.connection.execute(table)
    end
  end

  def self.connect!
    ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ":memory:"
  end

end
