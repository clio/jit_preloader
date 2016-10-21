class ActiveRecord::Relation

  def calculate_with_jit(*args)
    if respond_to?(:proxy_association) && proxy_association.owner && proxy_association.owner.jit_n_plus_one_tracking
      ActiveSupport::Notifications.publish("n_plus_one_query", 
                                           source: proxy_association.owner, 
                                           association: "#{proxy_association.reflection.name}.#{args.first}")
    end
    calculate_without_jit(*args)
  end

  alias_method_chain :calculate, :jit

  def exec_queries_with_jit
    exec_queries_without_jit.tap do |records|
      if limit_value != 1
        records.each{ |record| record.jit_n_plus_one_tracking = true }
        if jit_preload? || JitPreloader.globally_enabled?
          JitPreloader::Preloader.attach(records) 
        end
      end
    end
  end
  alias_method_chain :exec_queries, :jit

end
