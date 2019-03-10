module NxtPipeline
  class Pipeline
    include ActiveSupport::Callbacks
    define_callbacks :each_segment_pipe_through
    
    attr_reader :burst_segment

    def initialize(*attrs)
      extract_pipe_attr_from_init_params(*attrs)
    end

    def call
      self.class.segments.reduce(pipe_attr) do |transformed_pipe_attr, segment|
        run_callbacks :each_segment_pipe_through do
          segment[self.class.pipe_attr_name].new(self.class.pipe_attr_name => transformed_pipe_attr).pipe_through
        rescue => error
          handle_segment_burst(error, segment)
        end
      end
    end

    def burst?
      burst_segment.present?
    end

    class << self
      def pipe_attr(name)
        @pipe_attr_name = name
      end

      def mount_segment(name)
        self.segments << name
      end

      def rescue_segment_burst(*errors, &block)
        @rescueable_segment_bursts = errors
        self.rescueable_block = block
      end
      
      def before_each_segment(*filters, &block)
        set_callback :each_segment_pipe_through, :before, *filters, &block
      end
      
      def after_each_segment(*filters, &block)
        set_callback :each_segment_pipe_through, :after, *filters, &block
      end
      
      def around_each_segment(*filters, &block)
        set_callback :each_segment_pipe_through, :around, *filters, &block
      end
      
      attr_reader :pipe_attr_name
      attr_accessor :rescueable_block
      
      def segments
        @segments ||= []
      end
      
      def rescueable_segment_bursts
        @rescueable_segment_bursts ||= []
      end
    end

    private

    attr_reader :pipe_attr

    def extract_pipe_attr_from_init_params(*attrs)
      raise ArgumentError, 'You need to pass a keyword param as argument to #new' unless attrs.first.is_a?(Hash)
      @pipe_attr = attrs.first.fetch(self.class.pipe_attr_name)
    end

    def handle_segment_burst(error, segment)
      @burst_segment = segment.name.split('::').last.underscore

      self.class.rescueable_block.call(error, burst_segment) if error.class.in?(self.class.rescueable_segment_bursts)

      raise
    end
  end
end
