class Attaching < ActiveRecord::Base
  belongs_to :file_asset, :counter_cache => true
  belongs_to :attachable, :polymorphic => true
  
  def after_create
    if self.attachable.acts_as_polymorphic_paperclip_options[:counter_cache]
      self.attachable.class.increment_counter(:file_assets_count, self.attachable.id)
    end
  end
  
  def after_destroy
    if self.attachable.acts_as_polymorphic_paperclip_options[:counter_cache]
      self.attachable.class.decrement_counter(:file_assets_count, self.attachable.id)
    end
  end
end