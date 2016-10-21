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

  context "when the preloader is not globally enabled" do    
    context "when grabbing the email address and address of the first contact" do
      it "doesn't generate an N+1 query notification" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          Contact.first.tap{|c| c.addresses.to_a; c.email_address }
        end
        expect(source_map).to eql({})
      end
    end
    context "when grabbing all of the addresses and email addresses" do
      it "generates an N+1 query for each association on the contacts" do
        ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
          Contact.all.collect{|c| c.addresses.to_a; c.email_address }
        end
        expect(source_map).to eql(Hash[[contact1,contact2,contact3].product([[:addresses, :email_address]])])
      end

      context "and we use regular preload for addresses" do
        it "generates an N+1 query for only the email addresses on the contacts" do
          ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
            Contact.preload(:addresses).collect{|c| c.addresses.to_a; c.email_address }
          end
          expect(source_map).to eql(Hash[[contact1,contact2,contact3].product([[:email_address]])])
        end        
      end

      context "and we use jit preload" do
        it "generates no n+1 queries" do
          ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
            Contact.jit_preload.collect{|c| c.addresses.to_a; c.email_address }
          end
          expect(source_map).to eql({})
        end
      end
    end
  end

end
