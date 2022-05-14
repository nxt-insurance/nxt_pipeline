RSpec.describe NxtPipeline::Pipeline do
  class StepOne
    def initialize(word:)
      @word = word
    end

    attr_reader :word, :operation

    def call
      word.upcase
    end
  end

  class StepSkipped < StepOne
    def call
      nil
    end
  end

  class StepWithArgumentError < StepOne
    def call
      raise ArgumentError, 'This is not a fish'
    end
  end

  CustomError = Class.new(ArgumentError)
  OtherCustomError = Class.new(CustomError)

  context 'when there are no errors' do
    subject do
      NxtPipeline.new do |pipeline|
        pipeline.constructor(:service) do |word, step|
          step.to_s = step.argument.name
          step.argument.new(word: word).call
        end

        pipeline.step StepOne, constructor: :service
        pipeline.step StepSkipped, constructor: :service
      end
    end

    it 'indexes the steps' do
      expect(subject.steps.find { |s| s.argument == StepOne }.index).to eq(0)
      expect(subject.steps.find { |s| s.argument == StepSkipped }.index).to eq(1)
    end

    it 'executes the steps' do
      expect(subject.call('hanna')).to eq('HANNA')
    end

    it 'remembers the results of the steps on the steps' do
      subject.call('hanna')

      expect(subject.steps.first.result).to eq('HANNA')
      expect(subject.steps.second.result).to be_nil
    end

    it 'logs the steps' do
      subject.call('hanna')

      expect(subject.logger.log).to eq({"StepOne"=>:success, "StepSkipped"=>:skipped})
    end
  end

  context 'when registering the same step multiple times' do
    it 'raises an error' do
      expect {
        NxtPipeline::Pipeline.new do |pipeline|
          pipeline.constructor(:service) do |step, word:|
            step.service_class.new(word: word).call
          end

          pipeline.constructor(:service) do |step, word:|
            step.service_class.new(word: word).call
          end
        end
      }.to raise_error(StandardError, 'Already registered step :service')
    end
  end

  context 'when there is an error' do
    subject do
      NxtPipeline.new do |pipeline|
        pipeline.constructor(:service, default: true) do |acc, step|
          step.name = step.argument.to_s
          step.argument.new(word: acc).call
        end

        pipeline.step StepOne
        pipeline.step StepSkipped, to_s: 'This step was skipped'
        pipeline.step StepWithArgumentError

        pipeline.on_error ArgumentError do |opts, step, error|
          "Step #{step} was called with #{opts} and failed with #{error.class}"
        end

        pipeline.on_error do |step, opts, error|
          raise error
        end
      end
    end

    it 'executes the callback' do
      expect(subject.call('hanna')).to eq('Step StepWithArgumentError was called with HANNA and failed with ArgumentError')
    end

    it 'logs the steps' do
      subject.call('hanna')

      expect(subject.logger.log).to eq(
        "StepOne" => :success,
        "This step was skipped" => :skipped,
        "StepWithArgumentError" => :failed
      )
    end

    it 'sets the status of the steps' do
      subject.call('hanna')
      expect(subject.steps.map(&:status)).to eq(%i[success skipped failed])
    end

    it 'sets execution_started_at on all steps' do
      subject.call('hanna')
      expect(subject.steps.map(&:execution_started_at)).to all(be_present)
    end

    it 'sets execution_finished_at on all steps' do
      subject.call('hanna')
      expect(subject.steps.map(&:execution_finished_at)).to all(be_present)
    end

    it 'sets execution_duration on all steps' do
      subject.call('hanna')
      expect(subject.steps.map(&:execution_duration)).to all(be_present)
    end

    it 'remembers the error on the step' do
      subject.call('hanna')

      expect(subject.steps.map(&:error)).to match([nil, nil, be_a(ArgumentError)])
    end

    it 'adds methods to the error' do
      subject.call('hanna')
      argument_error = subject.steps.map(&:error).last
      expect(argument_error.details.logger).to eq(subject.logger)
      expect(argument_error.details.step.to_s).to eq('StepWithArgumentError')
      expect(argument_error.details.change_set).to eq("HANNA")
    end
  end

  context 'error callbacks' do
    subject do
      NxtPipeline::Pipeline.new do |pipeline|
        pipeline.constructor(:error_test) do |error, step|
          step.raisor.call(error)
        end

        pipeline.step :error_test, raisor: -> (error) { raise error }

        pipeline.on_error OtherCustomError do |opts, step, error|
          'other_custom_error callback fired'
        end

        pipeline.on_error CustomError do |opts, step, error|
          'custom_error callback fired'
        end

        pipeline.on_error do |opts, step, error|
          'all errors inheriting from standard error callback fired'
        end
      end
    end

    it 'executes the first matching callback' do
      expect(subject.call(OtherCustomError)).to eq('other_custom_error callback fired')
      expect(subject.call(CustomError)).to eq('custom_error callback fired')
      expect(subject.call(ArgumentError)).to eq('all errors inheriting from standard error callback fired')
    end

    context 'when the more common handler was registered before the more specific handler' do
      subject do
        NxtPipeline::Pipeline.new do |pipeline|
          pipeline.constructor(:error_test) do |error, step|
            step.raisor.call(error)
          end

          pipeline.step :error_test, raisor: -> (error) { raise error }

          pipeline.on_error CustomError do |*args|
            'custom_error callback fired'
          end

          pipeline.on_error OtherCustomError do |*args|
            'other_custom_error callback fired'
          end

          pipeline.on_error do |step, arg, error|
            raise error
          end
        end
      end

      it 'executes the first matching callback' do
        expect(subject.call(OtherCustomError)).to eq('custom_error callback fired')
        expect(subject.call(CustomError)).to eq('custom_error callback fired')
        expect { subject.call(ArgumentError) }.to raise_error(ArgumentError)
      end
    end

    context 'when one handler was registered for multiple errors' do
      subject do
        NxtPipeline::Pipeline.new do |pipeline|
          pipeline.constructor(:error_test) do |error, step|
            step.raisor.call(error)
          end

          pipeline.step :error_test, raisor: -> (error) { raise error }

          pipeline.on_errors CustomError, OtherCustomError do |opts, step, error|
            'common callback fired'
          end

          pipeline.on_error do |opts, step, error|
            raise error
          end
        end
      end

      it 'triggers the handler for all errors' do
        expect(subject.call(CustomError)).to eq('common callback fired')
        expect(subject.call(OtherCustomError)).to eq('common callback fired')
        expect { subject.call(ArgumentError) }.to raise_error(ArgumentError)
      end
    end

    context 'when a handler was configured not to halt the pipeline' do
      subject do
        NxtPipeline::Pipeline.new do |pipeline|
          pipeline.step :upcase do |word|
            word.upcase
          end

          pipeline.step :raisor do |word|
            raise ArgumentError
          end

          pipeline.step :reverse do |word|
            word.reverse
          end

          pipeline.on_error ArgumentError, halt_on_error: false do |opts, step, error|
            'Error handler which does not halt the pipeline'
          end
        end
      end

      it 'executes both steps' do
        expect(subject.call('hello')).to eq("OLLEH")
        expect(subject.logger.log).to eq(
          'upcase' => :success,
          'raisor' => :failed,
          'reverse' => :success
        )
      end
    end
  end

  context 'with different kinds of steps registered' do
    subject do
      NxtPipeline::Pipeline.new do |pipeline|
        pipeline.constructor(:service) do |acc, step|
          step.transformer.call(acc)
        end

        pipeline.constructor(:other) do |acc, step|
          step.splitter.call(acc)
        end

        pipeline.step :service, transformer: -> (arg) { arg.upcase }
        pipeline.step :other, splitter: -> (arg) { arg.chars.join('_') }
        pipeline.step :service, transformer: -> (arg) { (arg.chars + %w[_] + arg.chars).join }
      end
    end

    it 'executes the steps' do
      expect(subject.call('hanna')).to eq('H_A_N_N_A_H_A_N_N_A')
    end

    it 'assigns the correct arguments' do
      expect(subject.steps.map(&:argument)).to eq(%i[service other service])
    end
  end

  context 'default step' do
    subject do
      NxtPipeline::Pipeline.new do |pipeline|
        pipeline.constructor(:proc, default: true) do |acc, step|
          step.transformer.call(acc)
        end

        pipeline.step :upcase, transformer: -> (arg) { arg.upcase }
        pipeline.step :join, transformer: -> (arg) { arg.chars.join('_') }
      end
    end

    it 'executes the steps' do
      expect(subject.call('hanna')).to eq('H_A_N_N_A')
    end

    context 'when defined multiple times' do
      it 'raises an error' do
        expect {
          NxtPipeline::Pipeline.new do |pipeline|
            pipeline.constructor(:proc, default: true) do |acc, step|
              step.transformer.call(acc)
            end

            pipeline.constructor(:lambda, default: true) do |acc, step|
              step.transformer.call(acc)
            end
          end
        }.to raise_error(ArgumentError, 'Default step already defined')
      end
    end
  end

  context 'steps with blocks' do
    subject do
      NxtPipeline::Pipeline.new do |pipeline|
        pipeline.step :first_step do |arg|
          arg.upcase
        end

        pipeline.step :second_step do |arg|
          arg.chars.join('_')
        end
      end
    end

    it 'executes the steps' do
      expect(subject.call('hanna')).to eq('H_A_N_N_A')
    end

    it 'logs the steps' do
      subject.call('hanna')
      # fallback to type :inline for inline constructors without type
      expect(subject.logger.log).to eq('first_step' => :success, 'second_step' => :success)
    end

    it 'logs the result for each step' do
      subject.call('hanna')

      expect(subject.steps.find { |s| s.argument == :first_step }.result).to eq('HANNA')
      expect(subject.steps.find { |s| s.argument == :second_step }.result).to eq('H_A_N_N_A')
    end

    context 'when :to_s option was provided' do
      before do
        subject.configure do |p|
          p.step 'Argument', to_s: 'What is my name' do |step, arg:|
            arg.prepend('My name is: ')
          end
        end
      end

      it 'does not use the type as :to_s option' do
        expect(subject.steps.last.to_s).to eq('What is my name')
      end
    end
  end

  context 'when the argument responds to call' do
    subject do
      def times_two(arg)
        arg * 2
      end

      NxtPipeline::Pipeline.new do |pipeline|
        pipeline.constructor(:test, default: true) do |arg, step|
          step.argument.call(arg)
        end

        pipeline.step -> (arg) { arg.upcase }
        pipeline.step -> (arg) { arg.chars.join('_') }
        pipeline.step method(:times_two)
      end
    end

    it 'executes the steps' do
      expect(subject.call('hanna')).to eq('H_A_N_N_AH_A_N_N_A')
    end

    it 'logs the steps' do
      subject.call('hanna')
      expect(subject.logger.log).to eq('0' => :success, '1' => :success, '2' => :success)
    end
  end

  context 'when used inside a class' do
    class Transformer
      def initialize(string)
        @string = string
      end

      def call
        pipeline.call(@string)
      end

      def pipeline
        NxtPipeline::Pipeline.new do |pipeline|
          pipeline.step :upcase do |arg|
            transform_upcase(arg)
          end
        end
      end

      def transform_upcase(string)
        string.upcase
      end
    end

    subject do
      Transformer.new('hanna').call
    end

    it 'can access the methods in the scope' do
      expect(subject).to eq('HANNA')
    end
  end

  context 'logger' do
    class CustomLogger
      def call(step)
        log << step.to_s
      end

      def log
        @log ||= []
      end
    end

    subject do
      NxtPipeline::Pipeline.new do |pipeline|
        pipeline.constructor(:adder) do |number, step|
          step.argument.call(number)
        end

        pipeline.constructor(:multiplier) do |number, step|
          step.argument.call(number)
        end

        pipeline.step :adder do |number|
          number + 1
        end

        pipeline.step -> (number) { number * 2 }, constructor: :multiplier, to_s: :multiplier
        pipeline.step -> (number) { number + 2 }, constructor: :adder, to_s: :adder

        pipeline.step :inline do |number|
          number * 3
        end

        pipeline.step :last_step do |number|
          number - 5
        end

        pipeline.logger = CustomLogger.new
      end
    end

    it 'logs the step with the custom logger' do
      expect(subject.call(5)).to eq(37)
      expect(subject.logger.log).to eq(["adder", 'multiplier', 'adder', "inline", "last_step"])
    end
  end

  describe '#configure' do
    subject { NxtPipeline::Pipeline.new }

    before do
      subject.configure do |pipeline|
        pipeline.step :transformer, method: :upcase do |acc, step|
          acc.send(step.method)
        end
      end
    end

    it 'configures the pipeline' do
      expect(subject.call('hanna')).to eq('HANNA')
    end

    it 'returns itself' do
      expect(subject.configure do |pipeline|
        pipeline.step :transformer, method: :upcase do |arg, step|
          arg.send(step.method)
        end
      end).to eq(subject)
    end
  end

  describe '.call' do
    subject do
      NxtPipeline.call('hanna') do |pipeline|
        pipeline.step :test do |acc|
          acc.upcase
        end
      end
    end

    it 'executes the steps directly' do
      expect(subject).to eq('HANNA')
    end
  end
end
