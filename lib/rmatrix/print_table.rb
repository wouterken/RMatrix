module RMatrix
  class PrintTable
    attr_accessor :row_count, :column_count, :cells, :column_justifications, :separators
    def initialize
      self.row_count = self.column_count = 0
      self.cells = {}
      self.column_justifications = {}
      self.separators = Hash.new(', ')
    end

    def to_s
      widths = self.column_widths
      self.row_count.times.map do |row|
        self.column_count.times.flat_map do |column|
          cell_text = cell_repr(self.cells[[column, row]])
          justification = column_justification(column)
          width = widths[column]
          contents = case justification
          when :left  then cell_text.ljust(width)
          when :right then cell_text.rjust(width)
          end
          [contents,self.separators[[column, row]]]
        end[0...-1].join
      end.join("\n")
    end

    def to_tex
      tex_map = self.row_count.times.map do |row|
        self.column_count.times.map do |column|
          cell_repr(self.cells[[column, row]])
        end
      end
      <<-TEX
\\[
  \\text{Mat}_{\\varphi\\text{ to }M} = \\kbordermatrix{
    & c_1 & c_2 & c_3 & c_4 & c_5 \\\\
    r_1 & 1 & 1 & 1 & 1 & 1 \\\\
    r_2 & 0 & 1 & 0 & 0 & 1 \\\\
    r_3 & 0 & 0 & 1 & 0 & 1 \\\\
    r_4 & 0 & 0 & 0 & 1 & 1 \\\\
    r_5 & 0 & 0 & 0 & 0 & 1
  }
\\]
TEX
    end

    def column_justification(i)
      case self.column_justifications[i]
      when nil then :right
      when :right then :right
      when :left then :left
      else raise "Unexpected justification for column #{self.column_justifications[i] }"
      end
    end

    def set_column_separator(column, separator)
      self.row_count.times do |row|
        self.separators[[column, row]] =  separator
      end
    end

    def column_widths
      column_count.times.map do |i|
        column_width(i)
      end
    end

    def column_width(column)
      self.row_count.times.reduce(0) do |agg, row|
        [agg, self.cell_repr(self.cells[[column, row]]).length].max
      end
    end

    def cell_repr(cell)
      case cell
      when nil then ''
      when Numeric then numeric_to_truncated_string(cell)
      else "#{cell}"
      end
    end

    def numeric_to_truncated_string(numeric)
      ("%-.4e" % numeric).gsub(/(?<!\.)0+e/,'e').gsub('.e+00','').gsub('e+00','')
    end

    def [](column, row)
      self.cells[[column, row]]
    end

    def []=(column, row, value)
      build_column!(column)
      build_row!(row)
      self.cells[[column, row]] = value
    end

    def build_column!(idx)
      self.column_count = [self.column_count || 0, idx.succ].max
    end

    def build_row!(idx)
      self.row_count = [self.row_count || 0 , idx.succ].max
    end
  end


end
require_relative 'matrix_table'
