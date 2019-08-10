RSpec.describe NxtPipeline::Dsl do
  let(:some_class) do
    Class.new do
      include NxtPipeline::Dsl

      pipeline do |p|
        p.step do |step, arg|
          "Default: #{arg}"
        end
      end

      pipeline :execution do |p|
        p.step do |step, arg|
          "Execution: #{arg}"
        end
      end

      def call(pipeline_name, arg)
        pipeline(pipeline_name).execute(arg)
      end
    end
  end

  subject do
    some_class
  end

  describe '.pipeline' do
    context 'when no name is given' do
      it 'registers a default pipeline' do
        expect(subject.pipeline.execute('Raphael Lütfi Nilsom')).to eq('Default: Raphael Lütfi Nilsom')
        expect(subject.new.pipeline.execute('Raphael Lütfi Nilsom')).to eq('Default: Raphael Lütfi Nilsom')
      end
    end

    context 'when a name was given' do
      it 'registers a pipeline for that name' do
        expect(subject.pipeline(:execution).execute('Raphael Lütfi Nilsom')).to eq('Execution: Raphael Lütfi Nilsom')
        expect(subject.new.pipeline(:execution).execute('Raphael Lütfi Nilsom')).to eq('Execution: Raphael Lütfi Nilsom')
      end
    end

    context 'when a pipeline was already registered with that name' do
      it 'raises an error' do
        expect {
          subject.pipeline :execution do |p|
            p.step do |step, arg|
              "Oh oh: #{arg}"
            end
          end
        }.to raise_error(KeyError, /Already registered a pipeline execution/)
      end
    end

    context 'when pipelines are nested' do
      subject do
        Class.new do
          include NxtPipeline::Dsl

          pipeline :execution do |p|
            p.step :raisor do |step, arg|
              raise StandardError, arg
            end

            p.on_error StandardError do |step, arg, error|
              pipeline(:error).execute(error: error, original_arg: arg)
            end
          end

          pipeline :error do |p|
            p.step do |step, arg|
              "Ups, an error occurred: #{arg[:error].class}. Original argument was: #{arg[:original_arg]}"
            end
          end

          def call(arg)
            pipeline(:execution).execute(arg)
          end
        end
      end

      it 'calls the pipelines in the correct order' do
        expect(subject.new.call('Fire')).to eq('Ups, an error occurred: StandardError. Original argument was: Fire')
      end
    end
  end

  describe '.pipeline!' do
    subject do
      Class.new(some_class) do
        pipeline! :default do |p|
          p.step do |step, arg|
            "Hijacked: #{arg}"
          end
        end
      end
    end

    it 'allows to overwrite already configured pipelines' do
      expect(subject.pipeline(:default).execute('Raphael Lütfi Nilsom')).to eq('Hijacked: Raphael Lütfi Nilsom')
      expect(subject.new.pipeline(:default).execute('Raphael Lütfi Nilsom')).to eq('Hijacked: Raphael Lütfi Nilsom')
    end
  end
end
