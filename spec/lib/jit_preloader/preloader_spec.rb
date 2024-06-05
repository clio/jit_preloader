require "spec_helper"
require "db-query-matchers"

RSpec.describe JitPreloader::Preloader do
  let!(:contact1) do
    addresses = [
      Address.new(street: "123 Fake st", country: canada),
      Address.new(street: "21 Jump st", country: usa),
      Address.new(street: "90210 Beverly Hills", country: usa)
    ]
    phones = [
      PhoneNumber.new(phone: "4445556666"),
      PhoneNumber.new(phone: "2223333444")
    ]
    Contact.create(name: "Only Addresses", addresses: addresses, phone_numbers: phones)
  end

  let!(:contact2) do
    Contact.create(name: "Only Emails", email_address: EmailAddress.new(address: "woot@woot.com"))
  end

  let!(:contact3) do
    addresses = [
      Address.new(street: "1 First st", country: canada),
      Address.new(street: "10 Tenth Ave", country: usa)
    ]
    Contact.create(
      name: "Both!",
      addresses: addresses,
      email_address: EmailAddress.new(address: "woot@woot.com"),
      phone_numbers: [PhoneNumber.new(phone: "1234567890")]
    )
  end

  let!(:contact_owner) do
    contact3.contact_owner_id = contact1.id
    contact3.contact_owner_type = "Address"
    contact3.save!
    ContactOwner.create(
      contacts: [contact1, contact2],
    )
  end

  let(:canada) { Country.create(name: "Canada") }
  let(:usa) { Country.create(name: "U.S.A") }

  let(:source_map) { Hash.new{|h,k| h[k]= Array.new } }
  let(:callback) do
    ->(event, data){ source_map[data[:source]] << data[:association] }
  end

  context "for single table inheritance" do
    context "when preloading an aggregate for a child model" do
      let!(:contact_book) { ContactBook.create(name: "The Yellow Pages") }
      let!(:company1) { Company.create(name: "Company1", contact_book: contact_book) }
      let!(:company2) { Company.create(name: "Company2", contact_book: contact_book) }

      it "can handle queries" do
        contact_books = ContactBook.jit_preload.to_a
        expect(contact_books.first.companies_count).to eq 2
      end
    end

    context "when preloading an aggregate of a child model through its base model" do
      let!(:contact_book) { ContactBook.create(name: "The Yellow Pages") }
      let!(:contact) { Contact.create(name: "Contact", contact_book: contact_book) }
      let!(:company1) { Company.create(name: "Company1", contact_book: contact_book) }
      let!(:company2) { Company.create(name: "Company2", contact_book: contact_book) }
      let!(:contact_employee1) { Employee.create(name: "Contact Employee1", contact: contact) }
      let!(:contact_employee2) { Employee.create(name: "Contact Employee2", contact: contact) }
      let!(:company_employee1) { Employee.create(name: "Company Employee1", contact: company1) }
      let!(:company_employee2) { Employee.create(name: "Company Employee2", contact: company2) }

      it "can handle queries" do
        contact_books = ContactBook.jit_preload.to_a
        expect(contact_books.first.employees_count).to eq 4
      end
    end

    context "when preloading an aggregate of a nested child model through another child model" do
      let!(:contact_book) { ContactBook.create(name: "The Yellow Pages") }
      let!(:contact) { Contact.create(name: "Contact", contact_book: contact_book) }
      let!(:company1) { Company.create(name: "Company1", contact_book: contact_book) }
      let!(:company2) { Company.create(name: "Company2", contact_book: contact_book) }
      let!(:contact_employee1) { Employee.create(name: "Contact Employee1", contact: contact) }
      let!(:contact_employee2) { Employee.create(name: "Contact Employee2", contact: contact) }
      let!(:company_employee1) { Employee.create(name: "Company Employee1", contact: company1) }
      let!(:company_employee2) { Employee.create(name: "Company Employee2", contact: company2) }

      it "can handle queries" do
        contact_books = ContactBook.jit_preload.to_a
        expect(contact_books.first.company_employees_count).to eq 2
      end
    end

    context "when preloading an aggregate of a nested child model through a many-to-many relationship with another child model" do
      let!(:contact_book) { ContactBook.create(name: "The Yellow Pages") }
      let!(:child1) { Child.create(name: "Child1") }
      let!(:child2) { Child.create(name: "Child2") }
      let!(:child3) { Child.create(name: "Child3") }
      let!(:parent1) { Parent.create(name: "Parent1", contact_book: contact_book, children: [child1, child2]) }
      let!(:parent2) { Parent.create(name: "Parent2", contact_book: contact_book, children: [child2, child3]) }

      it "can handle queries" do
        contact_books = ContactBook.jit_preload.to_a
        expect(contact_books.first.children_count).to eq 4
        expect(contact_books.first.children).to include(child1, child2, child3)
      end
    end

    context "when preloading an aggregate for a child model scoped by another join table" do
      let!(:contact_book) { ContactBook.create(name: "The Yellow Pages") }
      let!(:contact1) { Company.create(name: "Without Email", contact_book: contact_book) }
      let!(:contact2) { Company.create(name: "With Blank Email", email_address: EmailAddress.new(address: ""), contact_book: contact_book) }
      let!(:contact3) { Company.create(name: "With Email", email_address: EmailAddress.new(address: "a@a.com"), contact_book: contact_book) }

      it "can handle queries" do
        contact_books = ContactBook.jit_preload.to_a
        expect(contact_books.first.companies_with_blank_email_address_count).to eq 1
        expect(contact_books.first.companies_with_blank_email_address).to eq [contact2]
      end
    end
  end

  context "when preloading an aggregate as polymorphic" do
    let(:contact_owner_counts) { [2] }

    context "without jit preload" do
      it "generates N+1 query notifications for each one" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          ContactOwner.all.each_with_index do |c, i|
            expect(c.contacts_count).to eql contact_owner_counts[i]
          end
        end

        contact_owner_queries = [contact_owner].product([["contacts.count"]])
        expect(source_map).to eql(Hash[contact_owner_queries])
      end
    end

    context "with jit_preload" do

      it "does NOT generate N+1 query notifications" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          ContactOwner.jit_preload.each_with_index do |c, i|
            expect(c.contacts_count).to eql contact_owner_counts[i]
          end
        end

        expect(source_map).to eql({})
      end

      it "can handle queries" do
        ContactOwner.jit_preload.each_with_index do |c, i|
          expect(c.contacts_count).to eql contact_owner_counts[i]
        end
      end

      context "when a record has a polymorphic association type that's not an ActiveRecord" do
        before do
          contact1.update!(contact_owner_type: "NilClass", contact_owner_id: nil)
        end

        it "doesn't die while trying to load the association" do
          expect(Contact.jit_preload.map(&:contact_owner)).to eq [nil, ContactOwner.first, Address.first]
        end
      end

      context "when a record has a polymorphic association type is nil" do
        before do
          contact1.update!(contact_owner_type: nil, contact_owner_id: nil)
        end

        it "successfully load the rest of association values" do
          contacts = Contact.jit_preload.to_a
          expect(contacts.first.contact_owner).to eq(nil)

          expect do
            contacts.first.contact_owner
            contacts.second.contact_owner
            contacts.third.contact_owner
          end.not_to make_database_queries

          expect(contacts.second.contact_owner).to eq(ContactOwner.first)
          expect(contacts.third.contact_owner).to eq(Address.first)
        end

        it "publish N+1 notification due to polymorphic nil type" do
          contacts = Contact.jit_preload.to_a

          ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
            contacts.first.contact_owner
          end

          expect_source_map = { contacts.first => [:contact_owner] }
          expect(source_map).to eql(expect_source_map)
        end
      end
    end
  end

  context "when preloading an aggregate on a has_many through relationship" do
    let(:country_contacts_counts) { [2, 3] }

    context "without jit preload" do
      it "generates N+1 query notifications for each one" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          Country.all.each_with_index do |c, i|
            expect(c.contacts_count).to eql country_contacts_counts[i]
          end
        end

        country_contact_queries = [canada, usa].product([["contacts.count"]])
        expect(source_map).to eql(Hash[country_contact_queries])
      end
    end

    context "with jit_preload" do
      it "does NOT generate N+1 query notifications" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          Country.all.jit_preload.each_with_index do |c, i|
            expect(c.contacts_count).to eql country_contacts_counts[i]
          end
        end

        expect(source_map).to eql({})
      end

      it "can handle queries" do
        Country.all.jit_preload.each_with_index do |c, i|
          expect(c.contacts_count).to eql country_contacts_counts[i]
        end
      end
    end
  end

  context "when accessing an association with a scope that has a parameter" do
    let!(:contact_book) { ContactBook.create(name: "The Yellow Pages") }
    let!(:contact) { Contact.create(name: "Contact", contact_book: contact_book) }
    let!(:company1) { Company.create(name: "Company1", contact_book: contact_book) }

    it "is unable to be preloaded" do
      ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
        ContactBook.all.jit_preload.each do |contact_book|
          expect(contact_book.contacts_with_scope.to_a).to eql [company1, contact]
        end
      end

      expect(source_map).to eql(Hash[contact_book, [:contacts_with_scope]])
    end
  end

  context "when preloading an aggregate on a polymorphic has_many through relationship" do
    let(:contact_owner_addresses_counts) { [3] }

    context "without jit preload" do
      it "generates N+1 query notifications for each one" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          ContactOwner.all.each_with_index do |c, i|
            expect(c.addresses_count).to eql contact_owner_addresses_counts[i]
          end
        end

        contact_owner_addresses_queries = [contact_owner].product([["addresses.count"]])
        expect(source_map).to eql(Hash[contact_owner_addresses_queries])
      end
    end

    context "with jit_preload" do
      it "does NOT generate N+1 query notifications" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          ContactOwner.all.jit_preload.each_with_index do |c, i|
            expect(c.addresses_count).to eql contact_owner_addresses_counts[i]
          end
        end

        expect(source_map).to eql({})
      end

      it "can handle queries" do
        ContactOwner.all.jit_preload.each_with_index do |c, i|
          expect(c.addresses_count).to eql contact_owner_addresses_counts[i]
        end
      end
    end
  end

  context "when preloading a has_many through polymorphic aggregate where the through class has a polymorphic relationship to the target class" do
    let(:contact_owner_counts) { [1, 2] }

    context "without jit preload" do
      it "generates N+1 query notifications for each one" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          Country.all.each_with_index do |c, i|
            expect(c.contact_owners_count).to eql contact_owner_counts[i]
          end
        end

        contact_owner_queries = [canada, usa].product([["contact_owners.count"]])
        expect(source_map).to eql(Hash[contact_owner_queries])
      end
    end

    context "with jit_preload" do
      it "does NOT generate N+1 query notifications" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          Country.all.jit_preload.each_with_index do |c, i|
            expect(c.contact_owners_count).to eql contact_owner_counts[i]
          end
        end

        expect(source_map).to eql({})
      end

      it "can handle queries" do
        Country.all.jit_preload.each_with_index do |c, i|
          expect(c.contact_owners_count).to eql contact_owner_counts[i]
        end
      end
    end
  end

  context "when a singular association id changes after preload" do
    let!(:contact_book1) { ContactBook.create(name: "The Yellow Pages") }
    let!(:contact_book2) { ContactBook.create(name: "The White Pages") }
    let!(:company1) { Company.create(name: "Company1", contact_book: contact_book1) }
    let!(:company2) { Company.create(name: "Company2", contact_book: contact_book1) }

    it "allows the association to be reloaded" do
      companies = Company.where(id: [company1.id, company2.id]).jit_preload.all.to_a
      expect(companies.map(&:contact_book)).to match_array [contact_book1, contact_book1]

      company = companies.each {|c| c.contact_book_id = contact_book2.id }

      expect(companies.map(&:contact_book)).to match_array [contact_book2, contact_book2]
    end
  end

  context "when preloading an aggregate" do
    let(:addresses_counts) { [3, 0, 2] }
    let(:phone_number_counts) { [2, 0, 1] }
    let(:maxes) { [19, 0, 12] }

    context "without jit_preload" do
      it "generates N+1 query notifications for each one" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          Contact.all.each_with_index do |c, i|
            expect(c.addresses_count).to eql addresses_counts[i]
            expect(c.addresses_max_street_length).to eql maxes[i]
            expect(c.phone_numbers_count).to eql phone_number_counts[i]
          end
        end

        contact_queries = [contact1, contact2, contact3].product([["addresses.count", "addresses.maximum", "phone_numbers.count"]])
        expect(source_map).to eql(Hash[contact_queries])
      end
    end

    context "with jit_preload" do
      let(:usa_addresses_counts) { [2, 0, 1] }
      let(:can_addresses_counts) { [1, 0, 1] }

      it "does NOT generate N+1 query notifications" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          Contact.jit_preload.each_with_index do |c, i|
            expect(c.addresses_count).to eql addresses_counts[i]
            expect(c.addresses_max_street_length).to eql maxes[i]
            expect(c.phone_numbers_count).to eql phone_number_counts[i]
          end
        end

        expect(source_map).to eql({})
      end

      it "can handle dynamic queries" do
        Contact.jit_preload.each_with_index do |c, i|
          expect(c.addresses_count(country: usa)).to eql usa_addresses_counts[i]
          expect(c.addresses_count(country: canada)).to eql can_addresses_counts[i]
        end
      end
    end
  end

  context "when we marshal dump the active record object" do
    it "nullifes the jit_preloader reference" do
      contacts = Contact.jit_preload.to_a
      reloaded_contacts = contacts.collect{|r| Marshal.load(Marshal.dump(r)) }
      contacts.each do |c|
        expect(c.jit_preloader).to_not be_nil
      end
      reloaded_contacts.each do |c|
        expect(c.jit_preloader).to be_nil
      end
    end
  end

  context "when the preloader is globally enabled" do
    around do |example|
      JitPreloader.globally_enabled = true
      example.run
      JitPreloader.globally_enabled = false
    end
    it "doesn't reference the same records array that is returned" do
      contacts = Contact.all.to_a
      contacts << "A string"
      expect(contacts.first.jit_preloader.records).to eql Contact.all.to_a
    end

    context "when grabbing all of the address'es contries and email addresses" do
      it "doesn't generate an N+1 query ntoification" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          Contact.all.collect{|c| c.addresses.collect(&:country); c.email_address }
        end
        expect(source_map).to eql({})
      end
    end

    context "when we perform aggregate functions on the data" do
      it "generates N+1 query notifications for each one" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          Contact.all.each{|c| c.addresses.count; c.addresses.sum(:id) }
        end
        contact_queries = [contact1,contact2, contact3].product([["addresses.count", "addresses.sum"]])
        expect(source_map).to eql(Hash[contact_queries])
      end
    end
  end

  context "when the preloader is not globally enabled" do
    context "when we perform aggregate functions on the data" do
      it "generates N+1 query notifications for each one" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          Contact.all.each{|c| c.addresses.count; c.addresses.sum(:id) }
        end
        contact_queries = [contact1,contact2, contact3].product([["addresses.count", "addresses.sum"]])
        expect(source_map).to eql(Hash[contact_queries])
      end
    end

    context "when explicitly finding a contact" do
      it "generates N+1 query notifications for the country" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          Contact.find(contact1.id).tap{|c| c.addresses.collect(&:country); c.email_address }
        end
        address_queries = Address.where(contact_id: 1).to_a.product([[:country]])
        expect(source_map).to eql(Hash[address_queries])
      end
    end

    context "when explicitly finding multiple contacts" do
      it "generates N+1 query notifications for the country" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          Contact.find(contact1.id, contact2.id).each{|c| c.addresses.collect(&:country); c.email_address }
        end
        contact_queries = [contact1,contact2].product([[:addresses, :email_address]])
        address_queries = Address.where(contact_id: contact1.id).to_a.product([[:country]])

        expect(source_map).to eql(Hash[address_queries.concat(contact_queries)])
      end
    end

    context "when grabbing the email address and address's country of the first contact" do
      it "generates N+1 query notifications for the country" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          Contact.first.tap{|c| c.addresses.collect(&:country); c.email_address }
        end

        address_queries = Address.where(contact_id: contact1.id).to_a.product([[:country]])

        expect(source_map).to eql(Hash[address_queries])
      end
    end

    context "when grabbing all of the address'es contries and email addresses" do
      it "generates an N+1 query for each association on the contacts" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          Contact.all.each{|c| c.addresses.collect(&:country); c.email_address }
        end
        contact_queries = [contact1,contact2,contact3].product([[:addresses, :email_address]])
        address_queries = Address.all.to_a.product([[:country]])
        expect(source_map).to eql(Hash[address_queries.concat(contact_queries)])
      end

      context "and we use regular preload for addresses" do
        it "generates an N+1 query for only the email addresses on the contacts" do
          ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
            Contact.preload(:addresses).each{|c| c.addresses.collect(&:country); c.email_address }
          end
          contact_queries = [contact1,contact2,contact3].product([[:email_address]])
          address_queries = Address.all.to_a.product([[:country]])
          expect(source_map).to eql(Hash[address_queries.concat(contact_queries)])
        end
      end

      context "and we use jit preload" do
        it "generates no n+1 queries" do
          ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
            Contact.jit_preload.each{|c| c.addresses.collect(&:country); c.email_address }
          end
          expect(source_map).to eql({})
        end
      end

      context "reload" do
        it "clears the jit_preload_aggregates" do
          contact = Contact.jit_preload.first

          contact.addresses_count

          expect { contact.reload }.to change{ contact.jit_preload_aggregates }.to({})
        end
      end
    end

    context "with dive limit set" do
      let!(:contact_book_1) { ContactBook.create(name: "The Yellow Pages") }
      let!(:contact_book_2) { ContactBook.create(name: "The Yellow Pages") }
      let!(:contact_book_3) { ContactBook.create(name: "The Yellow Pages") }
      let!(:company1) { Company.create(name: "Company1", contact_book: contact_book_1) }
      let!(:company2) { Company.create(name: "Company2", contact_book: contact_book_1) }
      let!(:company3) { Company.create(name: "Company2", contact_book: contact_book_2) }
      let!(:company4) { Company.create(name: "Company4", contact_book: contact_book_3) }
      let!(:company5) { Company.create(name: "Company5", contact_book: contact_book_3) }

      context "from the global value" do
        before do
          JitPreloader.max_ids_per_query = 2
        end

        after do
          JitPreloader.max_ids_per_query = nil
        end

        it "can handle queries" do
          contact_books = ContactBook.jit_preload.to_a

          expect(contact_books.first.companies_count).to eq 2
          expect(contact_books.second.companies_count).to eq 1
          expect(contact_books.last.companies_count).to eq 2
        end

        it "makes the right number of queries based on dive limit" do
          contact_books = ContactBook.jit_preload.to_a
          expect do
            contact_books.first.companies_count
          end.to make_database_queries(count: 2)

          expect do
            contact_books.second.companies_count
            contact_books.last.companies_count
          end.to_not make_database_queries
        end
      end

      context "from aggregate argument" do
        it "can handle queries" do
          contact_books = ContactBook.jit_preload.to_a

          expect(contact_books.first.companies_count_with_max_ids_set).to eq 2
          expect(contact_books.second.companies_count_with_max_ids_set).to eq 1
          expect(contact_books.last.companies_count_with_max_ids_set).to eq 2
        end

        it "makes the right number of queries based on dive limit" do
          contact_books = ContactBook.jit_preload.to_a
          expect do
            contact_books.first.companies_count_with_max_ids_set
          end.to make_database_queries(count: 2)

          expect do
            contact_books.second.companies_count_with_max_ids_set
            contact_books.last.companies_count_with_max_ids_set
          end.to_not make_database_queries
        end
      end
    end
  end

end
