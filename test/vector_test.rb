require 'test_helper'

class VectorTest < Minitest::Test
  def test_index
    assert_equal V[0,3,0][1], 3
  end

  def test_type_constructor
    assert_raises(StandardError){ V[[1,2,3],[4,5,6]] }
    assert V.object[{}]
    assert V['object'][{}]
    assert V.complex[2+3i]
  end

  def test_inspect_horizontal
    assert_equal V[1,2,3].inspect, "Vector(3)
V[1.0, 2.0, 3.0]"
  end

  def test_inspect_vertical
    assert_equal V[1,2,3].T.inspect, "Vector(3)
V[[1.0],
  [2.0],
  [3.0]]"
  end

  def test_preserves_type_for_transforms
    assert_equal V[1,2,3,0,5].where.class, RMatrix::Vector
  end

  def test_preserves_type_for_scalars
    assert_equal V[1,2,3,0,5].*(2).*(3).-(1).+(2)./(3.0).**(5).class, RMatrix::Vector
  end

  def test_allow_type_change_for_matrix_math
    multiplied = V[4,5,6].T * V[1,2,3]
    refute_equal multiplied.class, RMatrix::Vector
    assert_equal multiplied.class, RMatrix::Matrix
    assert_equal multiplied, \
      M[[4.0,  8.0, 12.0],
        [5.0, 10.0, 15.0],
        [6.0, 12.0, 18.0]]
  end

  def test_transpose
    assert_equal V[[1],[2],[3]].T, V[1,2,3]
    assert_equal V[1,2,3].T.T, V[1,2,3]
  end
end