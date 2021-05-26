RSpec.describe NxtPipeline::Pipeline do
  describe '#step_resovler' do
    subject do
      NxtPipeline::Pipeline.new do |pipeline|
        pipeline.step_resolver do |argument|
          argument.is_a?(Class) && :service
        end

        pipeline.step_resolver do |argument|
          argument.is_a?(String) && :dynamic
        end

        pipeline.constructor(:service, default: true) do |step, arg:|
          result = step.argument.new(word: arg).call
          { arg: result }
        end

        pipeline.constructor(:dynamic) do |step, arg:|
          if step.argument == 'multiply'
            { arg: arg * 2 }
          elsif step.argument == 'symbolize'
            { arg: arg.to_sym }
          else
            raise ArgumentError, "Don't know how to deal with argument: #{step.argument}"
          end
        end

        pipeline.step StepOne
        pipeline.step 'multiply'
        pipeline.step 'symbolize'

        pipeline.step do |step, arg:|
          arg
        end
      end
    end

    it 'resolves the steps' do
      expect(subject.call(arg: 'hanna')).to eq(:HANNAHANNA)
    end
  end
end
