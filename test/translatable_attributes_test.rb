require 'test_helper'

ActiveRecord::Schema.define do
  create_table :products, :force => true do |t|
    t.integer :price
  end
  create_table :attribute_translations, :force => true do |t|
    t.belongs_to :translatable, :polymorphic => true
    t.string :attribute, :locale, :text
  end
end

I18n.locale = "humbaba"

class Product < ActiveRecord::Base

  #This is done in init.rb, but it's not loaded in tests
  include TranslatableAttributes::ActiveRecordExtensions

  translates_attributes :name, :description

end

class TranslatableAttributesTest < ActiveSupport::TestCase

  setup :setup#Make sure the scope is right

  def setup
    @tc = TranslatableAttributes
  end

  test "should fall back to i18n locale" do
    @tc.locale = nil
    assert_equal @tc.locale, I18n.locale
  end

  test "should be able to use own locale" do
    @tc.locale = "test"
    assert_equal "test", @tc.locale
  end

end

class ActiveRecordExtensionsTest < ActiveSupport::TestCase

  test "should have an attribute_translations association" do
    assert Product.new.attribute_translations
  end

  test "should keep track of translatable attributes" do
    klass = Class.new
    klass.expects(:reflect_on_association).at_least_once.returns(true)
    klass.send(:include, TranslatableAttributes::ActiveRecordExtensions)
    assert_equal [], klass.translatable_attributes
    klass.translates_attributes :foo, :bar
    assert_equal %w(foo bar), klass.translatable_attributes
    klass.translates_attributes :bar, :baz
    assert_equal %w(foo bar baz), klass.translatable_attributes
  end

  test "should know what methods it can respond to" do
    product = Product.new
    assert_equal %w(name), product.respond_to_translatable_attribute?(:name)
    assert_equal %w(name =), product.respond_to_translatable_attribute?(:name=)
    assert_equal %w(name en), product.respond_to_translatable_attribute?(:name_en)
    assert_equal %w(name en =), product.respond_to_translatable_attribute?(:name_en=)
    assert !product.respond_to_translatable_attribute?(:name_foo_bar)
    assert !product.respond_to_translatable_attribute?(:name_foo_bar=)
    assert_equal %w(description), product.respond_to_translatable_attribute?(:description)
    assert_equal %w(description =), product.respond_to_translatable_attribute?(:description=)
    assert_equal %w(description de), product.respond_to_translatable_attribute?(:description_de)
    assert_equal %w(description de =), product.respond_to_translatable_attribute?(:description_de=)
    assert !product.respond_to_translatable_attribute?(:humbaba)
    assert !product.respond_to_translatable_attribute?(:humbaba=)
  end

  test "should respond correctly to respond_to?" do
    product = Product.new
    assert product.respond_to?(:name)
    assert product.respond_to?(:name_en)
    assert !product.respond_to?(:name_en_de)
  end

  test "should catch calls to translatable attribute methods" do
    product = Product.new
    product.expects(:read_translatable_attribute).with("name").returns("foo")
    assert_equal "foo", product.name
    product.expects(:read_translatable_attribute).with("name", "en").returns("foo")
    assert_equal "foo", product.name_en
  end

  test "should not intercept other messages" do
    product = Product.new
    assert_raise(NoMethodError){product.humbaba}
    assert_raise(NoMethodError){product.name_foo_bar}
    assert_raise(NoMethodError){product.name_foo_bar = "humbaba"}
  end

  test "should read translatable attribute on method interception" do
    product = Product.new
    product.expects(:read_translatable_attribute).with("name", "en").returns("humbaba")
    assert_equal "humbaba", product.name_en
    product.expects(:read_translatable_attribute).with("name").returns("humbaba")
    assert_equal "humbaba", product.name
  end

  test "should write translatable attribute on method interception" do
    product = Product.new
    product.expects(:write_translatable_attribute).with("name", "humbaba", "en")
    product.name_en = "humbaba"
    product.expects(:write_translatable_attribute).with("name", "humbaba")
    product.name = "humbaba"
  end

  test "should set the text attribute on the appropriate AttributeTranslation" do
    product = Product.new
    t = product.attribute_translations.for_attribute("name", "en")
    product.name_en = "humbaba"
    assert_equal "humbaba", t.text
    t = product.attribute_translations.for_attribute("name", "de")
    product.name_de = "enkidu"
    assert_equal "enkidu", product.attribute_translations.text_for_attribute("name", "de")
    assert_equal "enkidu", product.name_de
    assert_equal "enkidu", product.read_translatable_attribute("name", "de")
  end

  test "should have a default locale" do
    product = Product.new(:price => 0)
    product.locale = "nl"
    product.name = "gebruiksaanwijzing"
    product.name_no = "bruksanvisning"
    product.name_hr = "uputa za upotrebu"
    assert_equal "gebruiksaanwijzing", product.name
    assert_equal "gebruiksaanwijzing", product.name_nl
    assert_equal "gebruiksaanwijzing", product.read_translatable_attribute("name", "nl")
    assert_equal "bruksanvisning", product.name_no
    assert_equal "uputa za upotrebu", product.name_hr
    assert_nil product.name_en
    product.locale = "en"
    product.description = "You're a man, you don't need this"
    assert_nil product.name
    assert_equal "You're a man, you don't need this", product.description
    product.locale = "no"
    assert_equal "bruksanvisning", product.name
    assert_nil product.description
    assert_equal "You're a man, you don't need this", product.description_en
  end

  test "default locale should have a default locale" do
    product = Product.new
    assert_equal TranslatableAttributes.locale, product.locale
    TranslatableAttributes.locale = "no"
    product.name = "skinnvest"
    product.description = "bli itj fæst utn"
    product.name_en = "leather vest"
    assert_equal "skinnvest", product.name
    assert_equal "skinnvest", product.name_no
    assert_equal "leather vest", product.name_en
  end

  test "should save the translation records automatically" do
    product = Product.new
    product.name_en = "Donkey"
    product.name_nl = "Ezel"
    assert product.save
    assert !product.attribute_translations.any?{|at| at.new_record? }

    assert_equal "Donkey", Product.find(product.id).name_en
    assert_equal "Ezel", Product.find(product.id).name_nl
  end

  test "should not create duplicate translation objects" do
    product = Product.create!
    product.name_en = "Donkey"
    product.name_nl = "Ezel"
    assert product.save

    product = Product.find(product.id)
    product.name_en = "Horse"
    product.name_nl = "Heeezt"
    assert product.save

    product = Product.find(product.id)
    assert_equal "Horse", product.name_en
    assert_equal "Heeezt", product.name_nl
    assert_equal "Horse", product.attribute_translations.for_attribute(:name, :en).text
    assert_equal "Heeezt", product.attribute_translations.for_attribute(:name, :nl).text
    assert_equal 2, product.attribute_translations.size
  end

  test "should work with update_attribute(s)" do
    product = Product.create!
    assert product.update_attributes(:name_en => "Table", :name_sv => "Skörvsta")
    assert_equal "Table", Product.find(product.id).name_en
    assert_equal "Skörvsta", Product.find(product.id).name_sv
    assert Product.find(product.id).update_attributes(:name_en => "Chair", :name_sv => "Östersund")
    assert_equal "Chair", Product.find(product.id).name_en
    assert_equal "Östersund", Product.find(product.id).name_sv
    assert_equal 2, Product.find(product.id).attribute_translations.size
    assert Product.find(product.id).update_attribute(:name_en, "Sitting appliance")
    assert_equal "Sitting appliance", Product.find(product.id).name_en
    
    product = Product.find(product.id)
    product.expects(:write_translatable_attribute).with("name", "humbaba", "en")
    product.expects(:write_translatable_attribute).with("name", "enkidu", "no")
    assert product.update_attributes(:name_en => "humbaba", :name_no => "enkidu")
  end

