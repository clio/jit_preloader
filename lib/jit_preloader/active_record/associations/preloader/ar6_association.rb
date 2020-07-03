module JitPreloader
  module PreloaderAssociation

    # A monkey patch to ActiveRecord. The old method looked like the snippet
    # below. Our changes here are that we remove records that are already
    # part of the target, then attach all of the records to a new jit preloader.
    #
    # def run
    #   if !preload_scope || preload_scope.empty_scope?
    #     owners.each do |owner|
    #       associate_records_to_owner(owner, records_by_owner[owner] || [])
    #     end
    #   else
    #     # Custom preload scope is used and
    #     # the association can not be marked as loaded
    #     # Loading into a Hash instead
    #     records_by_owner
    #   end
    #   self
    # end
    def run
      all_records = []

      owners.each do |owner|
        owned_records = records_by_owner[owner]&.uniq || []
        all_records.concat(Array(owned_records)) if owner.jit_preloader || JitPreloader.globally_enabled?
        associate_records_to_owner(owner, owned_records)
      end

      JitPreloader::Preloader.attach(all_records) if all_records.any?

      self
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
      else
        association.target ||= records.first unless records.empty?
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
