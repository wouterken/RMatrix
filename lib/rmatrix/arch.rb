module RMatrix
  module Arch
    CPU = :cpu_
    GPU = :gpu_

    def self.arch_name(method_arch, method_name)
      @@arch_names ||= Hash.new{|names,arch_name| names[arch_name] = Hash.new{|arch, name| arch[name] = "#{arch}#{name}"}}
      @@arch_names[method_arch][method_name]
    end

    def self.cpu(method_name)
      arch_name(Arch::CPU, method_name)
    end
  end
end