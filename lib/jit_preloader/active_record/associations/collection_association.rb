# frozen_string_literal: true

module JitPreloader
  module ActiveRecordAssociationsCollectionAssociation
    def load_target
      was_loaded = loaded?

      if !loaded? && owner.persisted? && owner.jit_preloader && (reflection.scope.nil? || reflection.scope.arity == 0)
        owner.jit_preloader.jit_preload(reflection.name)
      end

      jit_loaded = loaded?

      super.tap do |records|
        # We should not act on non-persisted objects, or ones that are already loaded.
        if owner.persisted? && !was_loaded
          # If we went through a JIT preload, then we will have attached another JitPreloader elsewhere.
          JitPreloader::Preloader.attach(records) if records.any? && !jit_loaded && JitPreloader.globally_enabled?

          # If the records were not pre_loaded
          records.each { |record| record.jit_n_plus_one_tracking = true }

          if !jit_loaded && owner.jit_n_plus_one_tracking
            ActiveSupport::Notifications.publish('n_plus_one_query',
                                                 source: owner, association: reflection.name)
          end
        end
      end
    end
  end
end

ActiveRecord::Associations::CollectionAssociation.prepend(JitPreloader::ActiveRecordAssociationsCollectionAssociation)
