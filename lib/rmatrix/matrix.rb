module RMatrix
  class Matrix

    class << self
      attr_accessor :named_inspect
    end

    require 'narray'
    require_relative 'typecode'

    include Enumerable
    include Indices

    attr_accessor :invert_next_operation, :narray, :typecode, :row_label_map, :column_label_map
    attr_reader :row_map, :column_map
    attr_writer :matrix

    def initialize(source, typecode=Typecode::FLOAT, column_map: nil, row_map: nil, column_label_map: nil, row_label_map: nil)
      self.typecode    = typecode
      self.narray      = two_dimensional(source, typecode)
      self.row_map     = row_map
      self.column_map  = column_map
    end

    def row_map=(row_map)
      @row_map = parse_map(row_map)
      @row_label_map = @row_map.invert unless !@row_map || @row_map.default_proc
    end

    def column_map=(column_map)
      @column_map = parse_map(column_map)
      @column_label_map = @column_map.invert unless !@column_map || @column_map.default_proc
    end

    def parse_map(map, invert: false)
      case map
      when nil then map
      when Array then invert ? map.each.with_index.map.to_h.invert : map.each.with_index.map.to_h
      when Hash then map
      else raise 'Invalid map type encountered'
      end
    end

    def matrix
      @matrix ||= narray.empty? ? narray : NMatrix.refer(narray)
    end

    def self.blank(rows: 1, columns: 1, typecode: Typecode::FLOAT, initial: 0, column_map: nil, row_map: nil)
      source = self.new(NArray.new(typecode, columns, rows), typecode, column_map: column_map, row_map: row_map)
      source.narray[]= initial unless source.empty?
      source
    end

    def set_all(value)
      narray[]=(value)
    end

    def _dump(level)
      narray.to_s << ':' << columns.to_s << ':' << rows.to_s << ':' << narray.typecode.to_s
    end

    def map(flatten: true)
      narray.to_type(RMatrix::Matrix::Typecode::OBJECT).map do |x|
        yield x
      end.to_a
    end

    def flat_map(&block)
      map(&block).flatten(1)
    end

    def to_f
      if length === 1
        self.narray[0].to_f
      else
        raise "Can only call to_f on vectors of length 1"
      end
    end

    def to_i
      if length === 1
        self.narray[0].to_i
      else
        raise "Can only call to_i on vectors of length 1"
      end
    end

    def self._load arg
      split_index, buffer, index = 0, '', arg.length - 1
      split = Array.new(3)
      while split_index < 3
        case char = arg[index]
        when ':'
          split[split_index] = buffer.reverse.to_i
          split_index += 1
          buffer = ''
        else buffer << char
        end
        index -= 1
      end
      arg[index+1..-1] = ''
      self.new(NArray.to_na(arg, split[0]).reshape(split[2], split[1]), split[0])
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
      return self.class.new(matrix, typecode) if shape.length == 0
      as_na = NArray.to_na(
        matrix.each.map do |elm|
          yield elm
        end
      ).to_type(typecode)
      self.class.new(as_na.reshape(*shape), typecode)
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

    def self.identity(size)
      blank = self.blank(rows: size, columns: size)
      blank.diagonal(1)
    end

    def self.ones(rows: 1, columns: 1)
      self.blank(rows: rows, columns: columns, initial: 1)
    end

    def sum_rows
      sum(1)
    end

    def sum_columns
      sum(0)
    end

    def concat(*others, rows: true)
      others.map!{|o| Matrix === o ? o.narray : NArray.to_na(o)}

      joined = case rows
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

      Matrix.new(joined, typecode)
    end

    def join(other)
      case true
      when self.rows == 1 && other.rows == 1
        self.class.new(NArray.to_na([self.narray,other.narray]).to_type(self.typecode).reshape(self.columns + other.columns, 1))
      when self.columns == 1 && other.columns == 1
        self.class.new(NArray.to_na([self.narray,other.narray]).to_type(self.typecode).reshape(1, self.rows + other.rows))
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
        self.class.new(apply_scalar(:*, other), typecode)
      end
    end

    def mult(other)
      self.class.new(self.narray * other.narray, typecode)
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

    def to_significant_figures(x, p)
      ("%-.#{p}e" % x).gsub(/0+e/,'e').gsub('.e+00','').gsub('e+00','')
    end

    def inspect(sz: 10, sig: 6, names: RMatrix::Matrix.named_inspect)
      desc = case
      when self.is_vector? then "Vector(#{self.length})"
      else "Matrix(#{rows} x #{columns})"
      end
      "#{desc}\n#{RMatrix::MatrixTable.new(self).to_s}"
    end

    def to_tex(sz = 10, sig=6)
      values = condensed(sz, sig)
      column_headers = column_label_map ? values[0].map.with_index do |v, i|
        case v
        when '\\cdots' then '\\cdots'
        else (column_label_map && column_label_map[i]) || i
        end
      end : []

      row_headers = row_label_map ? values.map.with_index do |v, i|
        case v[0]
        when '\\vdots' then '\\vdots'
        else (row_label_map && row_label_map[i]) || i
        end
      end : []

      <<-TEX
