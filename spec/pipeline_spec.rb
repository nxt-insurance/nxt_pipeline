RSpec.describe NxtPipeline do
  class StepOne
    def initialize(opts)
      @opts = opts
    end

    def call
      @opts.upcase
    end
  end

  class StepSkipped
    def initialize(opts)
      @opts = opts
    end

    def call
      nil
    end
  end

  class StepWithArgumentError
    def initialize(opts)
      @opts = opts
    end

    def call
      raise ArgumentError, 'This is not a fish'
    end
  end

  CustomError = Class.new(ArgumentError)
  OtherCustomError = Class.new(CustomError)

  context 'when there are no errors' do
    subject do
      NxtPipeline::Pipeline.new do |pipeline|
        pipeline.constructor(:service) do |step, arg|
          step.service_class.new(arg).call
        end

        pipeline.step :service,
                      service_class: StepOne

        pipeline.step :service,
                      service_class: StepSkipped
      end
    end

    it 'executes the steps' do
      expect(subject.execute('hanna')).to eq('HANNA')
    end
  end

  context 'when registering the same step multiple times' do
    it 'raises an error' do
      expect {
        NxtPipeline::Pipeline.new do |pipeline|
          pipeline.constructor(:service) do |step, arg|
            step.service_class.new(arg).call
          end

          pipeline.constructor(:service) do |step, arg|
            step.service_class.new(arg).call
          end
        end
      }.to raise_error(StandardError, 'Already registered step :service')
    end
  end

  context 'when there is an error' do
    subject do
      NxtPipeline::Pipeline.new do |pipeline|
        pipeline.constructor(:service) do |step, arg|
          step.service_class.new(arg).call
        end

        pipeline.step :service,
                      service_class: StepOne,
                      to_s: 'StepOne'

        pipeline.step :service,
                      service_class: StepSkipped,
                      to_s: 'StepSkipped'

        pipeline.step :service,
                      service_class: StepWithArgumentError,
                      to_s: 'StepWithArgumentError'

        pipeline.on_error ArgumentError do |step, arg, error|
          "Step #{step} was called with #{arg} and failed with #{error.class}"
        end

        pipeline.on_error do |step, arg, error|
          raise error
        end
      end
    end

    it 'executes the callback' do
      expect(subject.execute('hanna')).to eq('Step StepWithArgumentError was called with HANNA and failed with ArgumentError')
    end

    it 'logs the steps' do
      subject.execute('hanna')

      expect(subject.logger.log).to eq(
        "StepOne" => :success,
        "StepSkipped" => :skipped,
        "StepWithArgumentError" => :failed
      )
    end
  end

  context 'error callbacks' do
    subject do
      NxtPipeline::Pipeline.new do |pipeline|
        pipeline.constructor(:error_test) do |step, arg|
          step.raisor.call(arg)
        end

        pipeline.step :error_test, raisor: -> (error) { raise error }

        pipeline.on_error OtherCustomError do |step, arg, error|
          'other_custom_error callback fired'
        end

        pipeline.on_error CustomError do |step, arg, error|
          'custom_error callback fired'
        end

        pipeline.on_error do |step, arg, error|
          raise error
        end
      end
    end

    it 'executes the first matching callback' do
      expect(subject.execute(OtherCustomError)).to eq('other_custom_error callback fired')
      expect(subject.execute(CustomError)).to eq('custom_error callback fired')
      expect { subject.execute(ArgumentError) }.to raise_error(ArgumentError)
    end

    context 'when the more common handler was registered before the more specific handler' do
      subject do
        NxtPipeline::Pipeline.new do |pipeline|
          pipeline.constructor(:error_test) do |step, arg|
            step.raisor.call(arg)
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
        expect(subject.execute(OtherCustomError)).to eq('custom_error callback fired')
        expect(subject.execute(CustomError)).to eq('custom_error callback fired')
        expect { subject.execute(ArgumentError) }.to raise_error(ArgumentError)
      end
    end

    context 'when one handler was registered for multiple errors' do
      subject do
        NxtPipeline::Pipeline.new do |pipeline|
          pipeline.constructor(:error_test) do |step, arg|
            step.raisor.call(arg)
          end

          pipeline.step :error_test, raisor: -> (error) { raise error }

          pipeline.on_errors CustomError, OtherCustomError do |step, arg, error|
            'common callback fired'
          end

          pipeline.on_error do |step, arg, error|
            raise error
          end
        end
      end

      it 'triggers the handler for all errors' do
        expect(subject.execute(CustomError)).to eq('common callback fired')
        expect(subject.execute(OtherCustomError)).to eq('common callback fired')
        expect { subject.execute(ArgumentError) }.to raise_error(ArgumentError)
      end
    end
  end

  context 'before_execute and after_execute callbacks' do
    subject do
      NxtPipeline::Pipeline.new do |pipeline|
        pipeline.step do |_, arg|
          arg
        end

        pipeline.before_execute do |pipeline, arg|
          arg.prepend('before ')
        end

        pipeline.after_execute do |pipeline, arg|
          arg << ' after'
        end
      end
    end

    it 'calls the callbacks in the correct order' do
      expect(subject.execute('getsafe')).to eq('before getsafe after')
    end

    context 'with after_execute callback accessing the pipeline log' do
      subject do
        NxtPipeline::Pipeline.new do |pipeline|
          pipeline.step to_s: 'anonymous_step' do |_, arg|
            arg
          end

          pipeline.after_execute do |pipeline, arg|
            arg << " => status: #{pipeline.log.dig('anonymous_step', :status)}"
          end
        end
      end

      it 'accesses the pipeline log' do
        expect(subject.execute('getsafe')).to eq('getsafe => status: success')
      end
    end
  end

  context 'with different kinds of steps registered' do
    subject do
      NxtPipeline::Pipeline.new do |pipeline|
        pipeline.constructor(:service) do |step, arg|
          step.transformer.call(arg)
        end

        pipeline.constructor(:other) do |step, arg|
          step.splitter.call(arg)
        end

        pipeline.step :service, transformer: -> (arg) { arg.upcase }
        pipeline.step :other, splitter: -> (arg) { arg.chars.join('_') }
        pipeline.step :service, transformer: -> (arg) { (arg.chars + %w[_] + arg.chars).join }
      end
    end

    it 'executes the steps' do
      expect(subject.execute('hanna')).to eq('H_A_N_N_A_H_A_N_N_A')
    end
  end

  context 'default step' do
    subject do
      NxtPipeline::Pipeline.new do |pipeline|
        pipeline.constructor(:proc, default: true) do |step, arg|
          step.transformer.call(arg)
        end

        pipeline.step transformer: -> (arg) { arg.upcase }
        pipeline.step transformer: -> (arg) { arg.chars.join('_') }
      end
    end

    it 'executes the steps' do
      expect(subject.execute('hanna')).to eq('H_A_N_N_A')
    end

    context 'when defined multiple times' do
      it 'raises an error' do
        expect {
          NxtPipeline::Pipeline.new do |pipeline|
            pipeline.constructor(:proc, default: true) do |step, arg|
              step.transformer.call(arg)
            end

            pipeline.constructor(:lambda, default: true) do |step, arg|
              step.transformer.call(arg)
            end
          end
        }.to raise_error(ArgumentError, 'Default step already defined')
      end
    end
  end

  context 'steps with blocks' do
    subject do
      NxtPipeline::Pipeline.new do |pipeline|
        pipeline.step do |step, arg|
          arg.upcase
        end

        pipeline.step :second_step do |step, arg|
          arg.chars.join('_')
        end
      end
    end

    it 'executes the steps' do
      expect(subject.execute('hanna')).to eq('H_A_N_N_A')
    end

    it 'logs the steps' do
      subject.execute('hanna')
      expect(subject.log).to eq("NxtPipeline::Step opts => {}" => { :status=>:success }, :second_step => { :status=>:success })
    end
  end

  context 'when used inside a class' do
    class Transformer
      def initialize(string)
        @string = string
      end

      def call
        pipeline.execute(@string)
      end

      def pipeline
        NxtPipeline::Pipeline.new do |pipeline|
          pipeline.step do |_, arg|
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

  describe '#configure' do
    subject { NxtPipeline::Pipeline.new }

    before do
      subject.configure do |pipeline|
        pipeline.step :transformer, method: :upcase do |step, arg|
          arg.send(step.method)
        end
      end
    end

    it 'configures the pipeline' do
      expect(subject.execute('hanna')).to eq('HANNA')
    end

    it 'returns itself' do
      expect(subject.configure do |pipeline|
        pipeline.step :transformer, method: :upcase do |step, arg|
          arg.send(step.method)
        end
      end).to eq(subject)
    end
  end

  describe '.execute' do
    subject do
      NxtPipeline::Pipeline.execute('hanna') do |pipeline|
        pipeline.step do |_, arg|
          arg.upcase
        end
      end
    end

    it 'executes the steps directly' do
      expect(subject).to eq('HANNA')
    end
  end
end
