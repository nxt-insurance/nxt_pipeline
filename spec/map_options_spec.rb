RSpec.describe NxtPipeline::Pipeline do
  context 'when the constructor takes only 2 arguments' do
    context 'but options are mapped' do
      subject do
        NxtPipeline::Pipeline.new do |pipeline|
          pipeline.constructor(:proc, default: true) do |step, opts|
            step.proc.call(opts, mapped_options)
          end

          pipeline.step :proc,
                        proc: ->(changeset, options) { changeset.merge(options) },
                        map_options: ->(changeset) { { additional: 'options' } }
        end
      end

      it 'raises an ArgumentError' do
        expect {
          subject.execute(original: 'options')
        }.to raise_error(
          ArgumentError,
          "Constructor takes only 2 arguments instead of 3 => step, changeset, mapped_options"
        )
      end
    end
  end

  context 'when the constructor takes 3 arguments' do
    context 'and an options are mapped' do
      subject do
        NxtPipeline::Pipeline.new do |pipeline|
          pipeline.constructor(:proc, default: true) do |step, opts, mapped_options|
            step.proc.call(opts, mapped_options)
          end

          pipeline.step :proc,
                        proc: ->(changeset, options) { changeset.merge(options) },
                        map_options: ->(changeset) { { additional: 'options' } }
        end
      end

      it 'passes the mapped options to the constructor' do
        expect(subject.execute(original: 'options')).to eq(original: 'options', additional: 'options')
      end
    end

    context 'but no options are mapped' do
      subject do
        NxtPipeline::Pipeline.new do |pipeline|
          pipeline.constructor(:proc, default: true) do |step, opts, mapped_options|
            step.proc.call(opts, mapped_options)
          end

          pipeline.step :proc, proc: ->(changeset, options) { changeset.merge(options) }
        end
      end

      it 'passes the an empty hash to the constructor' do
        expect(subject.execute(original: 'options')).to eq(original: 'options')
      end
    end
  end
end
