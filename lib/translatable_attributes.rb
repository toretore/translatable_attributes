module TranslatableAttributes

  DEFAULT_TABLE_NAME = "attribute_translations"
  DEFAULT_POLYMORPHIC_INTERFACE = "translatable"


  class << self

    attr_accessor :locale, :table_name, :class_name, :polymorphic_interface

    def locale
      @locale || I18n.locale
    end


    def table_name
      @table_name || DEFAULT_TABLE_NAME
    end

    def class_name
      @class_name || table_name.classify
    end

    def polymorphic_interface
      @polymorphic_interface || DEFAULT_POLYMORPHIC_INTERFACE
    end

  end


  module ActiveRecordExtensions

    def self.included(klass)
      klass.extend(ClassMethods)
    end

    module ClassMethods


      def translatable_attributes
        @translatable_attributes ||= []
      end


      def translates_attributes(*columns)
        #This is a little hacky, but it'll do
        unless reflect_on_association(:attribute_translations)
          has_many :attribute_translations,
            :as => TranslatableAttributes.polymorphic_interface,
            :class_name => TranslatableAttributes.class_name,
            :extend => AssociationExtensions,
            :autosave => true
        end
        send(:include, InstanceMethods) unless ancestors.include?(InstanceMethods)

        columns.map(&:to_s).each do |attribute|
          translatable_attributes << attribute unless translatable_attributes.include?(attribute)
        end
      end


    end


    module AssociationExtensions

      def for_attribute(attribute, locale)
        attribute, locale = "#{attribute}", "#{locale}"
        detect{|t| t.attribute == attribute && t.locale == locale } || build(:attribute => attribute, :locale => locale)
      end

      def text_for_attribute(attribute, locale)
        for_attribute(attribute, locale).text
      end

    end


    #Methods on all AR objects
    module InstanceMethods

      def locale
        @locale || TranslatableAttributes.locale
      end

      def locale=(l)
        @locale = l
      end

      def read_translatable_attribute(attribute, l=locale)
        attribute_translations.text_for_attribute(attribute, l)
      end

      def write_translatable_attribute(attribute, text, l=locale)
        attribute_translations.for_attribute(attribute, l).text = text
      end

      #Can +name+ be interpreted as a setter or getter for one of the translatable attributes?
      #Returns false if not and an array of extracted values if true
      #Ex: "foo" => ["foo"], "foo=" => ["foo", "="], "bar_en" => ["bar_en"], "bar_en=" => ["bar", "en", "="]
      #    "foo_bar_baz" => false, "foo_bar_baz=" => false, "untranslatableattribute_*" => false
      def respond_to_translatable_attribute?(name)
        name.to_s =~ /^(#{self.class.translatable_attributes.join('|')})(_[a-z]+)?(=)?$/ && [$1, $2 ? $2[1..-1] : nil, $3].compact
      end

      def method_missing(name, *a, &b)
        if args = respond_to_translatable_attribute?(name)
          if args.last == "=" #Setter
            args.pop #Remove the =
            args.insert(1, a.first) #Insert the text value as the second element
            write_translatable_attribute(*args)
          else #Getter
            read_translatable_attribute(*args)
          end
        else
          super
        end
      end

      def respond_to?(name, *a, &b)
        respond_to_translatable_attribute?(name) ? true : super
      end

    end

  end


  #Methods on the default AttributeTranslation model
  module ModelExtensions

    #Nothing

  end


end
