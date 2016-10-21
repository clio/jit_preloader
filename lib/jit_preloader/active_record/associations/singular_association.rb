class ActiveRecord::Associations::SingularAssociation

  alias_method :load_target_eager, :load_target
  def load_target
    if !loaded? && owner.jit_preloader
      owner.jit_preloader.jit_preload(reflection.name)
    end
    load_target_eager
  end

end
