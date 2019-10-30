class ContactBook < ActiveRecord::Base
  has_many :contacts
  has_many :employees, through: :contacts

  has_many :companies
  has_many :company_employees, through: :companies, source: :employees

  has_many :parents
  has_many :children, through: :parents

  has_many_aggregate :companies, :count, :count, "*"
  has_many_aggregate :employees, :count, :count, "*"
  has_many_aggregate :company_employees, :count, :count, "*"
  has_many_aggregate :children, :count, :count, "*"
end

class Contact < ActiveRecord::Base
  belongs_to :contact_book
  belongs_to :contact_owner, polymorphic: true

  has_many :addresses
  has_many :phone_numbers
  has_one :email_address
  has_many :employees

  has_many_aggregate :addresses, :max_street_length, :maximum, "LENGTH(street)"
  has_many_aggregate :phone_numbers, :count, :count, "id"
  has_many_aggregate :addresses, :count, :count, "*"
end

class Company < Contact
end

class Employee < Contact
  belongs_to :contact
end

class ParentsChild < ActiveRecord::Base
  belongs_to :parent
  belongs_to :child
end

class Parent < Contact
  has_many :parents_child
  has_many :children, through: :parents_child
end

class Child < Contact
  has_many :parents_child
  has_many :parents, through: :parents_child
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
