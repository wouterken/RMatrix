module RMatrix
  module Indices

    def []=(*args, value)
      indices = unmap_args(args)
      raw[*indices] = value
    end

    def [](*args)
      indices           = unmap_args(args)
      result_row_map    = build_result_map(self.row_map, indices.first, self.rows)      if self.row_map
      result_column_map = build_result_map(self.column_map, indices.last, self.columns) if self.column_map

      row_indices, column_indices = indices

      result_column_label_map = nil
      result_row_label_map = nil

      if row_label_map
        case row_indices
        when true then result_row_label_map = row_label_map
        else
          result_row_label_map = walk_indices(row_indices, row_label_map).each_slice(2).to_h
        end
      end

      if column_label_map
        case column_indices
        when true then result_column_label_map = column_label_map
        else
          result_column_label_map = walk_indices(column_indices, column_label_map).each_slice(2).to_h
        end
      end

      raw[*indices, column_map: result_column_map, column_label_map: result_column_label_map, row_map: result_row_map, row_label_map: result_row_label_map]
    end

    def method_missing(name, *args, &block)
      if row_map && row_map.include?(name)
        self[name, true]
      elsif column_map && column_map.include?(name)
        self[true, name]
      else
        super
      end
    end

    def walk_indices(indices, parent, i={index: 0})
      Array(indices).flat_map do |index|
        res = case index
        when Array, Range then walk_indices(index.to_a, parent, i)
        else [i[:index], parent[index]]
        end
        i[:index] += 1
        res
      end
    end

    def raw
      @raw ||= begin
        raw = Struct.new(:narray, :typecode).new(self.narray, self.typecode)
        def raw.[](*args, column_map: nil, row_map: nil, row_label_map: nil, column_label_map: nil)
          begin
            args.all?{|x| Fixnum === x } ? narray[*args.reverse] : Matrix.new(narray[*args.reverse], typecode, column_map: column_map, row_map: row_map, row_label_map: row_label_map, column_label_map: column_label_map)
          rescue StandardError => e
            raise IndexError.new("Error accessing index at #{args}. Shape is #{narray.shape.reverse}")
          end
        end

        def raw.[]=(*args, value)
          narray[*args.reverse] = value
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
          return [Array(unmap_index(self.row_map, args[0])), true] rescue nil
        end
        if column_map
          return [true, Array(unmap_index(self.column_map, args[0]))] rescue nil
        end
        return [args[0]]
      else
        row_index    = self.row_map ? unmap_index(self.row_map, args[0]) : args[0]
        column_index = self.column_map ? unmap_index(self.column_map, args[1]) : args[1]
        column_index = [column_index] if column_index.kind_of?(Fixnum)
        [
          row_index,
          column_index
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
        index = (map[columns] rescue nil)
        index = columns if !index && columns.kind_of?(Fixnum)
        raise "Value not present in index mapping: #{columns}" unless index
        index
      end
    end
  end
end