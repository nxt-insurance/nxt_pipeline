RSpec.describe NxtPipeline::Pipeline do
  context 'dynamic types' do
    subject do
      NxtPipeline::Pipeline.new do |pipeline|
        service_type_resolver = ->(type) { type.is_a?(Class) }

        pipeline.constructor(:service, default: true, type_resolver: service_type_resolver) do |step, arg|
          step.type.new(arg).call
        end

        string_type_resolver = ->(type) { type.is_a?(String) }

        pipeline.constructor(:dynamic, type_resolver: string_type_resolver) do |step, arg|
          if step.type == 'multiply'
            arg * 2
          elsif step.type == 'symbolize'
            arg.to_sym
          else
            raise ArgumentError, "Don't know how to deal with type: #{step.type}"
          end
        end

        pipeline.step StepOne
        pipeline.step 'multiply'
        pipeline.step 'symbolize'
      end
    end

    it 'resolves the given type' do
      expect(subject.execute('hanna')).to eq(:HANNAHANNA)
    end
  end
end
