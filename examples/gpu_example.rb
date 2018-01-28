require 'rmatrix'

m1 = M[
  [1,2,3],
  [4,5,6]
]

m2 = M[
  [5,2],
  [9,4],
  [3,4]
]

RMatrix::GPU.exec do
  buffer_two = m1.buffer * m2.buffer
  buffer_two * M[[1,2],[3,4]]
end