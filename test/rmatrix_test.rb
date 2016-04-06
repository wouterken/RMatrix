require 'test_helper'

class RMatrixTest < Minitest::Test

  def setup
    M.seed(12345)
    @big   = M['1000x1000'].random! * 1000
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

  def test_cofactor_matrix
    assert_equal @small[0].C, [[12.0, -14.0, 4.0], [-6.0, -2.0, 16.0], [-9.0, 15.0, -39.0]]
    assert_equal @small[1].C, [[-16.0, -20.0, 32.0], [-47.0, -1.0, 28.0], [65.0, 7.0, -64.0]]
    assert_equal @small[2].C, [[24.0, -30.0, -13.0], [3.0, 7.0, -7.0], [-20.0, 25.0, 18.0]]
  end

  def test_inverse
     assert_equal @small[0].I.round(4),M[ [ -0.222222, 0.111111, 0.166667 ],
                                         [ 0.259259, 0.037037, -0.277778 ],
                                         [ -0.0740741, -0.296296, 0.722222 ] ].round(4)

     assert_equal @small[1].I.round(4),M[[ 0.121212, 0.356061, -0.492424 ],
                                         [ 0.151515, 0.00757576, -0.0530303 ],
                                         [ -0.242424, -0.212121, 0.484848 ] ].round(4)

     assert_equal @small[2].I.round(4), M[[ 0.55814, 0.0697674, -0.465116 ],
                                        [ -0.697674, 0.162791, 0.581395 ],
                                        [ -0.302326, -0.162791, 0.418605 ]].round(4)

  end

  def test_tranpose
    assert_equal @small[0].T, M[[3.0, 9.0, 4.0], [7.0, 8.0, 4.0], [2.0, 1.0, 2.0]]
    assert_equal @small[1].T, M[[1.0, 8.0, 4.0], [9.0, 8.0, 8.0], [2.0, 9.0, 7.0]]
    assert_equal @small[2].T, M[[7.0, 5.0, 7.0], [2.0, 4.0, 3.0], [5.0, 0.0, 6.0]]
  end

  def test_one_by_n_is_vector
    assert M[1,2,3].class == RMatrix::Vector
    assert_raises(RuntimeError){ V[[1,2,3],[4,5,6]]}
  end

  def test_n_by_one_is_vector
    assert M[[1],[2],[3]].class == RMatrix::Vector
    assert_raises(RuntimeError){ V[[1,2],[3],[4]]}
  end

  def test_determinant
    assert_equal @small[0].D, -54
    assert_equal @small[1].D, -132
    assert_equal @small[2].D, 43
  end

  def test_minor
    assert_equal @small[0].M(0,0), M[[8,1],[4,2]]
    assert_equal @small[1].M(1,2), M[[1,9],[4,8]]
    assert_equal @small[2].M(2,2), M[[7,2],[5,4]]
  end

  def test_adjoint
    assert_equal @small[0].A, M[[ 12.0 ,-6.0, -9.0],
                                [-14.0 ,-2.0, 15.0],
                                [  4.0 ,16.0, -39.0]]
    assert_equal @small[1].A, M[[ -16.0 ,-47.0, 65.0],
                                [-20.0 ,-1.0, 7.0],
                                [  32.0 ,28.0, -64.0]]
    assert_equal @small[2].A, M[[ 24.0, 3.0, -20.0],
                                [-30.0, 7.0, 25.0],
                                [-13.0,-7.0, 18.0]]
  end

  def test_marshal
    assert_equal @small.map(&Marshal.method(:dump)).map(&Marshal.method(:load)), @small
  end

  def test_enumeration
    assert_equal @small[0].each.map{|x| x ** 2}.select{|x| x % 2}.inject(:+), 244
  end

  def test_mmap
    assert_equal @small.map{|x| x.mmap{|y| y * 2}}, @small.map{|x| x * 2}
    assert_equal @small.map{|x| x.mmap{|y| y ** 2}}, @small.map{|x| x ** 2}
  end

  def test_multiplication
    assert_equal @small[2] * @small[1], M[
                                          [43.0 ,119.0 ,67.0],
                                          [37.0 ,77.0 ,46.0],
                                          [55.0 ,135.0 ,83.0]
                                        ]
  end

  def test_elmwise_multiplication
     assert_equal @small[2] * 0.5, M[[3.5, 1.0, 2.5],[2.5, 2.0, 0.0],[3.5, 1.5, 3.0]]
  end

  def test_elmwise_operations
    assert_equal @small[2] - 0.5, M[[6.5, 1.5, 4.5],[4.5, 3.5, -0.5],[6.5, 2.5, 5.5]]
    assert_equal @small[2] + 0.5, M[[7.5, 2.5, 5.5],[5.5, 4.5, 0.5],[7.5, 3.5, 6.5]]
    assert_equal @small[2] ** 2, M[[49.0,  4.0, 25.0],[25.0, 16.0,  0.0],[49.0,  9.0, 36.0]]
  end

  def test_inverted_elmwise_operations
    assert_equal 2 / @small[0], M[[ 2 / 3.0, 2 / 7.0, 1.0 ],
                                  [ 2 / 9.0, 0.25, 2.0 ],
                                  [ 0.5, 0.5, 1.0 ] ]
    assert_equal 2 - @small[0], M[[ -1.0, -5.0, 0.0 ],
                                  [ -7.0, -6.0, 1.0 ],
                                  [ -2.0, -2.0, 0.0 ]]
  end

  def test_sum_row_and_sum_col
    assert_equal @small.map(&:sum_rows), [V[[12],[18],[10]], V[[12],[25],[19]], V[[14],[9],[16]]]
    assert_equal @small.map(&:sum_columns), [V[16,19,5], V[13,25,18], V[19,9,11]]
  end

  def test_random
    assert M['10x10'].random!.mean != 0
  end

  def test_fill
    assert M['10x10'].fill!(5).mean == 5
  end

  def test_reshape
    assert_equal M['10x10'].fill!(5).reshape(5, 20).shape, [5,20]
  end

  def test_sort
    assert_equal M[[9,4,6],[2,7,5],[1,3,8]].sort, M[[1,2,3],[4,5,6],[7,8,9]]
    assert_equal V[9,4,6,2,7,5,1,3,8].sort, V[1,2,3,4,5,6,7,8,9]
  end

  def test_where
  end

  def test_not
  end

  def test_sum
  end

  def test_prod
  end

  def test_mean
  end

  def test_stddev
  end

  def test_rms
  end

  def test_rmsdev
  end

  def test_min_max
  end

  def test_shape
  end

  def test_pow
  end

  def test_and_or_xor
  end
end
