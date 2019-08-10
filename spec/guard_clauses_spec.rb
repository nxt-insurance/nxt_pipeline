RSpec.describe NxtPipeline::Pipeline do
  class StepOne
    def initialize(opts)
      @opts = opts
    end

    def call
      @opts.upcase
    end

    def to_s
      self.class.name
    end
  end

  subject do
    NxtPipeline::Pipeline.new do |pipeline|
      pipeline.constructor(:service, default: true) do |step, arg|
        step.service_class.new(arg).call
      end
    end
  end

  describe ':if guard' do
    context 'when the guard takes no arguments' do
      context 'and the guard claus applies' do
        it 'skips the step' do
          subject.execute('hanna') do |p|
            p.step service_class: StepOne, if: -> { false }
          end

          expect(subject.logger.log.values.last).to eq(:skipped)
        end
      end
    end

    context 'when the guard takes a single arguments' do
      context 'and the guard claus applies' do
        it 'skips the step' do
          subject.execute(false) do |p|
            p.step service_class: StepOne, if: -> (arg) { arg }
          end

          expect(subject.logger.log.values.last).to eq(:skipped)
        end
      end
    end

    context 'when the guard takes two arguments' do
      context 'and the guard claus applies' do
        it 'skips the step' do
          subject.execute(false) do |p|
            p.step service_class: StepOne, if: -> (arg, step) { step.is_a?(NxtPipeline::Step) && arg }
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
          subject.execute('hanna') do |p|
            p.step service_class: StepOne, unless: -> { true }
          end

          expect(subject.logger.log.values.last).to eq(:skipped)
        end
      end
    end

    context 'when the guard takes a single arguments' do
      context 'and the guard claus applies' do
        it 'skips the step' do
          subject.execute(true) do |p|
            p.step service_class: StepOne, unless: -> (arg) { arg }
          end

          expect(subject.logger.log.values.last).to eq(:skipped)
        end
      end
    end

    context 'when the guard takes two arguments' do
      context 'and the guard claus applies' do
        it 'skips the step' do
          subject.execute(true) do |p|
            p.step service_class: StepOne, unless: -> (arg, step) { step.is_a?(NxtPipeline::Step) && arg }
          end

          expect(subject.logger.log.values.last).to eq(:skipped)
        end
      end
    end
  end
end
