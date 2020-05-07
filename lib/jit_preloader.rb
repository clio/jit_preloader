require 'active_support/concern'
require 'active_support/core_ext/module/delegation'
require 'active_support/notifications'
require 'active_record'

require "jit_preloader/version"
require 'jit_preloader/active_record/base'
require 'jit_preloader/active_record/relation'
require 'jit_preloader/active_record/associations/collection_association'
require 'jit_preloader/active_record/associations/singular_association'
if Gem::Version.new(ActiveRecord::VERSION::STRING) < Gem::Version.new("5.2.2")
  require 'jit_preloader/active_record/associations/preloader/collection_association'
  require 'jit_preloader/active_record/associations/preloader/singular_association'
elsif Gem::Version.new(ActiveRecord::VERSION::STRING) >= Gem::Version.new("6.0.0")
  require 'jit_preloader/active_record/associations/preloader/ar6_association'
else
  require 'jit_preloader/active_record/associations/preloader/association'
end
require 'jit_preloader/preloader'

module JitPreloader

  def self.globally_enabled=(value)
    @enabled = value
  end

  def self.globally_enabled?
    if @enabled && @enabled.respond_to?(:call)
      @enabled.call
    else
      @enabled
    end
  end

end
