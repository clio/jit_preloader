class ActiveRecord::Associations::CollectionAssociation

  def load_target_with_jit
    if !loaded? && owner.jit_preloader
      owner.jit_preloader.jit_preload(reflection.name)
    end
    was_loaded = loaded?
    load_target_without_jit.tap do |records|
      JitPreloader::Preloader.attach(records) if !was_loaded && records.any? && (owner.jit_preloader || JitPreloader.globally_enabled?)
    end
  end
  alias_method_chain :load_target, :jit
end
