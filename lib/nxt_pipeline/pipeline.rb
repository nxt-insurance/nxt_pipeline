module NxtPipeline
  class Pipeline
    attr_reader :burst_segment

    def initialize(*attrs)
      extract_pipe_attr_from_init_params(*attrs)
    end

    def call
      self.segments.reduce(pipe_attr) do |transformed_pipe_attr, segment|
        segment[pipe_attr_name].new(pipe_attr_name => transformed_pipe_attr).pipe_through
      rescue => error
        handle_segment_burst(error, segment)
      end
    end

    def burst?
      burst_segment.present?
    end

    class << self
      def pipe_attr(name)
        self.pipe_attr_name = name
      end

      def mount_segment(name)
        self.segments << name
      end

      def rescue_segment_burst(*errors, &block)
        self.rescueable_segment_bursts = errors
        self.rescueable_block = block
      end
    end

    private

    attr_reader :pipe_attr

    cattr_accessor :pipe_attr_name
    cattr_accessor :segments, instance_writer: false, default: []
    cattr_accessor :rescueable_segment_bursts, instance_writer: false, default: []
    cattr_accessor :rescueable_block, instance_writer: false

    def extract_pipe_attr_from_init_params(*attrs)
      raise ArgumentError, 'You need to pass a keyword param as argument to #new' unless attrs.first.is_a?(Hash)
      @pipe_attr = attrs.first.fetch(pipe_attr_name)
    end

    def handle_segment_burst(error, segment)
      @burst_segment = segment.name.split('::').last.underscore

      self.rescueable_block.call(error, burst_segment) if error.class.in?(rescueable_segment_bursts)

      raise
    end
  end
end
