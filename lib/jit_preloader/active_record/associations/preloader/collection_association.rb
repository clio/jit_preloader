# frozen_string_literal: true

module ActiveRecord
  module Associations
    module Preloader
      class CollectionAssociation
        private
        # A monkey patch to ActiveRecord. The old method looked like the snippet
        # below. Our changes here are that we remove records that are already
        # part of the target, then attach all of the records to a new jit preloader.
        #
        # def preload(preloader)
        #   associated_records_by_owner(preloader).each do |owner, records|
        #     association = owner.association(reflection.name)
        #     association.loaded!
        #     association.target.concat(records)
        #     records.each { |record| association.set_inverse_instance(record) }
        #   end
        # end

        def preload(preloader)
          return unless (reflection.scope.nil? || reflection.scope.arity == 0) && klass.ancestors.include?(ActiveRecord::Base)
          all_records = []
          associated_records_by_owner(preloader).each do |owner, records|
            association = owner.association(reflection.name)
            association.loaded!
            # It is possible that some of the records are loaded already.
            # We don't want to duplicate them, but we also want to preserve
            # the original copy so that we don't blow away in-memory changes.
            new_records = association.target.any? ? records - association.target : records

            association.target.concat(new_records)
            new_records.each { |record| association.set_inverse_instance(record) }

            all_records.concat(records) if owner.jit_preloader || JitPreloader.globally_enabled?
          end
          JitPreloader::Preloader.attach(all_records) if all_records.any?
        end
      end
    end
  end
end
