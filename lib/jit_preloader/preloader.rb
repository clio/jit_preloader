module JitPreloader
  class Preloader < ActiveRecord::Associations::Preloader

    attr_accessor :records

    def self.attach(records)
      new.tap do |loader|
        loader.records = records.dup
        records.each do |record|
          record.jit_preloader = loader
        end
      end
    end

    def preload(name, records, associations, preload_scope = nil)
      wrapped_records       = Array.wrap(records).compact.uniq
      wrapped_associations  = Array.wrap(associations)

      return if records.empty?

      previous_association_values = Hash.new{|h,k| h[k] = {} }
      wrapped_associations.flat_map do |association_name|
        wrapped_records.each do |record|
          association = record.association(association_name)
          if association.loaded?
            previous_association_values[association_name][record] = association.target
            association.reset
          end
        end
      end

      super(records, associations, preload_scope)

      wrapped_associations.flat_map do |association_name|
        wrapped_records.each do |record|
          record.jit_preload_scoped_relations ||= {}
          association = record.association(association_name)
          record.jit_preload_scoped_relations[name] = association.target
          association.reset
          if previous_association_values[association_name].key?(record)
            association.target = previous_association_values[association_name][record]
          end
        end
      end
    end

    def jit_preload(association)
      # It is possible that the records array has multiple different classes (think single table inheritance).
      # Thus, it is possible that some of the records don't have an association.
      records_with_association = records.reject{|r| r.class.reflect_on_association(association).nil? }
      preload records_with_association, association
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
