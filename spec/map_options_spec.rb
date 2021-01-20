RSpec.describe NxtPipeline::Pipeline do
  context 'mapped options' do
    subject do
      NxtPipeline::Pipeline.new do |pipeline|
        pipeline.constructor(:proc, default: true) do |step, opts|
          step.proc.call(opts, step.mapped_options)
        end

        pipeline.step :proc,
                      proc: ->(change_set, options) { change_set.merge(options) },
                      map_options: ->(change_set) { { additional: 'options' } }
      end
    end

    it 'passes the mapped options to the constructor' do
      expect(subject.execute(original: 'options')).to eq(original: 'options', additional: 'options')
    end
  end
end
