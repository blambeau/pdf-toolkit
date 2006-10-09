require 'test/unit'
require 'pdf/toolkit'
require 'tempfile'
# require 'active_record/validations'
# require 'active_record/callbacks'
# require 'active_record/timestamp'

class PDF::Toolkit
end

class MyPDF < PDF::Toolkit
  loot_active_record
  self.record_timestamps = true
  validates_presence_of :author
  before_save do |object|
    object.producer = "PDF::Toolkit Test"
  end
  self.default_permissions = %w(Printing ModifyAnnotations)
end

class PDFToolkitActiveRecordTest < Test::Unit::TestCase
  DATA = File.open(File.join(File.dirname(__FILE__),"pdfs","blank.pdf")).read

  def setup
    @tempfiles = []
    @pdf = new_pdf
    @pdftk = MyPDF.new(@pdf)
  end

  def teardown
    (@tempfiles || []).each do |tempfile|
      tempfile.close
      tempfile.unlink
    end
    @tempfiles = nil
  end

  def new_pdf
    tempfile = Tempfile.open("pdftktest")
    tempfile.write(DATA)
    tempfile.close
    @tempfiles << tempfile if @tempfiles
    return tempfile
  end

  # def new_pdftool
    # PDF::Toolkit.open(new_pdf.path)
  # end

  def new_tempfile
    tempfile = Tempfile.open("pdftktest")
    tempfile.close
    @tempfiles << tempfile if @tempfiles
    return tempfile.path
  end

  def test_invalid
    PDF::Toolkit.loot_active_record # Ensure a double loot is harmless
    assert_nil   @pdftk.author
    assert_equal false, @pdftk.valid?
  end

  def test_save
    @pdftk.author = "John Smith"
    assert_equal true, @pdftk.valid?
    assert @pdftk.save
  end

  def test_callback
    @pdftk.author = "Andy Hunt"
    assert @pdftk.save
    @pdftk.reload
    assert_match /PDF::Toolkit/, @pdftk.producer
  end

  def test_timestamp
    before = Time.now
    @pdftk.author = "Dave Thomas"
    assert @pdftk.save
    @pdftk.reload
    after = Time.now
    assert @pdftk.updated_at >= before-1 && @pdftk.updated_at <= after,
      "Timestamp (#{@pdftk.updated_at}) out of range"
  end

end
