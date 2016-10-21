require 'jit_preloader/active_record/base'
require 'jit_preloader/active_record/query_methods'
require 'jit_preloader/active_record/relation'
require 'jit_preloader/active_record/associations/collection_association'
require 'jit_preloader/active_record/associations/singular_association'
require 'jit_preloader/active_record/associations/preloader/collection_association'
require 'jit_preloader/active_record/associations/preloader/singular_association'

module JitPreloader
  class Preloader < ActiveRecord::Associations::Preloader

    def self.globally_enabled=(value)
      @enabled = value
    end

    def self.globally_enabled?
      if @enabled && @enabled.responds_to?(:call)
        @enabled.call
      else
        @enabled
      end
    end

    attr_accessor :records

    def self.attach(records)
      new.tap do |loader|
        loader.records = records
        records.each do |record|
          record.jit_preloader = loader
        end
      end
    end

    def jit_preload(association)
      # It is possible that the records array has multiple different classes (think single table inheritance)
      # Thus, it is possible that some of the records don't have an association
      records_with_association = records.reject{|r| r.class.reflect_on_association(association).nil? }
      preload records_with_association, association
    end

  end
end
