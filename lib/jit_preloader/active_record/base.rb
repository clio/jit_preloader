module JitPreloadExtension

  extend ActiveSupport::Concern

  included do
    attr_accessor :jit_preloader
    attr_accessor :jit_n_plus_one_tracking
    attr_accessor :jit_preload_aggregates

    def reload(*args)
      clear_jit_preloader!
      super
    end

    def clear_jit_preloader!
      self.jit_preload_aggregates = {}
      if jit_preloader
        jit_preloader.records.delete(self)
        self.jit_preloader = nil
      end
    end

  end

  class_methods do
    delegate :jit_preload, to: :all

    def has_many_aggregate(assoc, name, aggregate, field, default: 0)
      method_name = "#{assoc}_#{name}"

      define_method(method_name) do |conditions={}|
        self.jit_preload_aggregates ||= {}

        hashed_conditions = if conditions.kind_of?(String)
                              conditions.hash
                            else
                              conditions.sort.hash
                            end

        key = "#{method_name}|#{hashed_conditions}"
        return jit_preload_aggregates[key] if jit_preload_aggregates.key?(key)
        if jit_preloader
          reflection = association(assoc).reflection
          primary_ids = jit_preloader.records.collect{|r| r[reflection.active_record_primary_key] }
          klass = reflection.klass

          association_scope = klass
          association_scope = association_scope.instance_exec(&reflection.scope).reorder(nil) if reflection.scope

          preloaded_data = Hash[association_scope
                                 .where(conditions)
                                 .where({ "#{reflection.foreign_key}" => primary_ids })
                                 .group(reflection.foreign_key)
                                 .send(aggregate, field)
                               ]

          jit_preloader.records.each do |record|
            record.jit_preload_aggregates ||= {}
            record.jit_preload_aggregates[key] = preloaded_data[record.id] || default
          end
        else
          self.jit_preload_aggregates[key] = send(assoc).where(conditions).send(aggregate, field) || default
        end
        jit_preload_aggregates[key]
      end
    end
  end
end

ActiveRecord::Base.send(:include, JitPreloadExtension)
