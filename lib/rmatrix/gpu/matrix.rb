module RMatrix
  class GPU::Matrix
    attr_accessor :rmatrix, :gpu_buffer, :narray, :typecode, :rows, :cols
    def initialize(rmatrix: nil, narray: nil)
      if rmatrix
        self.rmatrix    = rmatrix
        self.gpu_buffer = rmatrix.gpu_buffer
        self.narray     = rmatrix.narray
        self.typecode   = self.narray.typecode
        self.rows       = self.narray.shape[1]
        self.cols       = self.narray.shape[0]
      else
        self.rmatrix    = nil
        self.narray     = narray
        self.gpu_buffer = GPU::buffer(self.narray, copy: false)
        self.typecode   = narray.typecode
        self.rows       = self.narray.shape[1]
        self.cols       = self.narray.shape[0]
      end
    end

    def to_m
      self.rmatrix ||= RMatrix::Matrix.new(self.narray)
    end

    def to_ary
      [self]
    end

    def enqueue_read(*events)
      GPU::queue.enqueue_read_buffer(self.gpu_buffer, self.narray, :event_wait_list => events)
    end

    def method_missing(name, *args)
      to_m.send(Arch.cpu(name), *args)
    end

    def size
      rows * cols
    end

    def +(other)
      GPU.run_program(:+, self, other)
    end

    def -(other)
      GPU.run_program(:-, self, other)
    end

    def *(other)
      GPU.matrix_mult(self, other)
    end

    def mult(other)
      GPU.run_program(:mult, self, other)
    end
  end
end