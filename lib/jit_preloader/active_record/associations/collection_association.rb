class ActiveRecord::Associations::CollectionAssociation

  def load_target_with_jit
    was_loaded = loaded?

    if !loaded? && owner.persisted? && owner.jit_preloader
      owner.jit_preloader.jit_preload(reflection.name)
    end

    jit_loaded = loaded?

    load_target_without_jit.tap do |records|
      # We should not act on non-persisted objects, or ones that are already loaded.
      if owner.persisted? && !was_loaded
        # If we went through a JIT preload, then we will have attached another JitPreloader elsewhere.
        JitPreloader::Preloader.attach(records) if records.any? && !jit_loaded && JitPreloader.globally_enabled?

        # If the records were not pre_loaded
        records.each{ |record| record.jit_n_plus_one_tracking = true }

        if !jit_loaded && owner.jit_n_plus_one_tracking
          ActiveSupport::Notifications.publish("n_plus_one_query",
                                               source: owner, association: reflection.name)
        end
      end
    end
  end
  alias_method_chain :load_target, :jit

end
