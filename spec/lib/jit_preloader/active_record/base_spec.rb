require 'spec_helper'
require "db-query-matchers"

RSpec.describe "ActiveRecord::Base Extensions" do

  let(:canada) { Country.create(name: "Canada") }
  let(:usa) { Country.create(name: "U.S.A") }

  describe "#preload_scoped_relation" do
    def call(contact)
      contact.preload_scoped_relation(
        name: "American Addresses",
        base_association: :addresses,
        preload_scope: Address.where(country: usa)
      )
    end

    before do
      Contact.create(name: "Bar", addresses: [
        Address.new(street: "123 Fake st", country: canada),
        Address.new(street: "21 Jump st", country: usa),
        Address.new(street: "90210 Beverly Hills", country: usa)
      ])

      Contact.create(name: "Foo", addresses: [
        Address.new(street: "1 First st", country: canada),
        Address.new(street: "10 Tenth Ave", country: usa)
      ])
    end

    context "when operating on a single object" do
      it "will load the objects for that object" do
        contact = Contact.first
        expect(call(contact)).to match_array contact.addresses.where(country: usa).to_a
      end
    end

    it "memoizes the result" do
      contacts = Contact.jit_preload.limit(2).to_a

      expect do
        expect(call(contacts.first))
        expect(call(contacts.first))
      end.to make_database_queries(count: 1)
    end

    context "when reloading the object" do
      it "clears the memoization" do
        contacts = Contact.jit_preload.limit(2).to_a

        expect do
          expect(call(contacts.first))
        end.to make_database_queries(count: 1)
        contacts.first.reload
        expect do
          expect(call(contacts.first))
        end.to make_database_queries(count: 1)
      end
    end

    it "will issue one query for the group of objects" do
      contacts = Contact.jit_preload.limit(2).to_a

      usa_addresses = contacts.first.addresses.where(country: usa).to_a
      expect do
        expect(call(contacts.first)).to match_array usa_addresses
      end.to make_database_queries(count: 1)

      usa_addresses = contacts.last.addresses.where(country: usa).to_a
      expect do
        expect(call(contacts.last)).to match_array usa_addresses
      end.to_not make_database_queries
    end

    it "doesn't load the value into the association" do
      contacts = Contact.jit_preload.limit(2).to_a
      call(contacts.first)

      expect(contacts.first.association(:addresses)).to_not be_loaded
      expect(contacts.last.association(:addresses)).to_not be_loaded
    end

    context "when the association is already loaded" do
      it "doesn't change the value of the association" do
        contacts = Contact.jit_preload.limit(2).to_a
        contacts.each{|contact| contact.addresses.to_a }
        contacts.each{|contact| call(contact) }

        expect(contacts.first.association(:addresses)).to be_loaded
        expect(contacts.last.association(:addresses)).to be_loaded
      end
    end
  end
end
