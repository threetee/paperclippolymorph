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
          has_many :documents, :through => :attachings do
            def attach(document_id)
              document_id = extract_id(document_id)
              document = Document.find(document_id)
              @owner.documents << document
              @owner.documents(true)
            end
            
            def detach(document_id, delete_if_no_attachings = false)
              document_id = extract_id(document_id)
              attaching = @owner.attachings.find(:first, :conditions => ['document_id = ?', document_id])
              attachable = attaching.attachable
              raise ActiveRecord::RecordNotFound unless attaching
              result = attaching.destroy
              
              document = Document.find(document_id)
              if document.attachings.empty? && delete_if_no_attachings# delete if no longer attached to anything
                override_default_styles, normalised_styles = attachable.override_default_styles?(document.name)
                document.data.instance_variable_set("@styles", normalised_styles) if override_default_styles
                document.data.send(:queue_existing_for_delete)
                document.data.send(:flush_deletes)
                document.save # needed to permanently remove file name and urls 
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
          Document.transaction do
            if data.is_a?(Array)
              data.each do |data_item|
                create_and_save_document(data_item) unless data_item.nil? || data_item.blank?
              end
            else
              create_and_save_document(data)
            end
          end unless data.nil? || data.blank?
        end
        
        def create_and_save_document(data_item)
          the_document = Document.find_or_initialize_by_data_file_name(data_item.original_filename)
          override_default_styles, normalised_styles = override_default_styles?(data_item.original_filename)
          the_document.data.instance_variable_set("@styles", normalised_styles) if override_default_styles
          the_document.data = data_item
          if the_document.save
  
            # This association may be saved more than once within the same request / response 
            # cycle, which leads to needless DB calls. Now we'll clear out the data attribute
            # once the record is successfully saved any subsequent calls will be ignored.
            data_item = nil
            Attaching.find_or_create_by_document_id_and_attachable_type_and_attachable_id(:document_id => the_document.id, :attachable_type => self.class.to_s, :attachable_id => self.id)
            documents(true) # implicit reloading
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