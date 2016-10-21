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
                   email_addresses: [
                                     EmailAddress.new(address: "woot@woot.com"),
                                     EmailAddress.new(address: "huzzah@woot.com"),
                                    ]
                   )
  end

  let!(:contact3) do
    Contact.create(
                   name: "Both!", 
                   addresses: [
                               Address.new(street: "1 First st", country: canada), 
                               Address.new(street: "10 Tenth Ave", country: usa)
                              ],
                   email_addresses: [
                                     EmailAddress.new(address: "woot@woot.com"),
                                     EmailAddress.new(address: "huzzah@woot.com"),
                                    ]
                   )
  end

  let(:canada) { Country.create(name: "Canada") }
  let(:usa) { Country.create(name: "U.S.A") }

  context "when the preloader is disabled" do
    context "when grabbing all of the addresses" do
      it "generated an query for each contact" do
        Contact.all.jit_preload.collect{|c| c.addresses.to_a }
      end
    end
  end

end
