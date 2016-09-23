require 'test_helper'

class IndexTest < Minitest::Test

  def test_column_map
    m = M[
      [25, 170, 90],
      [30, 75, 65],
      column_map: {'Age' => 0, 'Height' => 1, 'Weight' => 2 }
    ]

    assert_equal m['Age'],                    M[[25], [30]]
    assert_equal m[['Age', 'Age']],             M[[25, 25], [30, 30]]
    assert_equal m[['Age', 'Weight', 'Age']], M[[25.0, 90.0, 25.0],[30.0, 65.0, 30.0]]
    assert_equal m['Age'...'Weight'],
      #=> 2 x 2 Matrix
      M[[25.0, 170.0],
        [30.0,  75.0]]
    assert_equal m['Age'..'Weight'],
      #=> 2 x 3 Matrix
      M[[25.0, 170.0, 90.0],
        [30.0,  75.0, 65.0]]
  end

  def test_row_map
    m = M[
      [25, 170, 90],
      [30, 75, 65],
      [42, 150, 63],
      row_map: ['Bob', 'Jane', 'Janet'].each_with_index.to_h
    ]

    assert_equal M[25.0, 170.0, 90.0], m['Bob']
    assert_equal M[[30, 75, 65],
                  [42, 150, 63],], m['Jane'..'Janet']
  end

  def test_dual_map
    m = M[
      [165,      938,         522,             998,           450,      614.6],
      [135,      1120,        599,             1268,          288,      682],
      [157,      1167,        587,             807,           397,      623],
      [139,      1110,        615,             968,           215,      609.4],
      [136,      691,         629,             1026,          366,      569.6],
      column_map: ['Bolivia', 'Ecuador', 'Madagascar', 'Papua New Guinea', 'Rwanda', 'Average'].each_with_index.to_h,
      row_map: ['2004/05', '2005/06', '2006/07', '2007/08', '2008/09'].each_with_index.to_h
    ]

    assert_equal m['2004/05', 'Bolivia'], V[165.0]
    assert_equal m['Madagascar'], V[
       [522.0],
       [599.0],
       [587.0],
       [615.0],
       [629.0]
      ]

  end

  def test_slicing
    m = M[
      [165,      938,         522,             998,           450,      614.6],
      [135,      1120,        599,             1268,          288,      682],
      [157,      1167,        587,             807,           397,      623],
      [139,      1110,        615,             968,           215,      609.4],
      [136,      691,         629,             1026,          366,      569.6],
      column_map: ['Bolivia', 'Ecuador', 'Madagascar', 'Papua New Guinea', 'Rwanda', 'Average'].each_with_index.to_h,
      row_map: ['2004/05', '2005/06', '2006/07', '2007/08', '2008/09'].each_with_index.to_h
    ]
    assert_equal m['2004/05', 'Bolivia'..'Rwanda'], V[165.0, 938.0, 522.0, 998.0, 450.0]
    assert_equal m['2004/05'..'2006/07', 'Bolivia'..'Rwanda'], M[[165.0,  938.0, 522.0,  998.0, 450.0],
                                                                 [135.0, 1120.0, 599.0, 1268.0, 288.0],
                                                                 [157.0, 1167.0, 587.0,  807.0, 397.0]]
    assert_equal m['2004/05'..'2006/07', 'Madagascar'],
                  V[
                   [522.0],
                   [599.0],
                   [587.0]
                  ]
  end

  def test_nested_slicing
     m = M[
      [165,      938,         522,             998,           450,      614.6],
      [135,      1120,        599,             1268,          288,      682],
      [157,      1167,        587,             807,           397,      623],
      [139,      1110,        615,             968,           215,      609.4],
      [136,      691,         629,             1026,          366,      569.6],
      column_map: ['Bolivia', 'Ecuador', 'Madagascar', 'Papua New Guinea', 'Rwanda', 'Average'].each_with_index.to_h,
      row_map: ['2004/05', '2005/06', '2006/07', '2007/08', '2008/09'].each_with_index.to_h
    ]

    first_three_years = m['2004/05'..'2006/07']
    assert_equal m['2005/06'], V[135.0, 1120.0, 599.0, 1268.0, 288.0, 682.0]
    assert_equal m['2005/06']['Papua New Guinea'], V[1268.0]
    assert_equal m["Papua New Guinea"],
                  V[
                   [998.0],
                   [1268.0],
                   [807.0],
                   [968.0],
                   [1026.0]
                  ]
  end

  def test_raw_override
    m = M[
      [165,      938,         522,             998,           450,      614.6],
      [135,      1120,        599,             1268,          288,      682],
      [157,      1167,        587,             807,           397,      623],
      [139,      1110,        615,             968,           215,      609.4],
      [136,      691,         629,             1026,          366,      569.6],
      column_map: ['Bolivia', 'Ecuador', 'Madagascar', 'Papua New Guinea', 'Rwanda', 'Average'].each_with_index.to_h,
      row_map: ['2004/05', '2005/06', '2006/07', '2007/08', '2008/09'].each_with_index.to_h
    ]
    assert_raises(StandardError){
      m[0,0]
    }
    assert_equal m.raw[0,0], 165
  end
end