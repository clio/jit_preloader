class ActiveRecord::Associations::Preloader::SingularAssociation
  private
  # A monkey patch to ActiveRecord. The old method looked like the snippet
  # below. Our changes here are that we don't assign the record if the
  # target has already been set, and we attach all of the records to a new
  # jit preloader.
  #
  # def preload(preloader)
  #   associated_records_by_owner(preloader).each do |owner, associated_records|
  #     record = associated_records.first
  #     association = owner.association(reflection.name)
  #     association.target = record
  #   end
  # end

  def preload(preloader)
    return unless (reflection.scope.nil? || reflection.scope.arity == 0) && klass.ancestors.include?(ActiveRecord::Base)
    all_records = []

    associated_records_by_owner(preloader).each do |owner, associated_records|
      record = associated_records.first

      association = owner.association(reflection.name)
      association.target ||= record
      all_records.push(record) if record && (owner.jit_preloader || JitPreloader.globally_enabled?)
    end
    JitPreloader::Preloader.attach(all_records) if all_records.any?
  end
end
