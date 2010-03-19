require 'acts_as_polymorphic_paperclip'
ActiveRecord::Base.send(:include, LocusFocus::Acts::PolymorphicPaperclip)
require File.dirname(__FILE__) + '/lib/document'
require File.dirname(__FILE__) + '/lib/attaching'