module JitPreloader
  module PreloaderAssociation

    # A monkey patch to ActiveRecord. The old method looked like the snippet
    # below. Our changes here are that we remove records that are already
    # part of the target, then attach all of the records to a new jit preloader.
    #
    # def run
    #   records = records_by_owner

    #   owners.each do |owner|
    #     associate_records_to_owner(owner, records[owner] || [])
    #   end if @associate

    #   self
    # end

    def run
      return unless (reflection.scope.nil? || reflection.scope.arity == 0) && klass.ancestors.include?(ActiveRecord::Base)

      super.tap do
        if preloaded_records.any? && preloaded_records.none?(&:jit_preloader)
          JitPreloader::Preloader.attach(preloaded_records) if owners.any?(&:jit_preloader) || JitPreloader.globally_enabled?
        end
      end
    end

    # Original method:
    # def associate_records_to_owner(owner, records)
    #   return if loaded?(owner)
    #
    #   association = owner.association(reflection.name)
    #
    #   if reflection.collection?
    #     association.target = records
    #   else
    #     association.target = records.first
    #   end
    # end
    def associate_records_to_owner(owner, records)
      return if loaded?(owner)

      association = owner.association(reflection.name)

      if reflection.collection?
        new_records = association.target.any? ? records - association.target : records
        association.target.concat(new_records)
        association.loaded!
      else
        association.target = records.first
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
