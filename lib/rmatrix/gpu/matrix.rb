module RMatrix
  class GPU::Matrix
    attr_accessor :source
    def initialize(source)
      self.source = source
    end

    def method_missing(name, *args)
      puts "No GPU compatible delegate for #{name}. Forwarding to source"
      source.send(Arch.cpu(name), *args)
    end

    def narray
      source.narray
    end

    def gpu_buffer
      source.gpu_buffer
    end

    def typecode
      narray.typecode
    end

    def rows
      narray.shape[1]
    end

    def cols
      narray.shape[0]
    end

    def size
      rows * cols
    end



    def +(other)
      RMatrix::Matrix.new(GPU.run_program(:+, self, other))
    end

    def -(other)
      RMatrix::Matrix.new(GPU.run_program(:-, self, other))
    end

    def *(other)
      RMatrix::Matrix.new(GPU.matrix_mult(self, other))
    end

    def mult(other)
      RMatrix::Matrix.new(GPU.run_program(:mult, self, other))
    end
  end
end