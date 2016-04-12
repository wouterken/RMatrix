module RMatrix
  module GPU
    require_relative "matrix"
    extend self

    def load_platform(n=0)
      @@platform =OpenCLL::platforms[n]
    end

    def load_device(n=0)
      @@device = platform.devices[n]
    end

    def platform
      @@platform || load_platform
    end

    def device
      @@device || load_device
    end

    def context
      @context ||= OpenCL::create_context(device)
    end

    def execute_within_gpu
      @@execute_within_gpu
    end

    def execute_within_gpu=(val)
      @@execute_within_gpu=val
    end

    def gpu_exec_state
      @@gpu_exec_state ||= []
    end

    def create_buffer(na, copy: true)
      if copy
        context.create_buffer(size * na.element_size, flags: OpenCL::Mem::COPY_HOST_PTR, host_ptr: na)
      else
        context.create_buffer(na.size * na.element_size)
      end
    end

    def build_program(source)
      context.create_program_with_source(source).tap(&:build)
    end

    def exec
      self.gpu_exec_state << self.execute_within_gpu
      self.execute_within_gpu = true
      yield
    ensure
      self.execute_within_gpu = self.gpu_exec_state.pop
    end

    self.execute_within_gpu = false
  end
end