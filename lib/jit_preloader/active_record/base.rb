module JitPreloadExtension

  extend ActiveSupport::Concern

  included do
    attr_accessor :jit_preloader
    attr_accessor :jit_n_plus_one_tracking
  end

  class_methods do
    delegate :jit_preload, to: :all
  end
end

ActiveRecord::Base.send(:include, JitPreloadExtension)