$
\\begin{array}{c} &
\\begin{array}{c} #{column_headers.join(" & ")} \\end{array}\\\\
\\begin{array}{c} #{row_headers.join(" \\\\ ")} \\end{array} &
  \\left(\\begin{array}{ccc}
    #{values.map{|line| line.join(" & ")}.join(" \\\\ ")}
  \\end{array}\\right)
\\end{array}
$
TEX
    end

    def condensed(sz=10, sig=6, vdots='\\vdots', cdots='\\cdots', ddots='\\ddots')
      width  = [sz, self.cols].min
      height = [sz, self.rows].min
      insert_cdots = self.cols > sz
      insert_vdots = self.rows > sz

      width  += 1 if insert_cdots
      height += 1 if insert_vdots

      blank = M.blank(rows: height, columns: width, typecode: Typecode::OBJECT)
      blank.narray[0...width, 0...height] = self.narray[0...width, 0...height]

      blank.narray[0...width, -1] = self.narray[0...width, -1]
      blank.narray[-1,0...height] = self.narray[-1, 0...height]

      blank.narray[0...width, -2] = vdots if insert_vdots
      blank.narray[-2, 0...height] = cdots if insert_cdots

      if insert_cdots && insert_vdots
        blank.narray[-2, -2] = ddots
        blank.narray[-1, -2] = vdots
        blank.narray[-2, -1] = cdots
        blank.narray[-1, -1] = self.narray[-1, -1]
      end

      blank.narray.to_a.map{|line| (sig ? Array(line).map{|v| Numeric === v ? to_significant_figures(v,sig) : v } : Array(line))}
    end

    def transpose()
      Matrix.new(self.matrix.transpose, typecode, column_map: self.row_map, row_map: self.column_map, column_label_map: self.row_label_map, row_label_map: self.column_label_map)
    end

    def self.[](*inputs, typecode: Typecode::FLOAT, row_map: nil, column_map: nil, column_label_map: nil, row_label_map: nil)
      if inputs.length == 1 && Matrix === inputs[0]
        inputs[0]
      elsif inputs.length == 1 && [String, Symbol].include?(inputs[0].class)
        if ['byte', 'sint', 'int', 'sfloat', 'float', 'scomplex', 'complex', 'object'].include?(inputs[0])
          ->(*source){ Matrix.new(source, inputs[0], row_map: row_map, column_map: column_map, row_label_map: row_label_map, column_label_map: column_label_map)}
        else
          Matrix.new(inputs[0], typecode, row_map: row_map, column_map: column_map, row_label_map: row_label_map, column_label_map: column_label_map)
        end
      else
        Matrix.new(inputs, typecode, row_map: row_map, column_map: column_map, row_label_map: row_label_map, column_label_map: column_label_map)
      end
    end

    def zip(*others)
      Matrix.new(super(*others), self.typecode)
    end

    def self.gen_mutator(name)
      define_method(name) do |*args, &blk|
        matrix.send(name, *args, &blk)
        self
      end
    end

    def self.gen_vec_or_matrix_delegator(name)
      define_method(name) do |*args, &blk|
        case self
        when Vector then Vector.new(matrix.send(name, *args, &blk), typecode)
        when Matrix then Matrix.new(matrix.send(name, *args, &blk), typecode)
        end
      end
    end

    def self.gen_matrix_delegator(name)
      define_method(name) do |*args, &blk|
        Matrix.new(matrix.send(name, *args, &blk), typecode)
      end
    end

    def sum(dim=nil)
      case dim
      when nil then
        res = self.narray.sum
        NArray === res ? Matrix.new(0, typecode)[0] : res
      else Matrix.new(self.matrix.sum(dim), typecode)
      end
    end

    def to_type(type)
      self.class.new(narray.to_type(type), type)
    end

    def self.gen_delegator(name)
      define_method(name) do |*args, &blk|
        result = matrix.send(name, *args, &blk)
        case result
        when NArray then Matrix.new(result, typecode)
        else result
        end
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
    [:reshape, :inverse, :lu, :diagonal, :conjugate].each(&method(:gen_matrix_delegator))
    [:sort, :sort_index, :delete_at, :where, :where2, :not, :-@, :reverse].each(&method(:gen_vec_or_matrix_delegator))
    [:prod, :min, :max, :stddev, :mean, :rms, :rmsdev, :shape, :empty?].each(&method(:gen_delegator))
    [:byte, :sint, :int, :sfloat, :float, :scomplex, :complex, :object].each(&method(:gen_typeconstructor))
    [:+, :/, :-, :**, :&, :^, :|].each do |_op|
      op = translate_op(_op)
      define_method(_op) do |other|
        result = case other
        when Matrix
          apply_elementwise(op, other)
        else
          apply_scalar(op, other)
        end
        self.class.new(
          result, typecode
        )
      end
    end

    def to_a
      return narray.to_a
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
RMatrix::Matrix.named_inspect = true