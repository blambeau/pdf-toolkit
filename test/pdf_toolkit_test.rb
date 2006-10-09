require 'test/unit'
require 'pdf/toolkit'
require 'tempfile'

class MyPdfTool < PDF::Toolkit
  def before_save
    self.updated_at = Time.at(1111111111)
  end
  self.default_permissions = %w(Printing ModifyAnnotations)
end

class PDFToolkitTest < Test::Unit::TestCase
  DATA = File.open(File.join(File.dirname(__FILE__),"pdfs","blank.pdf")).read

  def setup
    @tempfiles = []
    @pdf = new_pdf
    @pdftk = PDF::Toolkit.new(@pdf)
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

  def new_pdftool
    PDF::Toolkit.open(new_pdf.path)
  end

  def new_tempfile
    tempfile = Tempfile.open("pdftktest")
    tempfile.close
    @tempfiles << tempfile if @tempfiles
    return tempfile.path
  end

  def assert_reload(object = nil)
    object ||= @pdftk
    assert_nothing_raised { object.save!; object.reload }
  end

  def test_reload
    pdftk2 = PDF::Toolkit.open(@pdftk.path)
    pdftk2.keywords = "Ruby"
    pdftk2.save
    @pdftk.reload
    assert_equal pdftk2.keywords, @pdftk.keywords
  end

  def test_keys
    @pdftk["FakeKey"] = "Test"
    assert_reload
    assert_not_nil @pdftk["FakeKey"]
    assert_equal   @pdftk["FakeKey"], @pdftk[:fake_key]
    assert_nil     @pdftk["fake_key"]
  end

  def test_save_as
    @pdftk.author = "John Doe"
    assert @pdftk.save
    @pdftk.author = "Jane Doe"
    saved = @pdftk.save_as(new_tempfile)
    assert_not_nil saved
    @pdftk.reload
    saved.reload
    assert_equal "John Doe", @pdftk.author
    assert_equal "Jane Doe", saved.author
  end

  def test_date
    time = Time.at(1234567890)
    @pdftk.updated_at = time
    @pdftk.created_at = time.utc
    assert_reload
    assert_equal time, @pdftk.updated_at
    assert_equal time, @pdftk["ModDate"]
    assert_equal time, @pdftk.created_at
  end

  def test_delete
    assert_not_nil @pdftk.creator
    @pdftk.delete(:creator)
    assert_reload
    assert_nil @pdftk.creator
  end

  def test_encrypt
    @pdftk.owner_password = "chunky bacon"
    @pdftk.author = "Why the Lucky Stiff"
    assert @pdftk.save
    pdftk = nil
    assert_raise(PDF::Toolkit::ExecutionError){ PDF::Toolkit.open(@pdftk.path) }
    assert_nothing_raised { pdftk = PDF::Toolkit.open(@pdftk.path,"chunky bacon") }
    assert_not_nil pdftk.author
  end

  # def test_autoloading
    # pdftk = PDF::Toolkit.new(@pdftk)
    # assert pdftk.has_key?(:creator), "Could not find creator"
  # end

  def test_inheritable_attributes
    old = PDF::Toolkit.default_permissions
    PDF::Toolkit.default_permissions = ["AllFeatures"]
    new_class = Class.new(PDF::Toolkit)
    new_class.default_permissions = ["DegradedPrinting"]
    assert_equal ["AllFeatures"], PDF::Toolkit.default_permissions
    PDF::Toolkit.default_permissions = ["ModifyContents"]
    new_class = Class.new(PDF::Toolkit)
    assert_equal ["ModifyContents"], new_class.default_permissions
  ensure
    PDF::Toolkit.default_permissions = old
  end

  def test_inheritance
    mypdf = MyPdfTool.open(@pdftk)
    assert_nothing_raised { mypdf.save!; mypdf.reload }
    assert_equal Time.at(1111111111), mypdf.updated_at
  end

  def test_to_text
    text = @pdftk.to_text {|io|io.read}
    assert_match /^\f\n?$/, text
  end

end
