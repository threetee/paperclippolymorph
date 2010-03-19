module LocusFocus
  module Acts #:nodoc: all
    module PolymorphicPaperclip
      def self.included(base)
        base.extend ClassMethods
      end
      
      module ClassMethods
        # Extends the model to afford the ability to associate other records with the receiving record.
        # 
        # This module needs the paperclip plugin to work
        # http://www.thoughtbot.com/projects/paperclip
        def acts_as_polymorphic_paperclip(options = {})
          write_inheritable_attribute(:acts_as_polymorphic_paperclip_options, {
            :counter_cache => options[:counter_cache],
            :styles => options[:styles]
          })
          class_inheritable_reader :acts_as_polymorphic_paperclip_options

          has_many :attachings, :as => :attachable, :dependent => :destroy
          has_many :file_assets, :through => :attachings do
            def attach(file_asset_id)
              file_asset_id = extract_id(file_asset_id)
              file_asset = FileAsset.find(file_asset_id)
              @owner.file_assets << file_asset
              @owner.file_assets(true)
            end
            
            def detach(file_asset_id, delete_if_no_attachings = false)
              file_asset_id = extract_id(file_asset_id)
              attaching = @owner.attachings.find(:first, :conditions => ['file_asset_id = ?', file_asset_id])
              attachable = attaching.attachable
              raise ActiveRecord::RecordNotFound unless attaching
              result = attaching.destroy
              
              file_asset = FileAsset.find(file_asset_id)
              if file_asset.attachings.empty? && delete_if_no_attachings# delete if no longer attached to anything
                override_default_styles, normalised_styles = attachable.override_default_styles?(file_asset.name)
                file_asset.data.instance_variable_set("@styles", normalised_styles) if override_default_styles
                file_asset.data.send(:queue_existing_for_delete)
                file_asset.data.send(:flush_deletes)
                file_asset.save # needed to permanently remove file name and urls 
              end
              result
            end
            
            protected
            def extract_id(obj)
              return obj.id unless obj.class == Fixnum || obj.class == String
              obj.to_i if obj.to_i > 0
            end
          end

          # Virtual attribute for the ActionController::UploadedStringIO
          # which consists of these attributes "content_type", "original_filename" & "original_path"
          # content_type: image/png
          # original_filename: 64x16.png
          # original_path: 64x16.png
          attr_accessor :data
            
          include LocusFocus::Acts::PolymorphicPaperclip::InstanceMethods
        end
      end
      module InstanceMethods
        def after_save
          super
          FileAsset.transaction do
            if data.is_a?(Array)
              data.each do |data_item|
                create_and_save_file_asset(data_item) unless data_item.nil? || data_item.blank?
              end
            else
              create_and_save_file_asset(data)
            end
          end unless data.nil? || data.blank?
        end
        
        def create_and_save_file_asset(data_item)
          the_file_asset = FileAsset.find_or_initialize_by_data_file_name(data_item.original_filename)
          override_default_styles, normalised_styles = override_default_styles?(data_item.original_filename)
          the_file_asset.data.instance_variable_set("@styles", normalised_styles) if override_default_styles
          the_file_asset.data = data_item
          if the_file_asset.save
  
            # This association may be saved more than once within the same request / response 
            # cycle, which leads to needless DB calls. Now we'll clear out the data attribute
            # once the record is successfully saved any subsequent calls will be ignored.
            data_item = nil
            Attaching.find_or_create_by_file_asset_id_and_attachable_type_and_attachable_id(:file_asset_id => the_file_asset.id, :attachable_type => self.class.to_s, :attachable_id => self.id)
            file_assets(true) # implicit reloading
          end
        end
        def override_default_styles?(filename)
          if !acts_as_polymorphic_paperclip_options[:styles].nil?
            normalised_styles = {}
            acts_as_polymorphic_paperclip_options[:styles].each do |name, args|
              dimensions, format = [args, nil].flatten[0..1]
              format = nil if format.blank?
              if filename.match(/\.pdf$/) # remove crop commands if file is a PDF (this fails with Imagemagick)
                args.gsub!(/#/ , "")
                format = "png"
              end
              normalised_styles[name] = { :processors => [:thumbnail], :geometry => dimensions, :format => format }
            end
            return true, normalised_styles
          else
            return false
          end
        end
      end
    end
  end
end