require 'test_helper'

class ShortcutsTest < Minitest::Test
   def setup
    @small = [
      M[[3, 7, 2],
        [9, 8, 1],
        [4, 4, 2]],
      M[[1, 9, 2],
        [8, 8, 9],
        [4, 8, 7]],
      M[[7, 2, 5],
        [5, 4, 0],
        [7, 3, 6]]
    ]
  end

  def test_I
    @small.each do |m|
      assert_equal m.I, m.inverse
    end
  end

  def test_T
    @small.each do |m|
      assert_equal m.T, m.transpose
    end
  end

  def test_D
    @small.each do |m|
      assert_equal m.D, m.determinant
    end
  end

  def test_Minor
    @small.each do |m|
      assert_equal m.M(1,1), m.minor(1,1)
    end
  end

  def test_A
    @small.each do |m|
      assert_equal m.A, m.adjoint
    end
  end

  def test_C
    @small.each do |m|
      assert_equal m.C, m.cofactor_matrix
    end
  end

  def test_M
    assert_equal M, RMatrix::Matrix
  end

  def test_V
    assert_equal V, RMatrix::Vector
  end
end