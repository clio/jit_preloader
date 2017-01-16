class Contact < ActiveRecord::Base
  has_many :addresses
  has_one :email_address

  has_many_aggregate :addresses, :max_street_length, :maximum, "LENGTH(street)"
  has_many_aggregate :addresses, :count, :count, "*"
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
