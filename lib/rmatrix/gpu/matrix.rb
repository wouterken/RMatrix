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
  end
end