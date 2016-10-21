class ActiveRecord::Associations::SingularAssociation

  def load_target_with_jit
    if !loaded? && owner.persisted? && owner.jit_preloader
      owner.jit_preloader.jit_preload(reflection.name)
    end
    was_loaded = loaded?    

    load_target_without_jit.tap do |record|
      if !was_loaded && owner.persisted? && owner.jit_n_plus_one_tracking && loaded?
        ActiveSupport::Notifications.publish("n_plus_one_query", 
                                             source: owner, association: reflection.name)
      end
    end
  end
  alias_method_chain :load_target, :jit

end
