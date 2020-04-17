module JitPreloader
  module PreloaderAssociation

    # Monkey patching ActiveRecord to use JitPreload
    # The following methods run, associate_records_to_owner, and build_scope
    # have been modified from their original functionality.

    # In <= 5.2, ActiveRecord was passing a parameter to the run method,
    # in AR 6.0 the function signature no longer has a parameter. This allows this
    # method to be called the same in both ActiveRecord versions
    def run(_=nil)
      all_records = []

      owners.each do |owner|
        owned_records = records_by_owner[owner] || []
        all_records.concat(Array(owned_records)) if owner.jit_preloader || JitPreloader.globally_enabled?
        associate_records_to_owner(owner, owned_records)
      end

      JitPreloader::Preloader.attach(all_records) if all_records.any?
      self
    end

    def associate_records_to_owner(owner, records)
      association = owner.association(reflection.name)
      association.loaded!

      if reflection.collection?
        # It is possible that some of the records are loaded already.
        # We don't want to duplicate them, but we also want to preserve
        # the original copy so that we don't blow away in-memory changes.
        new_records = association.target.any? ? records - association.target : records
        association.target.concat(new_records)
      else
        association.target ||= records.first unless records.empty?
      end
    end

    def build_scope
      super.tap do |scope|
        scope.jit_preload! if owners.any?(&:jit_preloader) || JitPreloader.globally_enabled?
      end
    end

    # The rest of the methods were copied from ActiveRecord 6.0 to make JitPreloader
    # backwards compatible with Rails versions greater than 4.2 without having to do any
    # funky version logic in this file.

    def initialize(klass, owners, reflection, preload_scope)
      @klass         = klass
      @owners        = owners
      @reflection    = reflection
      @preload_scope = preload_scope
      @model         = owners.first && owners.first.class
    end

    def records_by_owner
      load_records unless defined?(@records_by_owner)

      @records_by_owner
    end

    def preloaded_records
      load_records unless defined?(@preloaded_records)

      @preloaded_records
    end

    private

    attr_reader :owners, :reflection, :preload_scope, :model, :klass

    def load_records
      # owners can be duplicated when a relation has a collection association join
      # #compare_by_identity makes such owners different hash keys
      @records_by_owner = {}.compare_by_identity
      raw_records = owner_keys.empty? ? [] : records_for(owner_keys)

      @preloaded_records = raw_records.select do |record|
        assignments = false

        owners_by_key[convert_key(record[association_key_name])].each do |owner|
          entries = (@records_by_owner[owner] ||= [])

          if reflection.collection? || entries.empty?
            entries << record
            assignments = true
          end
        end

        assignments
      end
    end

    # The name of the key on the associated records
    def association_key_name
      reflection.join_primary_key(klass)
    end

    # The name of the key on the model which declares the association
    def owner_key_name
      reflection.join_foreign_key
    end

    def owner_keys
      @owner_keys ||= owners_by_key.keys
    end

    def owners_by_key
      @owners_by_key ||= owners.each_with_object({}) do |owner, result|
        key = convert_key(owner[owner_key_name])
        (result[key] ||= []) << owner if key
      end
    end

    def key_conversion_required?
      unless defined?(@key_conversion_required)
        @key_conversion_required = (association_key_type != owner_key_type)
      end

      @key_conversion_required
    end

    def convert_key(key)
      if key_conversion_required?
        key.to_s
      else
        key
      end
    end

    def association_key_type
      @klass.type_for_attribute(association_key_name).type
    end

    def owner_key_type
      @model.type_for_attribute(owner_key_name).type
    end

    def records_for(ids)
      scope.where(association_key_name => ids).load do |record|
        # Processing only the first owner
        # because the record is modified but not an owner
        owner = owners_by_key[convert_key(record[association_key_name])].first
        association = owner.association(reflection.name)
        association.set_inverse_instance(record)
      end
    end

    def scope
      @scope ||= build_scope
    end

    def reflection_scope
      @reflection_scope ||= reflection.scope ? reflection.scope_for(klass.unscoped) : klass.unscoped
    end
  end
end

ActiveRecord::Associations::Preloader::Association.prepend(JitPreloader::PreloaderAssociation)
