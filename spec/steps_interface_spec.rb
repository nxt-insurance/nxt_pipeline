RSpec.describe NxtPipeline::Pipeline do
  let(:input) { '' }

  context 'add steps subsequently' do
    subject do
      NxtPipeline::Pipeline.new do |p|
        p.step ->(_, arg:) { { arg: arg + 'first ' } }
        p.step ->(_, arg:) { { arg: arg + 'second ' } }
        p.step ->(_, arg:) { { arg: arg + 'third ' } }

        p.after_execution do |pipe, **_|
          { arg: pipe.result[:arg].strip }
        end
      end
    end

    it do
      expect(subject.call(arg: input)).to eq(arg: 'first second third')
    end
  end

  context 'add multiple steps with options through overwritten reader' do
    let(:additional_steps) do
      [
        ->(_, arg:) { { arg: arg + 'first ' } },
        [
          ->(arg) { { arg: arg + 'second ' } },
          constructor: :proc
        ],
        [
          ->(arg) { { arg: arg + 'third ' } },
          constructor: :proc,
          map_options: ->(_) { { passed_in: 'injected' } }
        ]
      ]
    end

    subject do
      NxtPipeline::Pipeline.new do |p|
        p.constructor(:proc, default: true) do |step, arg:|
          if step.mapped_options.any?
            arg << "#{step.mapped_options[:passed_in]} "
          end

          step.argument.call(arg)
        end

        p.steps(additional_steps)
        p.step ->(_, arg:) { { arg: arg + 'fourth ' } }

        p.after_execution do |pipe, **_|
          { arg: pipe.result[:arg].strip }
        end
      end
    end

    it do
      expect(subject.call(arg: input)).to eq(arg: 'first second injected third fourth')
    end
  end

  context 'force multiple steps through writer' do
    let(:enforced_steps) do
      [
        [->(_, arg:) { { arg: arg + 'first ' } }],
        [
          ->(arg) { { arg: arg + 'second ' } },
          constructor: :proc
        ],
        [
          ->(arg) { { arg: arg + 'third ' } },
          constructor: :proc,
          map_options: -> { { passed_in: 'injected' } }
        ]
      ]
    end

    subject do
      NxtPipeline::Pipeline.new do |p|
        p.constructor(:proc, default: true) do |step, arg:|
          if step.mapped_options.any?
            arg << "#{step.mapped_options[:passed_in]} "
          end

          step.argument.call(arg)
        end

        p.steps(enforced_steps)
        p.step ->(_, arg:) { { arg: arg + 'fourth ' } }

        p.after_execution do |pipe, **_|
          { arg: pipe.result[:arg].strip }
        end
      end
    end

    # enforce only some steps through setter
    before { subject.steps = enforced_steps }

    it do
      expect(subject.call(arg: input)).to eq(arg: 'first second injected third')
    end
  end

  context 'with a pipeline as a step of another pipeline' do
    let(:other_pipeline) do
      NxtPipeline::Pipeline.new do |p|
        p.constructor(:proc, default: true) do |step, arg:|
          if step.mapped_options.any?
            arg << "#{step.mapped_options[:passed_in]} "
          end

          step.argument.call(arg)
        end

        p.step ->(_, arg:) { { arg: arg + 'pipeline 1.1 ' } }
        p.step ->(_, arg:) { { arg: arg + 'pipeline 1.2 ' } }
      end
    end

    subject do
      NxtPipeline::Pipeline.new do |p|
        p.constructor(:proc, default: true) do |step, arg:|
          if step.mapped_options.any?
            arg << "#{step.mapped_options[:passed_in]} "
          end

          step.argument.call(arg)
        end

        p.step other_pipeline
        p.step ->(_, arg:) { { arg: arg + 'pipeline 2.1 ' } }
        p.step ->(_, arg:) { { arg: arg + 'pipeline 2.2' } }
      end
    end

    it do
      expect(subject.call(arg: input)).to eq(arg: 'pipeline 1.1 pipeline 1.2 pipeline 2.1 pipeline 2.2')
    end
  end
end