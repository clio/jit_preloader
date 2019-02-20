class Database
  def self.tables
    [
      "CREATE TABLE contacts (id INTEGER NOT NULL PRIMARY KEY, name VARCHAR(255), contact_owner_id INTEGER, contact_owner_type VARCHAR(255))",
      "CREATE TABLE contact_owners (id INTEGER NOT NULL PRIMARY KEY, name VARCHAR(255))",
      "CREATE TABLE addresses (id INTEGER NOT NULL PRIMARY KEY, contact_id INTEGER NOT NULL, country_id INTEGER NOT NULL, street VARCHAR(255))",
      "CREATE TABLE email_addresses (id INTEGER NOT NULL PRIMARY KEY, contact_id INTEGER NOT NULL, address VARCHAR(255))",
      "CREATE TABLE phone_numbers (id INTEGER NOT NULL PRIMARY KEY, contact_id INTEGER NOT NULL, phone VARCHAR(10))",
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
