module JitPreloader
  module PreloaderAssociation

    # A monkey patch to ActiveRecord. The old method looked like the snippet
    # below. Our changes here are that we remove records that are already
    # part of the target, then attach all of the records to a new jit preloader.
    #
    # def run(preloader)
    #   records = load_records do |record|
    #     owner = owners_by_key[convert_key(record[association_key_name])]
    #     association = owner.association(reflection.name)
    #     association.set_inverse_instance(record)
    #   end

    #   owners.each do |owner|
    #     associate_records_to_owner(owner, records[convert_key(owner[owner_key_name])] || [])
    #   end
    # end

    def run(preloader)
      return unless (reflection.scope.nil? || reflection.scope.arity == 0) && klass.ancestors.include?(ActiveRecord::Base)

      super.tap do
        if preloaded_records.any? && preloaded_records.none?(&:jit_preloader)
          JitPreloader::Preloader.attach(preloaded_records) if owners.any?(&:jit_preloader) || JitPreloader.globally_enabled?
        end
      end
    end

    # Original method:
    # def associate_records_to_owner(owner, records)
    #   association = owner.association(reflection.name)
    #   association.loaded!
    #   if reflection.collection?
    #     association.target.concat(records)
    #   else
    #     association.target = records.first unless records.empty?
    #   end
    # end
    def associate_records_to_owner(owner, records)
      association = owner.association(reflection.name)
      association.loaded!

      if reflection.collection?
        # It is possible that some of the records are loaded already.
        # We don't want to duplicate them, but we also want to preserve
        # the original copy so that we don't blow away in-memory changes.
        new_records = association.target.any? ? records - association.target : records
        association.target.concat(new_records)
        association.loaded!
      else
        association.target = records.first unless records.empty?
      end
    end


    def build_scope
      super.tap do |scope|
        scope.jit_preload! if owners.any?(&:jit_preloader) || JitPreloader.globally_enabled?
      end
    end
  end
end

ActiveRecord::Associations::Preloader::Association.prepend(JitPreloader::PreloaderAssociation)
ActiveRecord::Associations::Preloader::ThroughAssociation.prepend(JitPreloader::PreloaderAssociation)
