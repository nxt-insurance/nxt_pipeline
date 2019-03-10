module NxtPipeline
  class Pipeline
    include ActiveSupport::Callbacks
    define_callbacks :each_step_pipe_through
    
    attr_reader :failed_step

    def initialize(*attrs)
      extract_pipe_attr_from_init_params(*attrs)
    end

    def run
      self.class.steps.reduce(pipe_attr) do |transformed_pipe_attr, step|
        run_callbacks :each_step_pipe_through do
          step[self.class.pipe_attr_name].new(self.class.pipe_attr_name => transformed_pipe_attr).pipe_through
        rescue => error
          handle_segment_burst(error, step)
        end
      end
    end

    def failed?
      failed_step.present?
    end

    class << self
      def pipe_attr(name)
        @pipe_attr_name = name
      end

      def step(name)
        self.steps << name
      end

      def rescue_errors(*errors, &block)
        @rescueable_errors = errors
        self.rescueable_block = block
      end
      
      def before_each_step(*filters, &block)
        set_callback :each_step_pipe_through, :before, *filters, &block
      end
      
      def after_each_step(*filters, &block)
        set_callback :each_step_pipe_through, :after, *filters, &block
      end
      
      def around_each_step(*filters, &block)
        set_callback :each_step_pipe_through, :around, *filters, &block
      end
      
      attr_reader :pipe_attr_name
      attr_accessor :rescueable_block
      
      def steps
        @steps ||= []
      end
      
      def rescueable_errors
        @rescueable_errors ||= []
      end
    end

    private

    attr_reader :pipe_attr

    def extract_pipe_attr_from_init_params(*attrs)
      raise ArgumentError, 'You need to pass a keyword param as argument to #new' unless attrs.first.is_a?(Hash)
      @pipe_attr = attrs.first.fetch(self.class.pipe_attr_name)
    end

    def handle_segment_burst(error, step)
      @failed_step = step.name.split('::').last.underscore

      self.class.rescueable_block.call(error, failed_step) if error.class.in?(self.class.rescueable_errors)

      raise
    end
  end
end
