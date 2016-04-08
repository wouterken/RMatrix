module RMatrix
  class Vector < RMatrix::Matrix

    def initialize(source)
      super
      raise "Invalid dimensions #{shape.join(?x).reverse}. Vector must be eiter Nx1 or 1xM" unless [rows, columns].include?(1) && shape.length == 2
    end

    def self.[](*inputs)
      if inputs.length == 1 && [String, Symbol].include?(inputs[0].class)
        if ['byte', 'sint', 'int', 'sfloat', 'float', 'scomplex', 'complex', 'object'].include?(inputs[0].to_s)
          ->(*source){ Matrix.new(source, typecode: inputs[0].to_s) }
        else
          Vector.new(inputs[0])
        end
      else
        Vector.new(inputs)
      end
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