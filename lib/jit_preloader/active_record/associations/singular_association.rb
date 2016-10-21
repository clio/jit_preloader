class ActiveRecord::Associations::SingularAssociation

  def load_target_with_jit
    if !loaded? && owner.jit_preloader
      owner.jit_preloader.jit_preload(reflection.name)
    end
    load_target_without_jit
  end
  alias_method_chain :load_target, :jit

end
