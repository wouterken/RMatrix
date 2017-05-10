require 'test_helper'

class VectorTest < Minitest::Test
  def test_index
    assert_equal V[0,3,0][1], 3
  end

  def test_type_constructor
    assert_raises(StandardError){ V[{}] }
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
V[[1],
  [2],
  [3]]"
  end

  def test_transpose
    assert_equal V[[1],[2],[3]].T, V[1,2,3]
    assert_equal V[1,2,3].T.T, V[1,2,3]
  end
end