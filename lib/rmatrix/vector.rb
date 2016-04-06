module RMatrix
  class Vector < RMatrix::Matrix

    def initialize(source)
      super
      raise "Invalid dimensions #{shape.join(?x).reverse}. Vector must be eiter Nx1 or 1xM" unless [rows, columns].include?(1) && shape.length == 2
    end

    def self.[](*inputs)
      Vector.new(inputs)
    end

    def inspect
      elms = narray.to_a.flatten
      print = elms.first(10)
      has_more = elms.length > 10
      if rows == 1
        "Vector(#{narray.length})\nV[#{print.join(", ") + (has_more ? ',...' : '')}]"
      else
        "Vector(#{narray.length})\nV[\n [#{print.join("],\n [") + (has_more ? "\n  ..." : '')}]\n]"
      end
    end
  end
end