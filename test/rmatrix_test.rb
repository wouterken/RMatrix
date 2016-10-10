require 'test_helper'

class RMatrixTest < Minitest::Test

  def setup
    M.seed(12345)
    @big   = M.blank(rows: 1000, columns:  1000).random! * 1000
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

  def test_transpose
    assert_equal @small[0].T, M[[3.0, 9.0, 4.0], [7.0, 8.0, 4.0], [2.0, 1.0, 2.0]]
    assert_equal @small[1].T, M[[1.0, 8.0, 4.0], [9.0, 8.0, 8.0], [2.0, 9.0, 7.0]]
    assert_equal @small[2].T, M[[7.0, 5.0, 7.0], [2.0, 4.0, 3.0], [5.0, 0.0, 6.0]]
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

  def test_random
    assert M.blank(rows: 10, columns: 10).random!.mean != 0
  end

  def test_fill
    assert M.blank(rows: 10, columns: 10).fill!(5).mean == 5
  end

  def test_reshape
    assert_equal M.blank(rows: 10, columns: 10).fill!(5).reshape(5, 20).shape, [5,20]
  end

  def test_sort
    assert_equal M[[9,4,6],[2,7,5],[1,3,8]].sort, M[[1,2,3],[4,5,6],[7,8,9]]
    assert_equal V[9,4,6,2,7,5,1,3,8].sort, V[1,2,3,4,5,6,7,8,9]
  end

  def test_where
    with_empties = V[2,5,0,1,0,8]
    indices = with_empties.to_a.map.with_index{|a,i| a.zero? ? nil : i.to_f}.compact
    assert_equal indices, with_empties.where.to_a
  end

  def test_not
    with_zeroes = V[2,5,0,1,0,8]
    assert_equal V[0, 0, 1, 0, 1, 0], with_zeroes.not
    assert_equal V[1, 1, 0, 1, 0, 1], with_zeroes.not.not
  end

  def test_sum
    test = M[[3,4],
             [8,9]]
    assert_equal test.sum, 24
    assert_equal test.sum(0), V[[7], [17]]
    assert_equal test.sum(1), V[[11, 13]]
  end

  def test_prod
    test = M[[3,4],
             [8,9]]
    assert_equal test.prod, 864.0
    assert_equal test.prod(0), V[[12], [72]]
    assert_equal test.prod(1), V[[24, 36]]
  end

  def test_mean
    test = M[[3,4],
             [8,9]]
    assert_equal test.mean, 6.0
    assert_equal test.mean(0), [3.5, 8.5]
    assert_equal test.mean(1), [5.5, 6.5]
  end

  def test_stddev
    test = M[[3,4],
             [8,9]]
    assert_equal test.stddev.round(3), 2.944
    assert_equal test.stddev(0).round(2), V[0.71, 0.71]
    assert_equal test.stddev(1).round(2), V[3.54, 3.54]
  end

  def test_rms
    test = M[[3,4],
             [8,9]]
    assert_equal test.rms.round(3), 6.519
    assert_equal test.rms(0).round(2), V[3.54, 8.51]
    assert_equal test.rms(1).round(2), V[6.04, 6.96]
  end

  def test_rmsdev
    test = M[[3,4],
             [8,9]]
    assert_equal test.rmsdev.round(3), 2.55
    assert_equal test.rmsdev(0).round(2), V[0.5, 0.5]
    assert_equal test.rmsdev(1).round(2), V[2.5, 2.5]
  end

  def test_min_max
    test = M[[3,4],
         [8,9]]
    assert_equal [3.0, 9.0], test.minmax
  end

  def test_shape
    assert M[1,2,3].shape, [3,1]
    assert M[[1],[2],[3]].shape, [1,3]
    assert M[[1,2],[3,4]].shape, [2,2]
  end

  def test_pow
    test = M[[3,4],
             [8,9]]
    assert_equal test ** 5,
      M[[  243.0,  1024.0],
        [32768.0, 59049.0]]
    assert_equal (test ** 0.5).round(3),
      M[[1.732, 2.0],
        [2.828, 3.0]]
  end

  def test_and_or_xor
    base = M[3,8,3,1,5,0,0]
    mask = M[1,1,0,0,1,4,4]
    assert_equal base & mask, M[1,1,0,0,1,0,0]
    assert_equal base | mask, M[1,1,1,1,1,1,1]
    assert_equal base ^ mask, M[0,0,1,1,0,1,1]
  end

  def test_blank
    assert_equal M.blank, V[0]
    assert_equal M[], M.blank(rows: 0, columns: 0)
    assert_equal M[1,1,1], M.blank(rows: 1, columns: 3, initial: 1)
  end

  def test_each
    buffer = []
    M[[1,2],[3,4]].each do |v| buffer << v  * 2 end
    assert_equal buffer, [2,4,6,8]
  end

  def test_each_column
    test = M[
      [1,2,3],
      [4,5,6],
      [8,8,8]
    ]
    assert Enumerator === test.each_column
    assert_equal test.each_column.map(&:sum), [13, 15, 17]
  end

  def test_each_row
    test = M[
      [1,2,3],
      [4,5,6],
      [8,8,8]
    ]
    assert Enumerator === test.each_row
    assert_equal test.each_row.map(&:sum), [6, 15, 24]
  end

  def test_mask
    v = V[1,-1,1,-1,2,-2]
    assert_equal  v.mask{|x| x < 0}, V[1.0,  0.0, 1.0,  0.0, 2.0,  0.0]
    assert_equal  v.mask{|x| x > 0}, V[0.0, -1.0, 0.0, -1.0, 0.0, -2.0]
  end

  def test_abs
    m = M[[1,-2],[3,-4]]
    assert_equal m.abs, M[[1,2],[3,4]]
  end

  def test_coerce
    m = M[3,6,9]
    refute_equal m / 3, 3 / m
    assert_equal m / 3, M[1,2,3]
    assert_equal 3 / m, M[1, 0.5, 1/3r]
  end

  def test_identity
    assert_equal M.identity(2),
      M[
        [1.0, 0.0],
        [0.0, 1.0]
      ]
    assert_equal M.identity(3),
      M[
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0]
      ]
  end

  def test_sum_rows
    assert_equal @small.map(&:sum_rows), [V[16,19,5], V[13,25,18], V[19,9,11]]
  end

  def test_sum_columns
    assert_equal @small.map(&:sum_columns), [V[[12],[18],[10]], V[[12],[25],[19]], V[[14],[9],[16]]]
  end

  def test_concat
    assert_equal M[4,5,6].concat(M[1,2,3]),
                        #=> 2 x 3 Matrix
                        M[[4.0, 5.0, 6.0],
                          [1.0, 2.0, 3.0]]
    assert_equal M[4,5,6].concat(M[1,2,3], rows: false),
                    #=> 2 x 3 Matrix
                    M[[4.0, 5.0, 6.0, 1.0, 2.0, 3.0]]

  end

  def test_join
    assert_equal M[1,2,3,4].join(M[6,7,8,9]),
                 V[1.0, 2.0, 3.0, 4.0, 6.0, 7.0, 8.0, 9.0]
    assert_equal M[1,2,3,4].T.join(M[6,7,8,9].T),
                 V[
                  [1.0],
                  [2.0],
                  [3.0],
                  [4.0],
                  [6.0],
                  [7.0],
                  [8.0],
                  [9.0]
                 ]
  end

  def test_round
     assert_in_delta 0.33333, M[1/3r].round(5)[0], 0.000001
     assert_in_delta 0.33330, M[1/3r].round(4)[0], 0.000001
     assert_in_delta 0.33300, M[1/3r].round(3)[0], 0.000001
     assert_in_delta 0.33000, M[1/3r].round(2)[0], 0.000001
     assert_in_delta 0.30000, M[1/3r].round(1)[0], 0.000001
  end

  def test_max
    test =  M[[1,2,1],[3,1,3]]
    assert_equal test.max(0), M[[2],[3]]
    assert_equal test.max(1), M[3,2,3]
    assert_equal test.max, 3
  end

  def test_min
    test =  M[[1,2,1],[3,2,3]]
    assert_equal test.min(0), M[[1],[2]]
    assert_equal test.min(1), M[1,2,1]
    assert_equal test.min,1
  end

  def test_zip
    assert_equal M[1,2,3].zip(M[3,4],M[5]).T,
                 M[
                  [1,2,3],
                  [3,4,0],
                  [5,0,0]
                 ]
  end

  def test_type_constructors
     assert_equal M.object[12,{}, Set], M['object'][12, {}, Set]
     assert_equal M.int[5.123], M[5, typecode: RMatrix::Matrix::Typecode::INT]
     assert_equal M.float[12], M['float'][12.00]
     assert M.sfloat[12.0]
     assert  M.complex[3+12i]
  end
end
