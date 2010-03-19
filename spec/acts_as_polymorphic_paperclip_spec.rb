require File.dirname(__FILE__) + '/spec_helper'

describe MockEssay, :type => :model do
  before(:each) do
    @uploaded_image = uploaded_jpeg("#{RAILS_ROOT}/vendor/plugins/paperclip_polymorph/spec/fixtures/documents/rails.png")
    @uploaded_text = uploaded_txt("#{RAILS_ROOT}/vendor/plugins/paperclip_polymorph/spec/fixtures/documents/sample.txt")
  end
  
  describe 'when being saved' do
    it 'should create a document after being saved' do
      lambda do
        MockEssay.create(:title => 'foo', :data => @uploaded_image)
      end.should change(Document, :count).by(1)
    end
  end
  
  describe 'when being deleted' do
    it 'should not delete any of the attached documents' do
      lambda do
        @essay = MockEssay.create(:title => 'foo', :data => @uploaded_image)
      end.should change(Document, :count).by(1)
      
      lambda do
        @essay.destroy
        lambda do
          MockEssay.find(@essay)
        end.should raise_error(ActiveRecord::RecordNotFound)
      end.should_not change(Document, :count)
    end
  end
    
  describe 'when using a counter cache' do
    it "should increment and decrement the counter after save and destroy" do
      lambda do
        @essay = MockEssay.create(:title => 'foo')
        @document = create_document(:data => @uploaded_image)
      end.should change(Document, :count).by(1)
      lambda do
        lambda do
          @essay.documents.attach(@document)
          @essay.reload
          @document.reload
        end.should change(@essay, :documents_count).by(1)
      end.should change(@document, :attachings_count).by(1)
      lambda do
        lambda do
          @essay.documents.detach(@document)
          @document.reload
          @essay.reload
        end.should change(@essay, :documents_count).by(-1)
      end.should change(@document, :attachings_count).by(-1)
    end
  end
  
  describe 'when being attached to a model with content-type restrictions' do
    it 'should allow only files of the accepted type to be saved and attached'
  end
end
