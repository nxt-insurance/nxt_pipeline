RSpec.describe NxtPipeline::Pipeline do
  let(:input) { '' }

  context 'add steps subsequently' do
    subject do
      NxtPipeline::Pipeline.new do |p|
        p.constructor(:proc, default: true) do |acc, step|
          step.argument.call(acc)
        end

        p.step ->(arg) { arg + 'first ' }
        p.step ->(arg) { arg + 'second ' }
        p.step ->(arg) { arg + 'third ' }

        p.after_execution do |acc, pipe|
          { arg: pipe.result.strip }
        end
      end
    end

    it do
      expect(subject.call(input)).to eq(arg: 'first second third')
    end
  end

  context 'add multiple steps with options through overwritten reader' do
    let(:additional_steps) do
      [
        ->(acc) { acc + 'first ' },
        [
          ->(acc) { acc + 'second ' },
          constructor: :proc
        ],
        [
          ->(acc) { acc + 'third ' },
          constructor: :proc,
          map_options: ->(_) { { passed_in: 'injected' } }
        ]
      ]
    end

    subject do
      NxtPipeline::Pipeline.new do |p|
        p.constructor(:proc, default: true) do |acc, step|
          if step.mapped_options.any?
            acc << "#{step.mapped_options[:passed_in]} "
          end

          step.argument.call(acc)
        end

        p.steps(additional_steps)
        p.step ->(acc) { acc + 'fourth ' }

        p.after_execution do |_, pipeline|
          { arg: pipeline.result.strip }
        end
      end
    end

    it do
      expect(subject.call(input)).to eq(arg: 'first second injected third fourth')
    end
  end

  context 'force multiple steps through writer' do
    let(:enforced_steps) do
      [
        [->(arg) { arg + 'first ' } ],
        [
          ->(arg) { arg + 'second ' },
          constructor: :proc
        ],
        [
          ->(arg) { arg + 'third ' },
          constructor: :proc,
          map_options: -> { { passed_in: 'injected' } }
        ]
      ]
    end

    subject do
      NxtPipeline::Pipeline.new do |p|
        p.constructor(:proc, default: true) do |acc, step|
          if step.mapped_options.any?
            acc << "#{step.mapped_options[:passed_in]} "
          end

          step.argument.call(acc)
        end

        p.steps(enforced_steps)
        p.step ->(acc) { acc + 'fourth ' }

        p.after_execution do |_, pipe|
          { arg: pipe.result.strip }
        end
      end
    end

    # enforce only some steps through setter
    before { subject.steps = enforced_steps }

    it do
      expect(subject.call(input)).to eq(arg: 'first second injected third')
    end
  end

  context 'with a pipeline as a step of another pipeline' do
    let(:other_pipeline) do
      NxtPipeline::Pipeline.new do |p|
        p.constructor(:proc, default: true) do |acc, step|
          if step.mapped_options.any?
            acc << "#{step.mapped_options[:passed_in]} "
          end

          step.argument.call(acc)
        end

        p.step ->(arg) { arg + 'pipeline 1.1 ' }
        p.step ->(arg) { arg + 'pipeline 1.2 ' }
      end
    end

    subject do
      NxtPipeline::Pipeline.new do |p|
        p.constructor(:proc, default: true) do |acc, step|
          if step.mapped_options.any?
            acc << "#{step.mapped_options[:passed_in]} "
          end

          step.argument.call(acc)
        end

        p.step other_pipeline
        p.step ->(arg) { arg + 'pipeline 2.1 ' }
        p.step ->(arg) { arg + 'pipeline 2.2' }
      end
    end

    it do
      expect(subject.call(input)).to eq('pipeline 1.1 pipeline 1.2 pipeline 2.1 pipeline 2.2')
    end
  end
end