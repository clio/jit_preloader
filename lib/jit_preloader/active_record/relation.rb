# frozen_string_literal: true

module JitPreloader
  module ActiveRecordRelation
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

    def calculate(*args)
      if respond_to?(:proxy_association) && proxy_association.owner && proxy_association.owner.jit_n_plus_one_tracking
        ActiveSupport::Notifications.publish('n_plus_one_query',
                                             source: proxy_association.owner,
                                             association: "#{proxy_association.reflection.name}.#{args.first}")
      end

      super(*args)
    end

    def exec_queries
      super.tap do |records|
        if limit_value != 1
          records.each { |record| record.jit_n_plus_one_tracking = true }
          if jit_preload? || JitPreloader.globally_enabled?
            JitPreloader::Preloader.attach(records)
          end
        end
      end
    end
  end
end

ActiveRecord::Relation.prepend(JitPreloader::ActiveRecordRelation)
