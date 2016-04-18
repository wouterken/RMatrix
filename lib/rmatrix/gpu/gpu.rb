module RMatrix
  module GPU
    require_relative "matrix"
    require 'opencl_ruby_ffi'
    extend self

    def load_platform(n=0)
      @platform =OpenCL::platforms[n]
    end

    def load_device(n=0)
      @device = platform.devices[n]
    end

    def platform
      @platform || load_platform
    end

    def device
      @device || load_device
    end

    def context
      @context ||= OpenCL::create_context(device)
    end

    def execute_within_gpu
      @execute_within_gpu
    end

    def execute_within_gpu=(val)
      @execute_within_gpu=val
    end

    def gpu_exec_state
      @gpu_exec_state ||= []
    end

    def queue
      @queue ||= context.create_command_queue(device)
    end

    def buffer(na, copy: true)
      if copy
        context.create_buffer(na.size * na.element_size, flags: OpenCL::Mem::COPY_HOST_PTR, host_ptr: na)
      else
        context.create_buffer(na.size * na.element_size)
      end
    end

    def build_program(source)
      context.create_program_with_source(source).tap(&:build)
    end

    def run_program(name, *inputs)
      puts "Matrix #{name}"
      prog, entry   = GPU::PROGRAMS[name].values
      input_buffers = inputs.map(&:gpu_buffer)
      largest       = inputs.max_by{|input| input.narray.size }
      output        = NArray.new(
        inputs.first.narray.typecode,
        *largest.narray.shape
      )
      buffer_output = GPU::buffer(output, copy: false)
      event = prog.send(entry, GPU::queue, [largest.narray.size], *input_buffers, buffer_output)
      GPU::queue.enqueue_read_buffer(buffer_output, output, :event_wait_list => [event])
      output
    end

    def matrix_mult(left, right)
      prog, entry       = GPU::PROGRAMS[:matrix_mult].values
      input_buffers     = [left, right].map(&:gpu_buffer)
      output_dimensions = [left.narray.shape[1], right.narray.shape[0]]
      output            = NArray.new(left.narray.typecode, *output_dimensions.reverse)
      buffer_output     = GPU::buffer(output, copy: false)
      event             = prog.send(entry, GPU::queue, output_dimensions.reverse, buffer_output, *input_buffers, OpenCL::Int.new(left.narray.shape[0]), OpenCL::Int.new(right.narray.shape[0]))
      GPU::queue.enqueue_read_buffer(buffer_output, output, :event_wait_list => [event])
      output
    end

    def exec
      self.gpu_exec_state << self.execute_within_gpu
      self.execute_within_gpu = true
      result = yield
      queue.finish
      result
    ensure
      self.execute_within_gpu = self.gpu_exec_state.pop
    end
    self.execute_within_gpu = false
  end
end

module RMatrix::GPU
  PROGRAMS = {
    :+ => {
      source: self.build_program(IO.read(File.expand_path(File.dirname(__FILE__)+"/kernels/addition.cl"))),
      entry: :addition
    },
    :mult => {
      source: self.build_program(IO.read(File.expand_path(File.dirname(__FILE__)+"/kernels/multiplication.cl"))),
      entry: :multiplication
    },
    :/ => {
      source: self.build_program(IO.read(File.expand_path(File.dirname(__FILE__)+"/kernels/division.cl"))),
      entry: :division
    },
    :- => {
      source: self.build_program(IO.read(File.expand_path(File.dirname(__FILE__)+"/kernels/subtraction.cl"))),
      entry: :subtraction
    },
    :matrix_mult => {
      source: self.build_program(IO.read(File.expand_path(File.dirname(__FILE__)+"/kernels/matrix_mult.cl"))),
      entry: :matrix_mult
    }
  }
end