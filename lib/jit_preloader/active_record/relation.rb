class ActiveRecord::Relation

  alias_method :exec_queries_eager, :exec_queries
  def exec_queries
    exec_queries_eager.tap do |records|
      if limit_value != 1
        records.each{ |record| record.jit_n_plus_one_tracking = true }
        if jit_preload? || JitPreloader.globally_enabled?
          JitPreloader::Preloader.attach(records) 
        end
      end
    end
  end
end
