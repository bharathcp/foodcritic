require "shellwords"

require "rspec_command"
require "simplecov"

SimpleCov.start do
  add_filter "/spec/"
end

module FunctionalHelpers
  extend RSpec::Matchers::DSL

  matcher :violate_rule do |rule_id|
    match do |cmd|
      if location
        cmd.stdout =~ /^#{rule_id}:.*: \.\/#{location}/
      else
        cmd.stdout =~ /^#{rule_id}:/
      end
    end
    chain :in, :location
    failure_message do |cmd|
      "expected a violation of rule #{rule_id}#{location && " in #{location}"}, output was:\n#{cmd.stdout}"
    end
  end

  def foodcritic_command(*args)
    output = StringIO.new
    error = StringIO.new
    begin
      # Don't use the block form of chdir because for some reason it can't be
      # nested.
      cwd = Dir.pwd
      Dir.chdir(temp_path)
      $stderr = error
      exitstatus = FoodCritic::CommandLine.main(args, output)
    ensure
      $stderr = STDERR
      Dir.chdir(cwd)
    end
    RSpecCommand::OutputString.new(output.string, error.string).tap do |out|
      out.define_singleton_method(:exitstatus) { exitstatus }
    end
  end

  module ClassMethods
    def foodcritic_command(*args)
      metadata[:foodcritic_command] = true
      subject do |example|
        foodcritic_command(*args)
      end
    end

    def attributes_file(*args, &block)
      file("attributes/default.rb", *args, &block)
    end

    def recipe_file(*args, &block)
      file("recipes/default.rb", *args, &block)
    end

    def metadata_file(*args, &block)
      file("metadata.rb", *args, &block)
    end

    def included(klass)
      super
      klass.extend ClassMethods
      # Set a default subject command, can be overridden if needed.
      klass.foodcritic_command("--no-progress", ".")
    end
  end

  extend ClassMethods
end

RSpec.configure do |config|
  # Basic configuraiton
  config.run_all_when_everything_filtered = true
  config.filter_run(:focus) unless ENV["CI"]

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"

  # Set some metadata based on test folders.
  config.define_derived_metadata(file_path: %r{spec/unit}) do |metadata|
    metadata[:unit] = true
  end
  config.define_derived_metadata(file_path: %r{spec/functional}) do |metadata|
    metadata[:functional] = true
  end
  config.define_derived_metadata(file_path: %r{spec/regression}) do |metadata|
    metadata[:regression] = true
  end

  config.include RSpecCommand
  config.include FunctionalHelpers, functional: true
end

require_relative "../lib/foodcritic"
