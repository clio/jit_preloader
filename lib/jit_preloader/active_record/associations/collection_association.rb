class ActiveRecord::Associations::CollectionAssociation

  alias_method :load_target_eager, :load_target
  def load_target
    if !loaded? && owner.jit_preloader
      owner.jit_preloader.jit_preload(reflection.name)
    end
    was_loaded = loaded?
    load_target_eager.tap do |records|
      JitPreloader::Preloader.attach(records) if !was_loaded && records.any? && (owner.jit_preloader || JitPreloader::Preloader.globally_enabled?)
    end
  end
end
