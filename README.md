<[![CircleCI](https://circleci.com/gh/nxt-insurance/nxt_pipeline.svg?style=svg)](https://circleci.com/gh/nxt-insurance/nxt_pipeline)

# NxtPipeline

The idea of nxt_pipeline is to provide the functionality to reduce over service objects and callables in general.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'nxt_pipeline'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install nxt_pipeline

## Usage

### Constructors

In order to reduce over your service objects you have to define constructors so that the pipeline knows how to execute
each step. Consider the following pipeline that processes an array of strings:

```ruby
class Upcaser
  def initialize(strings)
    @strings = strings
  end

  def call
    @strings.map(&:upcase)
  end
end

class Stripper
  def initialize(strings)
    @strings = strings
  end

  def call
    @strings.map(&:strip)
  end
end

class Compacter
  def initialize(strings)
    @strings = strings
  end

  def call
    @strings.reject(&:blank?)
  end
end

class Notifier < ApplicationJob
  def perform_later(**args)
    # ... TODO
  end
end

pipeline = NxtPipeline.new do |p|
  # service objects 
  p.constructor(:service, default: true) do |step, arg:|
    result = step.argument.new(arg).call
    result && { arg: result }
  end

  # active job jobs
  p.constructor(:job) do |step, arg:|
    step.argument.perform_later(**arg).call
    { arg: arg }
  end

  p.step Compacter
  p.step Stripper
  p.step Upcaser
  p.step Notifier, constructor: :job
end

pipeline.call(strings: ['Ruby', '', nil, 'JavaScript'])
```

### Defining steps

Once your pipeline knows how to execute your steps you can add those. The `pipeline.step` method expects at least one
argument which you can access in the constructor through `step.argument`. You can also pass in additional options
that you can access through readers your step. The `constructor:` option defines which constructor to use for a step
where as you can name a step with th `to_s:` option.

```ruby
# explicitly define which constructor to use 
pipeline.step MyServiceClass, constructor: :service
# use a block as inline constructor
pipeline.step SpecialService, constructor: ->(step, arg:) { step.argument.call(arg: arg) }
# Rely on the default constructor
pipeline.step MyOtherServiceClass
# Define a step name
pipeline.step MyOtherServiceClass, to_s: 'First Step'
# Or simply execute a (named) block
pipeline.step :step_name_for_better_log do |step, arg:|
  # ...
end
# Which is the same as above
pipeline.step to_s: 'This is the same as above' do |step, arg:|
  # ... 
end

# You can also add multiple steps at once which is especially useful to dynamically configure a pipeline for execution
pipeline.steps([
  [MyServiceClass, constructor: :service],
  [MyOtherServiceClass, constructor: :service],
  [MyJobClass, constructor: :job]
])

# You can also overwrite the steps of a pipeline through explicitly setting them. This will remove any previously 
# defined steps.
pipeline.steps = [
  [MyServiceClass, constructor: :service],
  [MyOtherServiceClass, constructor: :service]
]
```

### Execution

Once a pipeline contains steps you can run it with:

```ruby
pipeline.call(arg: 'initial argument')

# Or directly pass the steps you want to execute:
pipeline.call(arg: 'initial argument') do |p|
  p.step MyServiceClass, to_s: 'First step'
  p.step MyOtherServiceClass, to_s: 'Second step'
  p.step MyJobClass, constructor: :job
  p.step MyOtherJobClass, constructor: :job
end
```

You can also create a new instance of a pipeline and directly run it with `call`:

```ruby
NxtPipeline.call(arg: 'initial argument') do |p|
  p.step do |_, arg:|
    { arg: arg.upcase }
  end
end
```

You can query the steps of your pipeline simply by calling `pipeline.steps`. A NxtPipeline::Step will provide you with
an interface to it's type, options, status (:success, :skipped, :failed), execution_finished_at execution_started_at,
execution_duration, result, error and the index in the pipeline.

```
pipeline.steps.first
# will give you something like this:

#<NxtPipeline::Step:0x00007f83eb399448
 @constructor=
  #<Proc:0x00007f83eb399498@/Users/andy/workspace/nxt_pipeline/spec/pipeline_spec.rb:467>,
 @error=nil,
 @index=0,
 @opts={:to_s=>:transformer, :method=>:upcase},
 @result=nil,
 @status=nil,
 @type=:transformer
 @execution_duration=1.0e-05,
 @execution_finished_at=2020-10-22 15:52:55.806417 +0100,
 @execution_started_at=2020-10-22 15:52:55.806407 +0100,>
```

### Guard clauses

You can also define guard clauses that take a proc to prevent the execution of a step.
When the guard takes an argument the step argument is yielded.

 ```ruby
 pipeline.call(arg: 'initial argument') do |p|
  p.step MyServiceClass, if: -> (arg:) { arg == 'initial argument' }
  p.step MyOtherServiceClass, unless: -> { false }
end

 ```

### Error callbacks

Apart from defining constructors and steps you can also define error callbacks.

```ruby
NxtPipeline.new do |p|
  p.step do |_, arg:|
    { arg: arg.upcase }
  end

  p.on_error MyCustomError do |step, opts, error|
    # First matching error callback will be executed!
  end

  p.on_errors ArgumentError, KeyError do |step, opts, error|
    # First matching error callback will be executed!
  end

  p.on_errors YetAnotherError, halt_on_error: false do |step, opts, error|
    # After executing the callback the pipeline will not halt but continue to
    # execute the next steps.
  end

  p.on_errors do |step, opts, error|
    # This will match all errors inheriting from StandardError
  end
end
```

### Before, around and after callbacks

You can also define callbacks :before, :around and :after each step and or the `#execute` method. You can also register
multiple callbacks, but probably you want to keep them to a minimum to not end up in hell.

#### Step callbacks

```ruby
NxtPipeline.new do |p|
  p.before_step do |_, change_set|
    change_set[:acc] << 'before step 1'
    change_set
  end

  p.around_step do |_, change_set, execution|
    change_set[:acc] << 'around step 1'
    execution.call # you have to specify where in your callback you want to call the inner block
    change_set[:acc] << 'around step 1'
    change_set
  end

  p.after_step do |_, change_set|
    change_set[:acc] << 'after step 1'
    change_set
  end
end
```

#### Execution callbacks

```ruby
NxtPipeline.new do |p|
  p.before_execution do |_, change_set|
    change_set[:acc] << 'before execution 1'
    change_set
  end

  p.around_execution do |_, change_set, execution|
    change_set[:acc] << 'around execution 1'
    execution.call # you have to specify where in your callback you want to call the inner block
    change_set[:acc] << 'around execution 1'
    change_set
  end

  p.after_execution do |_, change_set|
    change_set[:acc] << 'after execution 1'
    change_set
  end
end
```

Note that the `after_execute` callback will not be called in case a step raises an error.
See the previous section (_Error callbacks_) for how to define callbacks that run in case of errors.

### Constructor resolvers

You can also define constructor resolvers for a pipeline to dynamically define which previously registered constructor
to use for a step based on the argument and options passed to the step.

```ruby
class Transform
  def initialize(word, operation)
    @word = word
    @operation = operation
  end

  attr_reader :word, :operation

  def call
    word.send(operation)
  end
end

NxtPipeline.new do |pipeline|
  # dynamically resolve to use a proc as constructor
  pipeline.constructor_resolver do |argument, **opts|
    argument.is_a?(Class) &&
      ->(step, arg:) {
        result = step.argument.new(arg, opts.fetch(:operation)).call
        # OR result = step.argument.new(arg, step.operation).call
        { arg: result }
      }
  end

  # dynamically resolve to a defined constructor
  pipeline.constructor_resolver do |argument|
    argument.is_a?(String) && :dynamic
  end

  pipeline.constructor(:dynamic) do |step, arg:|
    if step.argument == 'multiply'
      { arg: arg * step.multiplier }
    elsif step.argument == 'symbolize'
      { arg: arg.to_sym }
    else
      raise ArgumentError, "Don't know how to deal with argument: #{step.argument}"
    end
  end

  pipeline.step Transform, operation: 'upcase'
  pipeline.step 'multiply', multiplier: 2
  pipeline.step 'symbolize'
  pipeline.step :extract_value do |step, arg:|
    arg
  end
end
```

### Configurations

You probably do not have that many different kind of steps that you execute within a pipeline. Otherwise the whole
concept does not make much sense. To make constructing a pipeline simpler you can therefore define configurations on
a global level simply by providing a name for a configuration along with a configuration block. 
Then you then create a preconfigure pipeline by passing in the name of the configuration when creating a new pipeline.

```ruby
# Define configurations nn your initializer or somewhere upfront 
NxtPipeline.configure(:test_processor) do |pipeline|
  pipeline.constructor(:processor) do |step, arg:|
    { arg: step.argument.call(step, arg: arg) }
  end
end

NxtPipeline.configure(:validator) do |pipeline|
  pipeline.constructor(:validator) do |step, arg:|
    # ..
  end
end

# ...

# Later create a pipeline with a previously defined configuration
NxtPipeline.new(:test_processor) do |p|
  p.step ->(_, arg:) { arg + 'first ' }, constructor: :processor
  p.step ->(_, arg:) { arg + 'second ' }, constructor: :processor
  p.step ->(_, arg:) { arg + 'third' }, constructor: :processor
end
```

## Topics
- Constructors should take arg as first and step as second arg

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

You can also run `bin/guard` to automatically run specs when files are saved.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nxt-insurance/nxt_pipeline.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
>