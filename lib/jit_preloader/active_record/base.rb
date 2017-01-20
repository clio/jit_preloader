module JitPreloadExtension

  extend ActiveSupport::Concern

  included do
    attr_accessor :jit_preloader
    attr_accessor :jit_n_plus_one_tracking
    attr_accessor :jit_preload_aggregates
  end

  class_methods do
    delegate :jit_preload, to: :all

    def has_many_aggregate(assoc, name, aggregate, field, default: 0)
      method_name = "#{assoc}_#{name}"

      define_method(method_name) do
        self.jit_preload_aggregates ||= {}

        return jit_preload_aggregates[method_name] if jit_preload_aggregates[method_name]
        if jit_preloader
          reflection = association(assoc).reflection
          primary_ids = jit_preloader.records.collect{|r| r[reflection.active_record_primary_key] }
          klass = reflection.klass

          preloaded_data = Hash[klass
                                 .where(reflection.foreign_key => primary_ids)
                                 .group(reflection.foreign_key)
                                 .send(aggregate, field)
                               ]

          jit_preloader.records.each do |record|
            record.jit_preload_aggregates ||= {}
            record.jit_preload_aggregates[method_name] = preloaded_data[record.id] || default
          end
        else
          self.jit_preload_aggregates[method_name] = send(assoc).send(aggregate, field) || default
        end
        jit_preload_aggregates[method_name]
      end

      def reload(*args)
        self.jit_preload_aggregates = {}
        super
      end

    end
  end
end

ActiveRecord::Base.send(:include, JitPreloadExtension)
