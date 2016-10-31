module JitPreloader
  class Preloader < ActiveRecord::Associations::Preloader

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
      # It is possible that the records array has multiple different classes (think single table inheritance).
      # Thus, it is possible that some of the records don't have an association.
      records_with_association = records.reject{|r| r.class.reflect_on_association(association).nil? }
      preload records_with_association, association
    end

  end
end
