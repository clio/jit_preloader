module JitPreloader
  module ActiveRecordAssociationsSingularAssociation

    def load_target
      was_loaded = loaded?

      if !loaded? && owner.persisted? && owner.jit_preloader && (reflection.scope.nil? || reflection.scope.arity == 0)
        owner.jit_preloader.jit_preload(reflection.name)
      end

      jit_loaded = loaded?

      super.tap do |record|
        if owner.persisted? && !was_loaded
          # If the owner doesn't track N+1 queries, then we don't need to worry about
          # tracking it on the record. This is because you can do something like:
          # model.foo.bar (where foo and bar are singular associations) and that isn't
          # always an N+1 query.
          record.jit_n_plus_one_tracking ||= owner.jit_n_plus_one_tracking if record

          if !jit_loaded && owner.jit_n_plus_one_tracking && !is_polymorphic_association_without_type
            ActiveSupport::Notifications.publish("n_plus_one_query",
                                                 source: owner, association: reflection.name)
          end
        end
      end
    end
    
    private def is_polymorphic_association_without_type
      self.is_a?(ActiveRecord::Associations::BelongsToPolymorphicAssociation) && self.klass.nil?
    end
  end
end

ActiveRecord::Associations::SingularAssociation.prepend(JitPreloader::ActiveRecordAssociationsSingularAssociation)
