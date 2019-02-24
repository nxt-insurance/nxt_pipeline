module NxtPipeline
  class Pipeline
    def initialize(*attrs)
      extract_pipe_attr_from_init_params(*attrs)
    end

    def call
      self.segments.reduce(pipe_attr) do |transformed_pipe_attr, segment|
        segment[pipe_attr_name].new(pipe_attr_name => transformed_pipe_attr).pipe_through
      end
    end

    class << self
      def pipe_attr(name)
        self.pipe_attr_name = name
      end

      def mount_segment(name)
        self.segments << name
      end
    end

    private

    attr_reader :pipe_attr

    cattr_accessor :pipe_attr_name
    cattr_accessor :segments, instance_writer: false, default: []

    def extract_pipe_attr_from_init_params(*attrs)
      raise ArgumentError, 'You need to pass a keyword param as argument to #new' unless attrs.first.is_a?(Hash)
      @pipe_attr = attrs.first.fetch(pipe_attr_name)
    end
  end
end
