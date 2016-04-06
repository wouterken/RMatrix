module RMatrix
  class Matrix
    alias_method :I, :inverse
    alias_method :T, :transpose
    alias_method :D, :determinant
    alias_method :M, :minor
    alias_method :A, :adjoint
    alias_method :C, :cofactor_matrix
  end
end

M = RMatrix::Matrix
V = RMatrix::Vector