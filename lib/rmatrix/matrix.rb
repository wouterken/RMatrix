module RMatrix
  class Matrix
    require 'narray'
    include Enumerable

    attr_accessor :invert_next_operation, :matrix, :narray, :typecode

    def initialize(source, narray: nil, typecode: 'float')
      self.typecode = typecode
      if [Symbol, String].include?(source.class)
        dimensions = "#{source}".split("x").map(&:to_i)
        source = NArray.new(typecode, dimensions.inject(:*)).reshape(dimensions[1], dimensions[0])
      end

      self.narray = NArray.refer(narray || two_dimensional(source, typecode))
      self.matrix = NMatrix.refer(self.narray)
    end

    def _dump(level)
      [narray.typecode, columns, rows, narray.to_s].join(":")
    end

    def self._load arg
      typecode, columns, rows, as_str = arg.split(":",4)
      Matrix.new(nil, narray: NArray.to_na(as_str.to_s, typecode.to_i).reshape(columns.to_i, rows.to_i))
    end

    def each(&block)
      e = Enumerator.new do |enum|
        matrix.each do |elm|
          enum << elm
        end
      end
      block_given? ? e.each(&block) : e
    end

    def mmap
      as_na = NArray.to_na(
        matrix.each.map do |elm|
          yield elm
        end
      ).to_type(typecode)
      Matrix.new(as_na.reshape(*shape), typecode: typecode)
    end

    def coerce(other)
      self.invert_next_operation = true
      [self, other]
    end

    def size
      self.shape.inject(:*)
    end

    def rows
      self.shape.last
    end

    def columns
      self.shape.first
    end

    def sum_rows
      Matrix.new(sum(0), typecode: typecode)
    end

    def sum_columns
      Matrix.new(sum(1), typecode: typecode)
    end

    def two_dimensional(source, type)
      source = [source] if Numeric === source
      source = NArray.to_na(source).to_type(type)
      case source.dim
      when 1
        source.reshape(source.length, 1)
      when 2
        source
      else
        raise "Source for matrix must be either one or two dimensional" unless source.shape[2..-1].all?{|x| x == 1}
        source.reshape(source.shape[0], source.shape[1])
      end
    end

    def minor(x,y)
      return self.delete_at(y,x)
    end

    def cofactor_matrix(*args)
      return cofactor(*args) if args.length == 2

      result = []
      rows.times do |i|
        result << []
        columns.times do |j|
          result[i] << cofactor(i, j)
        end
      end
      return Matrix.new(result, typecode: typecode)
    end

    def determinant
      raise "Cannot calculate determinant of non-square matrix" unless columns == rows
      return self[0, 0] * self[1, 1]- self[0, 1] * self[1, 0] if(self.columns == 2)
      sign = 1
      det = 0
      self.columns.times do |i|
        det += sign * self[0,i] * self.minor(0, i).determinant
        sign *= -1
      end
      return det
    end

    def adjoint
      self.cofactor_matrix.transpose
    end

    def *(other)
      if other.kind_of?(Matrix)
        raise "Matrix A columns(#{self.columns}) != Matrix B rows(#{other.columns})" if other.rows != self.columns
        Matrix.new(self.matrix * other.matrix, typecode: typecode)
      else
        Matrix.new(apply_scalar(:*, other), typecode: typecode)
      end
    end

    def mult(other)
      Matrix.new(apply_elementwise(:*, other), typecode: typecode)
    end

    def ==(other)
      self.matrix == Matrix[other].matrix
    end

    def to_s
      inspect
    end

    def box_lines(lines, add_dots)
      "[#{lines.map{|l| "[#{l}#{add_dots ? ' ...' : '' }]"}.join(",\n  ")}]"
    end

    def round(dp)
      mmap{|x| x.round(dp) }
    end

    def inspect
      inspect_rows    = [10, self.rows].min
      inspect_columns = [10, self.columns].min
      more_rows       = inspect_rows    < self.rows
      more_columns    = inspect_columns < self.columns

      to_print        = self.matrix[0...inspect_columns, 0...inspect_rows]
      as_strings = inspect_columns.times.map do |i|
        column    = to_print[i, 0...inspect_rows].flatten.to_a.map{|f| f.to_s.gsub(/(\.\d{4}).*/, "\\1") }
        max_width = column.map{|s| s.length }.max
        column.map!{|s| s.rjust(max_width, ' ')} + (more_rows ? ['.' * max_width] : [])
      end.transpose
      "#{rows} x #{columns} Matrix\nM#{box_lines(as_strings.map{|row| row.join(", ") }, more_columns)}"
    end


    def [](*args)
      args.all?{|x| Fixnum === x } ? narray[*args.reverse] : Matrix.new(narray[*args.reverse], typecode: typecode)
    end

    def transpose
      Matrix.new(self.matrix.transpose, typecode: typecode)
    end

    def self.new(*args, &blk)
      result = super
      if result.class == Matrix && (result.rows == 1 || result.columns == 1)
        vect = V[1]
        vect.typecode, vect.matrix, vect.narray = result.typecode, result.matrix, result.narray
        result = vect
      end
      result
    end

    def self.[](*inputs)
      if inputs.length == 1 && Matrix === inputs[0]
        inputs[0]
      elsif inputs.length == 1 && [String, Symbol].include?(inputs[0].class)
        if ['byte', 'sint', 'int', 'sfloat', 'float', 'scomplex', 'complex', 'object'].include?(inputs[0])
          ->(*source){ Matrix.new(source, typecode: inputs[0]) }
        else
          Matrix.new(inputs[0])
        end
      else
        Matrix.new(inputs)
      end
    end

    def self.gen_mutator(name)
      define_method(name) do |*args, &blk|
        matrix.send(name, *args, &blk)
        self
      end
    end

    def self.gen_matrix_delegator(name)
      define_method(name) do |*args, &blk|
        Matrix.new(matrix.send(name, *args, &blk), typecode: typecode)
      end
    end

    def self.gen_delegator(name)
      define_method(name) do |*args, &blk|
        matrix.send(name, *args, &blk)
      end
    end

    def self.gen_typeconstructor(name)
      define_singleton_method(name) do
        ->(*source){ Matrix.new(source, typecode: name.to_s) }
      end
    end

    OPERATIONS_MAP = {
      :& => 'and',
      :^ => 'xor',
      :| => 'or'
    }
    def translate_op(op)
      OPERATIONS_MAP.fetch(op, op)
    end

    [:fill!, :random!, :indgen!].each(&method(:gen_mutator))
    [:reshape, :sort, :sort_index, :inverse, :lu, :delete_at, :where, :where2, :not, :-@].each(&method(:gen_matrix_delegator))
    [:sum, :prod, :mean, :stddev, :rms, :rmsdev, :min, :max, :shape].each(&method(:gen_delegator))
    [:byte, :sint, :int, :sfloat, :float, :scomplex, :complex, :object].each(&method(:gen_typeconstructor))

    [:+, :/, :-, :**, :&, :^, :|].each do |op|
      define_method(op) do |other|
        op = translate_op(op)
        result = if other.kind_of?(Matrix)
          apply_elementwise(op, other)
        else
          apply_scalar(op, other)
        end
        Matrix.new(
          result, typecode: typecode
        )
      end
    end

    def self.seed(seed)
      NArray.srand(seed)
    end

    private
      def test_inverse
        inverse = self.invert_next_operation
        self.invert_next_operation = false
        return inverse
      end

      def cofactor(i, j)
        minor = self.minor(i, j)
        sign = ((i * self.columns + j) % 2).zero? ? 1 : -1;
        return sign * minor.determinant
      end

      def apply_elementwise(op, other)
        if test_inverse
          other.narray.send(op, self.narray)
        else
          narray.send(op, Matrix[other].narray)
        end
      end

      def apply_scalar(op, other)
        if test_inverse
          Matrix[other].narray.send(op, self.narray)
        else
          narray.send(op, Matrix[other].narray)
        end
      end
  end

  class ::NArray; include Enumerable; end
end