module RMatrix
  class Matrix
    require 'narray'
    require_relative 'typecode'
    require_relative 'gpu/gpu'
    require_relative 'arch'

    include Enumerable

    attr_accessor :invert_next_operation, :matrix, :narray, :typecode

    def initialize(source, typecode=Typecode::SFLOAT)
      self.typecode = typecode
      self.narray   = two_dimensional(source, typecode)
    end

    def matrix
      @matrix ||= NMatrix.refer(narray)
    end

    def self.blank(rows, cols, typecode=Typecode::SFLOAT)
      self.new(NArray.new(typecode, cols, rows), typecode)
    end

    def _dump(level)
      [narray.typecode, columns, rows, narray.to_s].join(":")
    end

    def self._load arg
      typecode, columns, rows, as_str = arg.split(":",4)
      Matrix.new(NArray.to_na(as_str.to_s, typecode.to_i).reshape(columns.to_i, rows.to_i), typecode.to_i)
    end

    def gpu_buffer
      @gpu_buffer ||= GPU::buffer(self.narray)
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
      Matrix.new(as_na.reshape(*shape), typecode)
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
      Matrix.new(sum(0), typecode)
    end

    def sum_columns
      Matrix.new(sum(1), typecode)
    end

    def two_dimensional(source, type)
      case source
      when NArray
        if NMatrix === source
          @matrix = source
          source = NArray.refer(source)
        end
      when Numeric
        source = NArray.to_na([source])
      else
        source = NArray.to_na(source)
      end

      source = source.to_type(type) unless type == source.typecode

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
      return Matrix.new(result, typecode)
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
        Matrix.new(self.matrix * other.matrix, typecode)
      else
        Matrix.new(apply_scalar(:*, other), typecode)
      end
    end

    def mult(other)
      if GPU.execute_within_gpu
        GPU::Matrix.new(self).send(method, other)
      else
        Matrix.new(self.narray * other.narray, typecode)
      end
    end

    def ==(other)
      self.narray == Matrix[other].narray
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
      return Vector::inspect_vector(self) if [rows, columns].include?(1)

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
      args.all?{|x| Fixnum === x } ? narray[*args.reverse] : Matrix.new(narray[*args.reverse], typecode)
    end

    def transpose
      Matrix.new(self.matrix.transpose, typecode)
    end

    def self.[](*inputs)
      if inputs.length == 1 && Matrix === inputs[0]
        inputs[0]
      elsif inputs.length == 1 && [String, Symbol].include?(inputs[0].class)
        if ['byte', 'sint', 'int', 'sfloat', 'float', 'scomplex', 'complex', 'object'].include?(inputs[0])
          ->(*source){ Matrix.new(source, inputs[0]) }
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
        Matrix.new(matrix.send(name, *args, &blk), typecode)
      end
    end

    def self.gen_delegator(name)
      define_method(name) do |*args, &blk|
        matrix.send(name, *args, &blk)
      end
    end

    def self.gen_typeconstructor(name)
      define_singleton_method(name) do
        ->(*source){ Matrix.new(source, name.to_s) }
      end
    end

    OPERATIONS_MAP = {
      :& => 'and',
      :^ => 'xor',
      :| => 'or'
    }
    def self.translate_op(op)
      OPERATIONS_MAP.fetch(op, op)
    end

    [:fill!, :random!, :indgen!].each(&method(:gen_mutator))
    [:reshape, :sort, :sort_index, :inverse, :lu, :delete_at, :where, :where2, :not, :-@].each(&method(:gen_matrix_delegator))
    [:sum, :prod, :mean, :stddev, :rms, :rmsdev, :min, :max, :shape, :to_a].each(&method(:gen_delegator))
    [:byte, :sint, :int, :sfloat, :float, :scomplex, :complex, :object].each(&method(:gen_typeconstructor))

    [:+, :/, :-, :**, :&, :^, :|].each do |op|
      op = translate_op(op)
      define_method(op) do |other|
        result = case other
        when Matrix
          apply_elementwise(op, other)
        else
          apply_scalar(op, other)
        end
        Matrix.new(
          result, typecode
        )
      end
    end

    def self.gpu_capable(method)
      method = translate_op(method)
      aliased_name = Arch.cpu(method)
      alias_method aliased_name, method
      define_method(method) do |*args|
        if GPU.execute_within_gpu
          GPU::Matrix.new(self).send(method, *args)
        else
          send(aliased_name, *args)
        end
      end
    end

    [:+, :/, :-, :**, :&, :^, :|, :*, :mult, :transpose].each(&method(:gpu_capable))

    def self.seed(seed)
      NArray.srand(seed)
    end

    private
      def test_inverse
        if self.invert_next_operation
          self.invert_next_operation = false
          return true
        end
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
          narray.send(op, other.narray)
        end
      end

      def apply_scalar(op, other)
        if test_inverse
          other.send(op, self.narray)
        else
          narray.send(op, other)
        end
      end

  end

  class ::NArray; include Enumerable; end
end