module RMatrix
  class Vector < RMatrix::Matrix

    def initialize(source, typecode=Typecode::FLOAT)
      if narray
        self.narray = narray
        self.matrix = NMatrix.refer(matrix)
      else
        super
      end
      raise "Invalid dimensions #{shape.join(?x).reverse}. Vector must be eiter Nx1 or 1xM" unless [rows, columns].include?(1) && shape.length == 2
    end

    def self.[](*inputs)
      if inputs.length == 1 && [String, Symbol].include?(inputs[0].class)
        if ['byte', 'sint', 'int', 'sfloat', 'float', 'scomplex', 'complex', 'object'].include?(inputs[0].to_s)
          ->(*source){ Matrix.new(source, inputs[0].to_s) }
        else
          Vector.new(inputs[0])
        end
      else
        Vector.new(inputs)
      end
    end

    def to_a
      return narray.reshape(narray.length).to_a
    end

    def inspect
      self.class.inspect_vector(self)
    end

    def self.inspect_vector(v)
      elms = v.narray.to_a.flatten
      print = elms.first(10)
      has_more = elms.length > 10
      if v.rows == 1
        "Vector(#{v.narray.length})\nV[#{print.join(", ") + (has_more ? ',...' : '')}]"
      else
        "Vector(#{v.narray.length})\nV[\n [#{print.join("],\n [") + (has_more ? "\n  ..." : '')}]\n]"
      end
    end
  end
end