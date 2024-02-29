module JitPreloader
  module PreloaderBranch
    """
    ActiveRecord version >= 7.x.x introduced an improvement for preloading associations in batches:
    https://github.com/rails/rails/blob/main/activerecord/lib/active_record/associations/preloader.rb#L121

    Our existing monkey-patches will ignore associations whose classes are not descendants of
    ActiveRecord::Base (example: https://github.com/clio/jit_preloader/blob/master/lib/jit_preloader/active_record/associations/preloader/ar6_association.rb#L19).
    But this change breaks that behaviour because now Batch is calling `klass.base_class` (a method defined by ActiveRecord::Base)
    before we have a chance to filter out the non-AR classes.
    This patch for AR 7.x makes the Branch class ignore any association loaders that aren't for ActiveRecord::Base subclasses.
    """

    def loaders
      @loaders = super.find_all do |loader|
        loader.klass < ::ActiveRecord::Base
      end
    end
  end
end

ActiveRecord::Associations::Preloader::Branch.prepend(JitPreloader::PreloaderBranch)
