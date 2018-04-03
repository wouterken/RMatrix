module RMatrix
  module Random
    module ClassMethods
      def normal
      end

      def uniform(n=10,low: 0.0,high: 1.0)
        M.blank(columns: n).generate do
          ::Random.rand(low..high.to_f)
        end
      end

      def normal(n=10,low: 0.0,high: 1.0)
        spread = high - low
        M.blank(columns: n, rows: 6).random!.*(spread).+(low).avg(1)
      end

      def binomial
      end
    end

    def generate(n=50, initial=nil)
      length.times do |i|
        self[i] = block_given? ?
          yield(i.zero? ? initial : self[i - 1], i, ->(idx){self[idx]}) :
          ::Random.rand(0..10)
      end
      self
    end

    def self.included(base)
      base.extend ClassMethods
    end
  end
end