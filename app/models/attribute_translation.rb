class AttributeTranslation < ActiveRecord::Base

  belongs_to TranslatableAttributes.polymorphic_interface, :polymorphic => true

  include TranslatableAttributes::ModelExtensions

end
