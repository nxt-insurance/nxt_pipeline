RSpec.describe NxtPipeline::Pipeline do
  describe '#step_resovler' do
    class Transform
      def initialize(word, operation)
        @word = word
        @operation = operation
      end

      attr_reader :word, :operation

      def call
        word.send(operation)
      end
    end

    subject do
      NxtPipeline.new do |pipeline|
        # dynamically resolve to use a proc as constructor
        pipeline.constructor_resolver do |argument, **opts|
          argument.is_a?(Class) &&
            ->(acc, step) {
              step.argument.new(acc, opts.fetch(:operation)).call
            }
        end

        # dynamically resolve to a defined constructor
        pipeline.constructor_resolver do |argument, **opts|
          argument.is_a?(String) && :dynamic
        end

        pipeline.constructor(:dynamic) do |acc, step|
          if step.argument == 'multiply'
            acc * step.multiplier
          elsif step.argument == 'symbolize'
            acc.to_sym
          else
            raise ArgumentError, "Don't know how to deal with argument: #{step.argument}"
          end
        end

        pipeline.step Transform, operation: 'upcase'
        pipeline.step 'multiply', multiplier: 2
        pipeline.step 'symbolize'
        pipeline.step :extract_value do |acc|
          acc
        end
      end
    end

    it 'resolves the steps' do
      expect(subject.call('hanna')).to eq(:HANNAHANNA)
    end
  end
end
