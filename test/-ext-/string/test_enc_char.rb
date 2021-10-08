# frozen_string_literal: false
require 'test/unit'
require "-test-/string"

class Test_StringEncChar < Test::Unit::TestCase
  def test_enc_left_char_head_7bit
    str = Bug::String.new("abc")
    assert_equal(0, str.enc_left_char_head(0))
    assert_equal(1, str.enc_left_char_head(1))
    assert_equal(2, str.enc_left_char_head(2))
    assert_equal(3, str.enc_left_char_head(3))
    assert_equal(3, str.enc_left_char_head(4))
  end

  def test_enc_left_char_head_valid
    str = Bug::String.new("\u3240")
    assert_equal(0, str.enc_left_char_head(0))
    assert_equal(0, str.enc_left_char_head(1))
    assert_equal(0, str.enc_left_char_head(2))
    assert_equal(3, str.enc_left_char_head(3))
    assert_equal(3, str.enc_left_char_head(4))
  end

  def test_enc_left_char_head_invalid
    str = Bug::String.new("\u3240\xe3")
    assert_equal(0, str.enc_left_char_head(0))
    assert_equal(0, str.enc_left_char_head(1))
    assert_equal(0, str.enc_left_char_head(2))
    assert_equal(3, str.enc_left_char_head(3))
    assert_equal(3, str.enc_left_char_head(4))
  end
end
