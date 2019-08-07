class Contact < ActiveRecord::Base
  belongs_to :contact_owner, polymorphic: true

  has_many :addresses
  has_many :phone_numbers
  has_one :email_address

  has_many_aggregate :addresses, :max_street_length, :maximum, "LENGTH(street)"
  has_many_aggregate :phone_numbers, :count, :count, "id"
  has_many_aggregate :addresses, :count, :count, "*"
end

class Address < ActiveRecord::Base
  belongs_to :contact
  belongs_to :country
end

class EmailAddress < ActiveRecord::Base
  belongs_to :contact
end

class PhoneNumber < ActiveRecord::Base
  belongs_to :contact
end

class Country < ActiveRecord::Base
  has_many :addresses
  has_many :contacts, through: :addresses
  has_many :contact_owners, through: :contacts, source_type: 'ContactOwner'

  has_many_aggregate :contacts, :count, :count, "*"
  has_many_aggregate :contact_owners, :count, :count, "*"
end

class ContactOwner < ActiveRecord::Base
  has_many :contacts, as: :contact_owner
  has_many :addresses, through: :contacts

  has_many_aggregate :contacts, :count, :count, "*"
  has_many_aggregate :addresses, :count, :count, "*"
end
