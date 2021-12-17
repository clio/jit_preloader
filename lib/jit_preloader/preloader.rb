module JitPreloader
  class Preloader < ActiveRecord::Associations::Preloader

    attr_accessor :records

    def self.attach(records)
      new(records: records.dup, associations: nil).tap do |loader|
        records.each do |record|
          record.jit_preloader = loader
        end
      end
    end

    def jit_preload(associations)
      # It is possible that the records array has multiple different classes (think single table inheritance).
      # Thus, it is possible that some of the records don't have an association.
      records_with_association = records.reject{|r| r.class.reflect_on_association(associations).nil? }
      self.class.new(records: records_with_association, associations: associations).call
    end

    # We do not want the jit_preloader to be dumpable
    # If you dump a ActiveRecord::Base object that has a jit_preloader instance variable
    # you will also end up dumping all of the records the preloader has reference to.
    # Imagine getting N objects from a query and dumping each one of those into a cache
    # each object would dump N+1 objects which means you'll end up storing O(N^2) memory. Thats no good.
    # So instead, we will just nullify the jit_preloader on load
    def _dump(level)
      ""
    end

    def self._load(args)
      nil
    end

  end
end
