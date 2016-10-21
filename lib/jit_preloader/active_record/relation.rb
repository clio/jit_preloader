class ActiveRecord::Relation

  alias_method :exec_queries_eager, :exec_queries
  def exec_queries
    exec_queries_eager.tap do |records|
      if jit_preload? || JitPreloader.globally_enabled?
        JitPreloader::Preloader.attach(records) unless limit_value == 1
      end
    end
  end
end
