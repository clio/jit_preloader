class ActiveRecord::Associations::Preloader::SingularAssociation
  private
  # Monkey patch
  # Old method looked like below
  # Changes here is simply that we don't assign the record if the target
  # has already been set
  # def preload(preloader)
  #   associated_records_by_owner(preloader).each do |owner, associated_records|
  #     record = associated_records.first
  #     association = owner.association(reflection.name)
  #     association.target = record
  #   end
  # end
  def preload(preloader)
    return unless reflection.scope.nil? || reflection.scope.arity == 0
    associated_records_by_owner(preloader).each do |owner, associated_records|
      record = associated_records.first

      association = owner.association(reflection.name)
      association.target ||= record
    end
  end
end
