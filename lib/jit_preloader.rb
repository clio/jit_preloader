require 'active_support/concern'
require 'active_support/core_ext/module/delegation'
require 'active_record'

require "jit_preloader/version"
require 'jit_preloader/active_record/base'
require 'jit_preloader/active_record/query_methods'
require 'jit_preloader/active_record/relation'
require 'jit_preloader/active_record/associations/collection_association'
require 'jit_preloader/active_record/associations/singular_association'
require 'jit_preloader/active_record/associations/preloader/collection_association'
require 'jit_preloader/active_record/associations/preloader/singular_association'
require 'jit_preloader/preloader'

module JitPreloader
  # Your code goes here...
end
