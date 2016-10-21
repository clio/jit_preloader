class Contact < ActiveRecord::Base
  has_many :addresses
  has_many :email_addresses 
end

class Address < ActiveRecord::Base
  belongs_to :contact
  belongs_to :country
end

class EmailAddress < ActiveRecord::Base
  belongs_to :contact
end

class Country < ActiveRecord::Base
  has_many :addresses
end
