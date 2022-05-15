RSpec.describe NxtPipeline::Pipeline do
  subject do
    NxtPipeline.new do |pipeline|
      pipeline.constructor(:service, default: true) do |step, **opts|
        step.argument.new(**opts).call
      end
    end
  end

  describe ':if guard' do
    context 'when the guard takes no arguments' do
      context 'and the guard claus applies' do
        it 'skips the step' do
          subject.call(word: 'hanna') do |p|
            p.step StringTransformer, operation: :upcase, constructor: :service, if: -> { false }
          end

          expect(subject.logger.log.values.last).to eq(:skipped)
        end
      end
    end

    context 'when the guard takes a single arguments' do
      context 'and the guard claus applies' do
        it 'skips the step' do
          subject.call(word: false) do |p|
            p.step StringTransformer, operation: :upcase, if: -> (word:) { word }
          end

          expect(subject.logger.log.values.last).to eq(:skipped)
        end
      end
    end

    context 'when the guard takes two arguments' do
      context 'and the guard claus applies' do
        it 'skips the step' do
          subject.call(word: false) do |p|
            p.step StringTransformer, operation: :upcase, if: -> (opts, step) { step.is_a?(NxtPipeline::Step) && opts.fetch(:word) }
          end

          expect(subject.logger.log.values.last).to eq(:skipped)
        end
      end
    end
  end

  describe ':unless guard' do
    context 'when the guard takes no arguments' do
      context 'and the guard claus applies' do
        it 'skips the step' do
          subject.call(word: 'hanna') do |p|
            p.step StringTransformer, operation: :upcase, unless: -> { true }
          end

          expect(subject.logger.log.values.last).to eq(:skipped)
        end
      end
    end

    context 'when the guard takes a single arguments' do
      context 'and the guard claus applies' do
        it 'skips the step' do
          subject.call(word: true) do |p|
            p.step StringTransformer, operation: :upcase, unless: -> (word:) { word }
          end

          expect(subject.logger.log.values.last).to eq(:skipped)
        end
      end
    end

    context 'when the guard takes two arguments' do
      context 'and the guard claus applies' do
        it 'skips the step' do
          subject.call(word: true) do |p|
            p.step StringTransformer, operation: :upcase, unless: -> (opts, step) { step.is_a?(NxtPipeline::Step) && opts.fetch(:word) }
          end

          expect(subject.logger.log.values.last).to eq(:skipped)
        end
      end
    end
  end
end