end


class AssociationExtensionsTest < ActiveSupport::TestCase

  setup do
    Product.destroy_all
    AttributeTranslation.destroy_all
  end

  test "for_attribute should return the first AttributeTranslation for the product matching the supplied attribute and locale" do
    product = Product.create!(:price => 5)
    translation = product.attribute_translations.create!(:locale => "humbaba", :attribute => "name", :text => "mighty moussaka")
    assert_equal translation, product.attribute_translations.for_attribute("name", "humbaba")
  end

  test "for_attribute should return a new AttributeTranslation if none is found" do
    product = Product.create!(:price => 5)
    translation = product.attribute_translations.for_attribute("name", "en")
    assert translation.is_a?(AttributeTranslation)
    assert translation.new_record?
  end

  test "text_for_attribute should return the text content for the AttributeTranslation amtching the attribute and locale" do
    product = Product.create!(:price => 5)
    translation = product.attribute_translations.create!(:locale => "humbaba", :attribute => "name", :text => "mighty moussaka")
    assert_equal "mighty moussaka", product.attribute_translations.text_for_attribute("name", "humbaba")
  end

  test "text_for_attribute should return nil if no translation is found for the attribute and locale" do
    product = Product.create!(:price => 5)
    assert_nil product.attribute_translations.text_for_attribute("name", "humbaba")
  end

end
