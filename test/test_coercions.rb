require 'test/unit'
require 'pdf/toolkit'

class CoercionsTest < Test::Unit::TestCase
  include PDF::Toolkit::Coercions

  def setup
    @y2k   = Time.utc(2000)
    @y2k_s = "D:20000101000000+00'00'"
  end

  def test_format_time
    assert_equal @y2k_s, format_time(@y2k)
  end

  def test_parse_time
    assert_equal @y2k, parse_time(@y2k_s)
    assert_equal @y2k, parse_time("D:20000101000000")
    assert_equal @y2k, parse_time("D:20000101000000Z")
  end

  def test_cast_field
    assert cast_field(@y2k_s).is_a?(Time)
    assert cast_field("D:20100505191809Z").is_a?(Time)
    assert cast_field("12").is_a?(Integer)
  end

end

