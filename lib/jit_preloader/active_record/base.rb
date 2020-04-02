module JitPreloadExtension
  attr_accessor :jit_preloader
  attr_accessor :jit_n_plus_one_tracking
  attr_accessor :jit_preload_aggregates
  attr_accessor :jit_preload_scoped_relations

  def reload(*args)
    clear_jit_preloader!
    super
  end

  def clear_jit_preloader!
    self.jit_preload_aggregates = {}
    self.jit_preload_scoped_relations = {}
    if jit_preloader
      jit_preloader.records.delete(self)
      self.jit_preloader = nil
    end
  end

  def preload_scoped_relation(name:, base_association:, preload_scope: nil)
    return jit_preload_scoped_relations[name] if jit_preload_scoped_relations&.key?(name)

    records = jit_preloader&.records || [self]
    previous_association_values = {}

    records.each do |record|
      association = record.association(base_association)
      if association.loaded?
        previous_association_values[record] = association.target
        association.reset
      end
    end

    ActiveRecord::Associations::Preloader.new.preload(
      records,
      base_association,
      preload_scope
    )

    records.each do |record|
      record.jit_preload_scoped_relations ||= {}
      association = record.association(base_association)
      record.jit_preload_scoped_relations[name] = association.target
      association.reset
      if previous_association_values.key?(record)
        association.target = previous_association_values[record]
      end
    end

    jit_preload_scoped_relations[name]
  end

  def self.prepended(base)
    class << base
      delegate :jit_preload, to: :all

      def has_many_aggregate(assoc, name, aggregate, field, default: 0)
        method_name = "#{assoc}_#{name}"

        define_method(method_name) do |conditions={}|
          self.jit_preload_aggregates ||= {}

          key = "#{method_name}|#{conditions.sort.hash}"
          return jit_preload_aggregates[key] if jit_preload_aggregates.key?(key)
          if jit_preloader
            reflection = association(assoc).reflection
            primary_ids = jit_preloader.records.collect{|r| r[reflection.active_record_primary_key] }
            klass = reflection.klass

            aggregate_association = reflection
            while aggregate_association.through_reflection
              aggregate_association = aggregate_association.through_reflection
            end

            association_scope = klass.all.merge(association(assoc).scope).unscope(where: aggregate_association.foreign_key)
            association_scope = association_scope.instance_exec(&reflection.scope).reorder(nil) if reflection.scope

            # If the query uses an alias for the association, use that instead of the table name
            table_alias_name = association_scope.references_values.first
            table_reference = table_alias_name || aggregate_association.table_name

            conditions[table_reference] = { aggregate_association.foreign_key => primary_ids }

            # If the association is a STI child model, specify its type in the condition so that it
            # doesn't include results from other child models
            parent_is_base_class = aggregate_association.klass.superclass.abstract_class? || aggregate_association.klass.superclass == ActiveRecord::Base
            has_type_column = aggregate_association.klass.column_names.include?(aggregate_association.klass.inheritance_column)
            is_child_sti_model = !parent_is_base_class && has_type_column
            if is_child_sti_model
              conditions[table_reference].merge!({ aggregate_association.klass.inheritance_column => aggregate_association.klass.sti_name })
            end

            if reflection.type.present?
              conditions[reflection.type] = self.class.name
            end
            group_by = "#{table_reference}.#{aggregate_association.foreign_key}"

            preloaded_data = Hash[association_scope
              .where(conditions)
              .group(group_by)
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
end

ActiveRecord::Base.send(:prepend, JitPreloadExtension)
