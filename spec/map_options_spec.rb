RSpec.describe NxtPipeline::Pipeline do
  context 'mapped options' do
    subject do
      NxtPipeline.new do |pipeline|
        pipeline.constructor(:proc, default: true) do |opts, step|
          step.proc.call(opts, step.mapped_options)
        end

        pipeline.step :proc,
                      proc: ->(change_set, options) { change_set.merge(options) },
                      map_options: ->(_) { { additional: 'options' } }
      end
    end

    it 'passes the mapped options to the constructor' do
      expect(subject.call(original: 'options')).to eq(original: 'options', additional: 'options')
    end
  end
end
