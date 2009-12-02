require 'translatable_attributes'
ActiveRecord::Base.send(:include, TranslatableAttributes::ActiveRecordExtensions)
