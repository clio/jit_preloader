require 'spec_helper'

RSpec.describe JitPreloader::Preloader do

  it "does the thing" do
    c = Contact.create(name: "test")
    expect(c).to be_persisted
    expect(c.name).to eql "test"
  end

end
