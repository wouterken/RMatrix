module RMatrix
  module Indices
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
  end
end