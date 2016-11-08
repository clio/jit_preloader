require 'spec_helper'

RSpec.describe JitPreloader::Preloader do

  let!(:contact1) do
    Contact.create(
                   name: "Only Addresses", 
                   addresses: [
                               Address.new(street: "123 Fake st", country: canada), 
                               Address.new(street: "21 Jump st", country: usa)
                              ]
                   )
  end

  let!(:contact2) do
    Contact.create(
                   name: "Only Emails",
                   email_address: EmailAddress.new(address: "woot@woot.com"),
                   )
  end

  let!(:contact3) do
    Contact.create(
                   name: "Both!", 
                   addresses: [
                               Address.new(street: "1 First st", country: canada), 
                               Address.new(street: "10 Tenth Ave", country: usa)
                              ],
                   email_address: EmailAddress.new(address: "woot@woot.com"),
                   )
  end

  let(:canada) { Country.create(name: "Canada") }
  let(:usa) { Country.create(name: "U.S.A") }

  let(:source_map) { Hash.new{|h,k| h[k]= Array.new } }
  let(:callback) do
    ->(event, data){ source_map[data[:source]] << data[:association] }
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
        address_queries = Address.where(contact_id: 1).product([[:country]])
        expect(source_map).to eql(Hash[address_queries])
      end
    end

    context "when explicitly finding multiple contacts" do
      it "generates N+1 query notifications for the country" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          Contact.find(contact1.id, contact2.id).each{|c| c.addresses.collect(&:country); c.email_address }
        end
        contact_queries = [contact1,contact2].product([[:addresses, :email_address]])
        address_queries = Address.where(contact_id: contact1.id).product([[:country]])

        expect(source_map).to eql(Hash[address_queries.concat(contact_queries)])
      end
    end

    context "when grabbing the email address and address's country of the first contact" do
      it "generates N+1 query notifications for the country" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          Contact.first.tap{|c| c.addresses.collect(&:country); c.email_address }
        end

        address_queries = Address.where(contact_id: contact1.id).product([[:country]])

        expect(source_map).to eql(Hash[address_queries])
      end
    end

    context "when grabbing all of the address'es contries and email addresses" do
      it "generates an N+1 query for each association on the contacts" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          Contact.all.each{|c| c.addresses.collect(&:country); c.email_address }
        end
        contact_queries = [contact1,contact2,contact3].product([[:addresses, :email_address]])
        address_queries = Address.all.product([[:country]])
        expect(source_map).to eql(Hash[address_queries.concat(contact_queries)])
      end

      context "and we use regular preload for addresses" do
        it "generates an N+1 query for only the email addresses on the contacts" do
          ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
            Contact.preload(:addresses).each{|c| c.addresses.collect(&:country); c.email_address }
          end
          contact_queries = [contact1,contact2,contact3].product([[:email_address]])
          address_queries = Address.all.product([[:country]])
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
    end
  end

end
