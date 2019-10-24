class Contact < ActiveRecord::Base
  belongs_to :contact_owner, polymorphic: true

  has_many :addresses
  has_many :phone_numbers
  has_one :email_address

  has_many_aggregate :addresses, :max_street_length, :maximum, "LENGTH(street)"
  has_many_aggregate :phone_numbers, :count, :count, "id"
  has_many_aggregate :addresses, :count, :count, "*"
end

class Author < Contact
  belongs_to :book
  has_many :reviewers
end

class Reviewer < Contact
  belongs_to :author
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

class Book < ActiveRecord::Base
  has_many :sections
  has_many :sub_sections, through: :sections

  has_many :endorsements
  has_many :endorsement_sub_sections, through: :endorsements, source: :sub_sections

  has_many_aggregate :sub_sections, :count, :count, "*"
  has_many_aggregate :endorsement_sub_sections, :count, :count, "*"
end

class Section < ActiveRecord::Base
  belongs_to :book
  has_many :sub_sections
end

class Endorsement < Section
end

class SubSection < Section
  belongs_to :section
end
