module ActiveRecord::QueryMethods

  def jit_preload(*args)
    spawn.jit_preload!(*args)
  end

  def jit_preload!(*args)
    @jit_preload = true
    self
  end

  def jit_preload?
    @jit_preload
  end

end
