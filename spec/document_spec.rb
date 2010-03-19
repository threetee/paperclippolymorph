require File.dirname(__FILE__) + '/spec_helper'

describe Document do
  before(:each) do
    @document = Document.new
    @uploaded_image = uploaded_jpeg("#{RAILS_ROOT}/vendor/plugins/paperclip_polymorph/spec/fixtures/documents/rails.png")
    @uploaded_text = uploaded_txt("#{RAILS_ROOT}/vendor/plugins/paperclip_polymorph/spec/fixtures/documents/sample.txt")
  end
  it "should save the uploaded attachment data" do
    @document = create_document(:data => @uploaded_image)
    @document.browser_safe?.should be_true
    @document.icon.should == "image-jpeg.png"
    @document.name.should == @document.data_file_name
    
    @document = create_document(:data => @uploaded_text)
    @document.browser_safe?.should be_false
    @document.icon.should == "text-plain.png"
  end
  
  it "should allow you to replace one to many styles of an associated file" do
  
  end
  
  it 'should create and destroy attachings' do
    lambda do
      @document = create_document(:data => @uploaded_image)
      @essay = MockEssay.create(:title => 'foo')
      @essay.documents.attach(@document.id)
    end.should change(Attaching, :count).by(1)
    
    lambda do
      @document.detach(@essay)
    end.should change(Attaching, :count).by(-1)
  end
  
  it "should raise exception if an invalid record is called" do
    @document = create_document(:data => @uploaded_image)
    lambda do
      @document.detach(@document)
    end.should raise_error(ActiveRecord::RecordNotFound)
  end
end
