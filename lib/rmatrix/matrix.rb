module RMatrix
  class Matrix
    require 'narray'
    require_relative 'typecode'
    require_relative 'gpu/gpu'
    require_relative 'arch'

    include Enumerable

    attr_accessor :invert_next_operation, :matrix, :narray, :typecode, :row_map, :column_map

    def initialize(source, typecode=Typecode::SFLOAT, column_map: nil, row_map: nil)
      self.typecode = typecode
      self.narray   = two_dimensional(source, typecode)
      self.row_map, self.column_map = row_map, column_map
    end

    def matrix
      @matrix ||= narray.empty? ? narray : NMatrix.refer(narray)
    end

    def self.blank(rows: 1, columns: 1, typecode: Typecode::SFLOAT, initial: 0)
      self.new(NArray.new(typecode, columns, rows), typecode) + initial
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

    def each_column(&block)
      e = Enumerator.new do |enum|
        (0...self.columns).each  do |i|
          enum << self.raw[true, i]
        end
      end
      block_given? ? e.each(&block) : e
    end

    def each_row(&block)
     e = Enumerator.new do |enum|
        (0...self.rows).each  do |i|
          enum << self.raw[i, true]
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

    def mask
      mmap do |elm|
        (yield elm) ? 0 : elm
      end
    end

    def abs
      (self ** 2) ** 0.5
    end

    def coerce(other)
      self.invert_next_operation = true
      [self, other]
    end

    def size
      self.shape.inject(:*).to_i
    end

    def rows
      self.shape.last
    end

    def columns
      self.shape.first
    end

    def diag(dim=0)
      raise "Must be square matrix" unless self.shape[0] == self.shape[1]
      Matrix.new((self.class.identity(self.shape[0]).mult self).sum(dim))
    end

    def join_rows(*others, dim: 0)
      height = slices.map(&:shape).map(&:last).sum
      width  = slices[0].shape.first
      joined = ::NArray.new(slices[0].typecode, width, height)
      current_row = 0
      slices.each do |slice|
        slice_height = slice.shape[1]
        joined[true, current_row...current_row+slice_height] = slice
        current_row += slice_height
      end
      joined
    end

    def self.identity(size)
      blank = self.blank(rows: size, columns: size)
      blank.diagonal(1)
    end

    def sum_rows
      empty? ? self : Matrix.new(sum(1), typecode)
    end

    def sum_columns
      empty? ? self : Matrix.new(sum(0), typecode)
    end

    def concat(*others, rows: true)
      others.map!{|o| Matrix === o ? o.narray : NArray.to_na(o)}

      case rows
      when true
        # raise "Rows must match #{self.rows}, #{others.map(&:rows)}" unless [self.rows, *others.map(&:shape).map(&:last)].uniq.count.one?
        height = self.rows + others.map(&:shape).map(&:last).inject(:+)
        width  = others[0].shape.first
        joined = ::NArray.new(typecode, width, height)
        joined[true, 0...self.rows] = self.narray
        current_row = self.rows
        others.each do |slice|
          slice_height = slice.shape[1]
          joined[true, current_row...current_row+slice_height] = slice
          current_row += slice_height
        end
        joined
      else
        width  = self.columns + others.map(&:shape).map(&:first).inject(:+)
        height = others[0].shape.last
        joined = ::NArray.new(typecode, width, height)
        joined[0...self.columns, true] = self.narray
        current_col = self.columns
        others.each do |slice|
          slice_width = slice.shape[0]
          joined[current_col...current_col+slice_width, true] = slice
          current_col += slice_width
        end
        joined
        # raise "Rows must match #{self.columns}, #{others.map(&:columns)}" unless [self.columns, *others.map(&:columns)].uniq.count.one?
      end
    end

    def merge(other)
      case true
      when self.rows == 1 && other.rows == 1
        Vector.new(NArray.to_na([self.narray,other.narray]).to_type(self.typecode).reshape(self.columns + other.columns, 1))
      when self.columns == 1 && other.columns == 1
        Vector.new(NArray.to_na([self.narray,other.narray]).to_type(self.typecode).reshape(1, self.rows + other.rows))
      else
        raise "Couldn't join mismatched dimensions"
      end
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
        if type != RMatrix::Matrix::Typecode::OBJECT &&
          source.typecode == RMatrix::Matrix::Typecode::OBJECT &&
          RMatrix::Matrix === source[0]
          source = NArray.to_na(source.map(&:to_a).to_a).to_type(typecode)
        end
        source
      end

      source = source.to_type(type) unless type == source.typecode

      case source.dim
      when 1
        source.reshape(source.length, 1)
      when 2, 0
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
      return self.raw[0, 0] * self.raw[1, 1]- self.raw[0, 1] * self.raw[1, 0] if(self.columns == 2)
      sign = 1
      det = 0
      self.columns.times do |i|
        det += sign * self.raw[0,i] * self.minor(0, i).determinant
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
      if GPU.const_defined?('LOADED') && GPU.execute_within_gpu
        GPU::Matrix.new(rmatrix: self).send(method, other)
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

    def is_vector?
      [rows, columns].include?(1)
    end

    def inspect
      return 'M[Empty]' if empty?
      return Vector::inspect_vector(self) if self.is_vector?
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
      indices           = unmap_args(args)
      result_row_map    = build_result_map(self.row_map, indices.first, self.rows)      if self.row_map
      result_column_map = build_result_map(self.column_map, indices.last, self.columns) if self.column_map
      raw[*indices, column_map: result_column_map, row_map: result_row_map]
    end

    def raw
      @raw ||= begin
        raw = Struct.new(:narray, :typecode).new(self.narray, self.typecode)
        def raw.[](*args, column_map: nil, row_map: nil)
          args.all?{|x| Fixnum === x } ? narray[*args.reverse] : Matrix.new(narray[*args.reverse], typecode, column_map: column_map, row_map: row_map)
        end
        raw
      end
    end

    def build_result_map(existing, indices, size)
      return existing if indices == true
      result_map = {}
      indexify(indices, result_map, size)
      result_map.default_proc =  ->(h,k) do
        existing_index = existing[k]
        case existing_index
        when TrueClass
          existing_index
        when Range
          if existing_index.exclude_end?
            h[k] = h[existing_index.first]...h[existing_index.end]
          else
            h[k] = h[existing_index.first]..h[existing_index.end]
          end
        when nil
          raise "Couldn't find key #{k} in index mapping"
        else
          h[existing_index]
        end
      end
      result_map
    end

    def indexify(indices, results, size, total=0)
      Array(indices).each do |index|
        case index
        when TrueClass
          (0...size).each do |i|
            results[i] = i
          end
        when Fixnum
          results[index] ||= total
          total += 1
        when Array
          indexify(index, results, size, total)
        when Range
          inclusive  = index.exclude_end? ? index.first..(index.end - 1) : index
          flat_range = inclusive.end < inclusive.first ? [*inclusive.end..inclusive.first].reverse : [*inclusive]
          flat_range.each do |elm|
            indexify(elm, results, size, total)
          end
        end
      end
    end

    def unmap_args(args)
      if args.length == 1
        if row_map
          return [unmap_index(self.row_map, args[0]), true] rescue nil
        end
        if column_map
          return [true, [unmap_index(self.column_map, args[0])]] rescue nil
        end
        return [args[0]]
      else
        [
          self.row_map ? unmap_index(self.row_map, args[0]) : args[0],
          Array(self.column_map ? unmap_index(self.column_map, args[1]) : args[1])
        ]
      end
    end

    def unmap_index(map, columns)
      case columns
      when TrueClass, FalseClass
        columns
      when Array
        columns.map{|col| unmap_index(map, col)}.flatten
      when Range
        first = unmap_index(map, columns.first)
        last = unmap_index(map, columns.end)
        first = Range === first ? first.first : first
        if columns.exclude_end?
          last = Range === last ? last.first : last
          first...last
        else
          last = Range === last ? last.end : last
          first..last
        end
      else
        index = map[columns]
        raise "Value not present in index mapping: #{columns}" unless index
        index
      end
    end

    def transpose
      Matrix.new(self.matrix.transpose, typecode)
    end

    def self.[](*inputs, typecode: Typecode::SFLOAT, row_map: nil, column_map: nil)
      if inputs.length == 1 && Matrix === inputs[0]
        inputs[0]
      elsif inputs.length == 1 && [String, Symbol].include?(inputs[0].class)
        if ['byte', 'sint', 'int', 'sfloat', 'float', 'scomplex', 'complex', 'object'].include?(inputs[0])
          ->(*source){ Matrix.new(source, inputs[0], row_map: row_map, column_map: column_map)}
        else
          Matrix.new(inputs[0], typecode, row_map: row_map, column_map: column_map)
        end
      else
        Matrix.new(inputs, typecode, row_map: row_map, column_map: column_map)
      end
    end

    def max(*others)
      if others.any?
        zip_cells(others, &:max)
      else
        narray.max
      end
    end

    def min(*others)
      if others.any?
        zip_cells(others, &:min)
      else
        narray.min
      end
    end

    def zip_cells(others, &block)
      Matrix.new(self.zip(*others).map(&block), self.typecode)
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
    [:reshape, :sort, :sort_index, :inverse, :lu, :delete_at, :where, :where2, :not, :-@, :reverse, :diagonal].each(&method(:gen_matrix_delegator))
    [:sum, :prod, :mean, :stddev, :rms, :rmsdev, :shape, :to_a, :empty?].each(&method(:gen_delegator))
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

    def to_a
      return narray.reshape(narray.length).to_a if is_vector?
      return narray.to_a
    end

    def self.gpu_capable(method)
      method = translate_op(method)
      aliased_name = Arch.cpu(method)
      alias_method aliased_name, method
      define_method(method) do |*args|
        if GPU.execute_within_gpu
          GPU::Matrix.new(rmatrix: self).send(method, *args)
        else
          send(aliased_name, *args)
        end
      end
    end

    if GPU.const_defined?('LOADED')
      [:+, :/, :-, :**, :&, :^, :|, :*, :mult, :transpose].each(&method(:gpu_capable))
    end

    def self.seed(seed)
      NArray.srand(seed)
    end

    def to_m
      self
    end

    alias_method :cols, :columns
    alias_method :avg, :mean
    alias_method :length, :size

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