require 'rubygems'
require 'test/unit'
require 'active_support'
require 'active_support/test_case'
require 'active_record'
require 'mocha'
require 'translatable_attributes'
$: << File.join(File.dirname(__FILE__), '..', 'app', 'models')
require 'attribute_translation'

ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database => ":memory:",
  :verbosity => "quiet"
)
