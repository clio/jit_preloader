require 'spec_helper'

RSpec.describe JitPreloadExtension do
  context "key generation" do
    context "with no conditions" do
      it "returns the method name when no conditions" do
        expect(JitPreloadExtension.generate_key("method_name", {})).to eql("method_name")
      end
    end

    context "with conditions" do
      it "retuns the method names plus conditions when provided" do
        expect(JitPreloadExtension.generate_key("method_name", {a: '123'}))
          .to eql("method_name|a=123")

        expect(JitPreloadExtension.generate_key("method_name", {a: [9,8,7]}))
          .to eql("method_name|a=[9, 8, 7]")

        expect(JitPreloadExtension.generate_key("method_name", {a: {z: "123"}}))
          .to eql("method_name|a={:z=>\"123\"}")

        expect(JitPreloadExtension.generate_key("method_name", {a: :foobar}))
          .to eql("method_name|a=foobar")

        object = Contact.new
        expect(JitPreloadExtension.generate_key("method_name", {a: object}))
          .to eql("method_name|a=#{object}")
      end
    end
  end
end
