[![CircleCI](https://circleci.com/gh/nxt-insurance/nxt_pipeline.svg?style=svg)](https://circleci.com/gh/nxt-insurance/nxt_pipeline)

# NxtPipeline

NxtPipeline is an orchestration framework for your service objects or function objects, how I like to call them.
Service objects are a very wide spread way of organizing code in the Ruby and Rails communities. Since it's little classes
doing one thing you can think of them as function objects and thus they often share a common interface in a project. 
There are also many frameworks out there that normalize the usage of service objects and provide a specific way
of writing service objects and often also allow to orchestrate (reduce) these service objects.
Compare [light-service](https://github.com/adomokos/light-service) for instance.

The idea of NxtPipeline was to build a flexible orchestration framework for service objects without them having to conform
to a specific interface. Instead NxtPipeline expects you to specify how to execute different kinds of service objects
through so called constructors and thereby does not dictate you how to write your service objects. Nevertheless this still
mostly makes sense if your service objects share common interfaces to keep the necessary configuration to a minimum.

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

### Example

Let's look at an example. Here validator service objects are orchestrated with NxtPipeline to build a validation 
pipeline. We inject the accumulator `{ value: 'aki', errors: [] }` that is then passed through all validation steps. 
If an validator returns an error it's added to the array of errors of the accumulator to collect all errors of all steps.

```ruby
class Validator
  attr_accessor :error
end

class TypeChecker < Validator
  def initialize(value, type:)
    @value = value
    @type = type
  end

  attr_reader :value, :type

  def call
    return if value.is_a?(type)
    self.error = "Value does not match type #{type}"
  end
end

class MinSize < Validator
  def initialize(value, size:)
    @value = value
    @size = size
  end

  attr_reader :value, :size

  def call
    return if value.size >= size
    self.error = "Value size must be greater than #{size-1}"
  end
end

class MaxSize < Validator
  def initialize(value, size:)
    @value = value
    @size = size
  end

  attr_reader :value, :size

  def call
    return if value.size <= size
    self.error = "Value size must be less than #{size+1}"
  end
end

class Uniqueness < Validator
  def initialize(value, scope:)
    @value = value
    @scope = scope
  end

  attr_reader :value, :scope

  def call
    return if scope.count { |item| item == value }
    self.error = "Value is not unique in: #{scope}"
  end
end

result = NxtPipeline.call({ value: 'aki', errors: [] }) do |p|
  p.constructor(:validator, default: true) do |acc, step|
    validator = step.argument.new(acc.fetch(:value), **step.options)
    validator.call
    acc[:errors] << validator.error if validator.error.present?

    acc
  end

  p.step TypeChecker, options: { type: String }
  p.step MinSize, options: { size: 4 }
  p.step MaxSize, options: { size: 10 }
  p.step Uniqueness, options: { scope: ['andy', 'aki', 'lütfi', 'rapha'] }
end

result # => { value: 'aki', errors: ['Value size must be greater than 3'] } 
```

### Constructors

In order to reduce over your service objects you have to define constructors so that the pipeline knows how to execute
a specific step. You can define constructors globally and specific to a pipeline.

Make a constructor available for all pipelines of your project by defining it globally with:

```ruby
NxtPipeline.constructor(:service) do |acc, step|
  validator = step.argument.new(acc.fetch(:value), **step.options)
  validator.call
  acc[:errors] << validator.error if validator.error.present?

  acc
end
```

Or define a constructor only locally for a specific pipeline.

```ruby
NxtPipeline.new({ value: 'aki', errors: [] }) do |p|
  p.constructor(:validator, default: true) do |acc, step|
    validator = step.argument.new(acc.fetch(:value), **step.options)
    validator.call
    acc[:errors] << validator.error if validator.error.present?

    acc
  end

  p.step TypeChecker, options: { type: String }
  # ...
end
```

Constructor Hierarchy

In order to execute a specific step the pipeline firstly checks whether a constructor was specified for a step: 
`pipeline.step MyServiceClass, constructor: :service`. If this is not the case it checks whether there is a resolver 
registered that applies. If that's not the case the pipeline checks if there is a constructor registered for the 
argument that was passed in. This means if you register constructors directly for the arguments you pass in you don't
have to specify this constructor option. Therefore the following would work without the need to provide a constructor 
for the steps.

```ruby
NxtPipeline.new({}) do |p|
  p.constructor(:service) do |acc, step|
    step.service_class.new(acc).call
  end

  p.step :service, service_class: MyServiceClass
  p.step :service, service_class: MyOtherServiceClass
  # ...
end
```

Lastly if no constructor could be resolved directly from the step argument, the pipelines falls back to the locally
and then to the globally defined default constructors.

### Defining steps

Once your pipeline knows how to execute your steps you can add those. The `pipeline.step` method expects at least one
argument which you can access in the constructor through `step.argument`. You can also pass in additional options
that you can access through readers of a step. The `constructor:` option defines which constructor to use for a step
where as you can name a step with the `to_s:` option.

```ruby
# explicitly define which constructor to use 
pipeline.step MyServiceClass, constructor: :service
# use a block as inline constructor
pipeline.step SpecialService, constructor: ->(step, arg:) { step.argument.call(arg: arg) }
# Rely on the default constructor
pipeline.step MyOtherServiceClass
# Define a step name
pipeline.step MyOtherServiceClass, to_s: 'First Step'
# Or simply execute a (named) block - NO NEED TO DEFINE A CONSTRUCTOR HERE  
pipeline.step :step_name_for_better_log do |acc, step|
  # ...
end
```

Defining multiple steps at once. This is especially useful to dynamically configure a pipeline for execution and
can potentially even come from a yaml configuration or from the database.

```ruby
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

Once a pipeline contains steps you can call it with `call(accumulator)` whereas it expects you to inject the accumulator
as argument that is then passed through all steps.

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
  p.steps # ...
end
```

You can query the steps of your pipeline simply by calling `pipeline.steps`. A NxtPipeline::Step will provide you with
an interface for options, status, execution_finished_at execution_started_at,
execution_duration, result, error and the index in the pipeline.

```
pipeline.steps.first
# will give you a step object
#<NxtPipeline::Step:0x00007f83eb399448...>
```

### Guard clauses

You can also define guard clauses that take a proc to prevent the execution of a step.
A guard can accept the change set and the step as arguments.

 ```ruby
 pipeline.call('initial argument') do |p|
  p.step MyServiceClass, if: -> (acc, step) { acc == 'initial argument' }
  p.step MyOtherServiceClass, unless: -> { false }
end

 ```

### Error callbacks

Apart from defining constructors and steps you can also define error callbacks. Error callbacks can accept up to  
three arguments: `error, acc, step`.

```ruby
NxtPipeline.new do |p|
  p.step # ... 

  p.on_error MyCustomError do |error|
    # First matching error callback will be executed!
  end

  p.on_errors ArgumentError, KeyError do |error, acc|
    # First matching error callback will be executed!
  end

  p.on_errors YetAnotherError, halt_on_error: false do |error, acc, step|
    # After executing the callback the pipeline will not halt but continue to
    # execute the next steps.
  end

  p.on_errors do |error, acc, step|
    # This will match all errors inheriting from StandardError
  end
end
```

### Before, around and after callbacks

You can also define callbacks :before, :around and :after each step and or the `#execute` method. You can also register
multiple callbacks, but probably you want to keep them to a minimum to not end up in hell. Also note that before and
after callbacks will run even if a step was skipped through a guard clause.

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
  pipeline.step :extract_value do |arg|
    arg
  end
end
```

### Configurations

You probably do not have that many different kinds of steps that you execute within your pipelines. Otherwise the whole
concept does not make much sense. To make constructing a pipeline simpler you can therefore define configurations on
a global level simply by providing a name for a configuration along with a configuration block.
Then you then create a preconfigure pipeline by passing in the name of the configuration when creating a new pipeline.

```ruby
# Define configurations in your initializer or somewhere upfront 
NxtPipeline.configuration(:test_processor) do |pipeline|
  pipeline.constructor(:processor) do |arg, step|
    { arg: step.argument.call(arg: arg) }
  end
end

NxtPipeline.configure(:validator) do |pipeline|
  pipeline.constructor(:validator) do |arg, step|
    # ..
  end
end

# ...

# Later create a pipeline with a previously defined configuration
NxtPipeline.new(configuration: :test_processor) do |p|
  p.step ->(arg) { arg + 'first ' }, constructor: :processor
  p.step ->(arg) { arg + 'second ' }, constructor: :processor
  p.step ->(arg) { arg + 'third' }, constructor: :processor
end
```

### Step status and meta_data
When executing your steps you can also log the status of a step by setting it in your constructors or callbacks in 
which you have access to the steps.

```ruby
pipeline = NxtPipeline.new do |pipeline|
  pipeline.constructor(:step, default: true) do |acc, step|
    result = step.proc.call(acc)
    step.status = result.present? # Set the status here
    step.meta_data = 'additional info' # or some meta data
    acc
  end

  pipeline.step :first_step do |acc, step|
    step.status = 'it worked'
    step.meta_data = { extra: 'info' }
    acc
  end

  pipeline.step :second, proc: ->(acc) { acc }
end

pipeline.logger.log # => { "first_step" => 'it worked', "second" => true } 
pipeline.steps.map(&:meta_data) # => [{:extra=>"info"}, "additional info"]
```

## Topics

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

You can also run `bin/guard` to automatically run specs when files are saved.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nxt-insurance/nxt_pipeline.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
