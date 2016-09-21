module RMatrix
  module GPU
    require_relative "matrix"

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
      prog, entry   = GPU::PROGRAMS[name].values
      input_buffers = inputs.map(&:gpu_buffer)
      largest       = inputs.max_by{|input| input.narray.size }
      output        = GPU::Matrix.new(narray: NArray.new(
        inputs.first.narray.typecode,
        *largest.narray.shape
      ))
      prog.send(entry, GPU::queue, [largest.narray.size], *input_buffers, output.gpu_buffer)
      output
    end

    def matrix_mult(left, right)
      prog, entry       = GPU::PROGRAMS[:matrix_mult].values
      input_buffers     = [left, right].map(&:gpu_buffer)
      output_dimensions = [left.rows, right.cols]
      output            = GPU::Matrix.new(narray: NArray.new(left.narray.typecode, *output_dimensions.reverse))
      prog.send(entry, GPU::queue, output_dimensions.reverse, output.gpu_buffer, *input_buffers, OpenCL::Int.new(left.cols), OpenCL::Int.new(right.cols))
      output
    end

    def exec
      self.gpu_exec_state << self.execute_within_gpu
      self.execute_within_gpu = true
      *results = yield
      results.each(&:enqueue_read)
      queue.finish
      results.map(&:to_m)
    ensure
      self.execute_within_gpu = self.gpu_exec_state.pop
    end
    self.execute_within_gpu = false
  end
end

module RMatrix::GPU
  begin
    require 'opencl_ruby_ffi'
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
    LOADED = true
  rescue RuntimeError => e
    puts "OpenCL unavailable. Execute \"require 'opencl_ruby_ffi\" to diagnose"
    puts e
  end
end