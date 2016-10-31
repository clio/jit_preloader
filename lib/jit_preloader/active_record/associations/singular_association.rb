class ActiveRecord::Associations::SingularAssociation

  def load_target_with_jit
    was_loaded = loaded?

    if !loaded? && owner.persisted? && owner.jit_preloader
      owner.jit_preloader.jit_preload(reflection.name)
    end

    jit_loaded = loaded?

    load_target_without_jit.tap do |record|
      if owner.persisted? && !was_loaded
        # If the owner doesn't track N+1 queries, then we don't need to worry about
        # tracking it on the record. This is because you can do something like:
        # model.foo.bar (where foo and bar are singular associations) and that isn't
        # always an N+1 query.
        record.jit_n_plus_one_tracking ||= owner.jit_n_plus_one_tracking if record

        if !jit_loaded && owner.jit_n_plus_one_tracking
          ActiveSupport::Notifications.publish("n_plus_one_query",
                                               source: owner, association: reflection.name)
        end
      end
    end
  end
  alias_method_chain :load_target, :jit

end
