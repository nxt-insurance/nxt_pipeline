RSpec.describe NxtPipeline::Pipeline do
  describe '#map_options' do
    subject do
      NxtPipeline::Pipeline.new do |pipeline|
        pipeline.constructor(:proc, default: true) do |step, opts|
          step.proc.call(opts, step.mapped_options)
        end

        pipeline.step proc: ->(change_set, options) { change_set.merge(options) }, map_options: ->(change_set) { { additional: 'options' } }
        pipeline.step proc: ->(change_set, options) { change_set.merge(options) }, map_options: ->(change_set) { { more_additional: 'options' } }
        pipeline.step do |_, changeset|
          changeset.merge(curried: 'options') # inline steps can also be used to map options
        end
        pipeline.step proc: ->(change_set, options) { change_set.merge(options) }, map_options: ->(change_set) { { even_more_additional: 'options' } }
      end
    end

    it 'passes the mapped options to the constructor' do
      expect(subject.call(original: 'options')).to eq(
       original: 'options',
       additional: 'options',
       more_additional: 'options',
       curried: 'options',
       even_more_additional: 'options'
      )
    end
  end
end
