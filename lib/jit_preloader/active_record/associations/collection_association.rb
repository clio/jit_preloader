class ActiveRecord::Associations::CollectionAssociation

  def load_target_with_jit
    if !loaded? && owner.persisted? && owner.jit_preloader
      owner.jit_preloader.jit_preload(reflection.name)
      jit_loaded = true
    end

    was_loaded = loaded?

    load_target_without_jit.tap do |records|
      JitPreloader::Preloader.attach(records) if records.any? && !jit_loaded && JitPreloader.globally_enabled?

      records.each{ |record| record.jit_n_plus_one_tracking = true } if jit_loaded || !was_loaded
      if !was_loaded && loaded? && owner.persisted? && owner.jit_n_plus_one_tracking
        ActiveSupport::Notifications.publish("n_plus_one_query", 
                                             source: owner, association: reflection.name)
      end
    end
  end
  alias_method_chain :load_target, :jit

end
