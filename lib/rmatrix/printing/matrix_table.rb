require 'rmatrix/printing/print_table'

module RMatrix
  class MatrixTable < PrintTable
    def initialize(matrix, max_columns: 10, max_rows: 10)
      super()
      column_offset, row_offset = 0, 0
      column_labels = !!matrix.column_label_map
      row_labels    = !!matrix.row_label_map

      printed_rows = [matrix.rows, max_rows].min
      printed_columns = [matrix.columns, max_columns].min

      if matrix.column_label_map
        printed_columns.times do |i|
          column_label = matrix.column_label_map[i]
          if column_label
            self[i+1 + (row_labels ? 1 : 0 ), 0] = column_label.inspect
          end
        end
        row_offset += 1
      end

      if matrix.row_label_map
        printed_rows.times do |i|
          row_label = matrix.row_label_map[i]
          if row_label
            self[0, i + (column_labels ?  1 : 0)] = row_label.inspect
          end
        end
        column_offset += 1
      end


      self[column_offset,row_offset] = "#{matrix.is_vector? ? 'V' : 'M'}["
      column_offset += 1
      matrix.each_row.with_index do |row, row_idx|
        break if row_idx > printed_rows
        row.each.with_index do |cell, column_idx|
          break if column_idx > printed_columns
          self[column_idx + column_offset, row_idx + row_offset] = cell
        end
        self[[matrix.columns + column_offset, printed_columns + column_offset + 1].min, row_idx + row_offset] = ',' if (row_idx + row_offset - 1) != printed_rows
      end

      column_overlap = matrix.columns > max_columns
      row_overlap    = matrix.rows    > max_rows
      both_overlap   = column_overlap && row_overlap

      if column_overlap
        printed_rows.times do |row|
          self[max_columns + column_offset - 1, row + row_offset] = '…'
          self[max_columns + column_offset, row + row_offset] = matrix.raw[row, -1]
        end
      end

      if row_overlap
        printed_columns.times do |column|
          self[column + column_offset, max_rows + row_offset - 1] = '⋮'
          self[column + column_offset, max_rows + row_offset] = matrix.raw[-1, column]
        end
      end

      if both_overlap
        self[printed_columns + column_offset - 1, printed_rows + row_offset - 1] = "⋱"
        self[printed_columns + column_offset - 1, printed_rows + row_offset] = '⋮'
        self[printed_columns + column_offset, printed_rows + row_offset - 1] = '…'
        self[printed_columns + column_offset, printed_rows + row_offset]     = matrix.raw[-1, -1]
      end

      self[self.column_count - 1, self.row_count - 1] = ']'

      if row_labels
        self.set_column_separator( 0, ' ')
        self.set_column_separator( 1, '[')
        self.set_column_separator(self.column_count - 1, ']')
      else
        self.set_column_separator( 0, '[')
        self.set_column_separator(self.column_count - 2, ']')
      end

      self.set_column_separator(self.column_count - 2, ']')
    end
  end

end