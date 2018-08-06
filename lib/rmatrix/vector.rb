module RMatrix
  class Vector < RMatrix::Matrix

    def initialize(source, typecode=Typecode::FLOAT, column_map: nil, row_map: nil)
      super
      unless (shape.length == 2 && [rows, columns].include?(1)) || shape.length == 0
        raise "Invalid dimensions #{shape.join(?x).reverse}. Vector must be eiter Nx1 or 1xM"
      end
    end

    def self.[](*inputs, typecode: Typecode::FLOAT, row_map: nil, column_map: nil, column_label_map: nil, row_label_map: nil)
      if inputs.length == 1 && [String, Symbol].include?(inputs[0].class)
        if ['byte', 'sint', 'int', 'sfloat', 'float', 'scomplex', 'complex', 'object'].include?(inputs[0].to_s)
          ->(*source){ V.new(source, inputs[0].to_s) }
        else
          Vector.new(inputs[0])
        end
      else
        Vector.new(inputs, typecode, row_map: nil, column_map: nil)
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