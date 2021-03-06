require 'rspec/core'
require 'rspec/core/rake_task'
DUMMY_APP = 'spec/internal'
APP_ROOT = '.'
require 'jettywrapper'
JETTY_ZIP_BASENAME = 'master'
Jettywrapper.url = "https://github.com/projecthydra/hydra-jetty/archive/#{JETTY_ZIP_BASENAME}.zip"

def system_with_command_output(command)
  pretty_command = "\n$\t#{command}"
  $stdout.puts(pretty_command)
  if !system(command)
    banner = "\n\n" + "*" * 80 + "\n\n"
    $stderr.puts banner
    $stderr.puts "Unable to run the following command:"
    $stderr.puts "#{pretty_command}"
    $stderr.puts banner
    exit!(-1)
  end
end

def within_test_app
  FileUtils.cd(DUMMY_APP)
  yield
  FileUtils.cd('../..')
end

desc "Clean out the test rails app"
task :clean do
  system_with_command_output("rm -rf #{DUMMY_APP}")
end

desc 'Rebuild the rails test app'
task :regenerate => [:clean, :generate]

desc "Create the test rails app"
task :generate do
  unless File.exists?(DUMMY_APP + '/Rakefile')
    system_with_command_output('rails new ' + DUMMY_APP)
    puts "Updating gemfile"

    gemfile_content = <<-EOV
    gem 'curate', :path=>'../../../#{File.expand_path('../../', __FILE__).split('/').last}'
    gem 'capybara'
    gem 'launchy'
    gem 'factory_girl_rails'
    gem 'timecop'
    gem 'vcr'
    gem 'webmock'
    gem 'rspec-html-matchers'
    gem 'database_cleaner', '< 1.1.0', :group => :test
    gem 'test_after_commit', group: :test
    gem 'poltergeist', group: :test
    gem 'simplecov', group: :test, require: false
    gem 'coveralls', group: :test, require: false
    gem 'kaminari', github: 'harai/kaminari', branch: 'route_prefix_prototype'
EOV
    gemfile_content << "gem 'debugger'" unless ENV['TRAVIS']

    `echo "#{gemfile_content}" >> #{DUMMY_APP}/Gemfile`


    puts "Copying generator"
    system_with_command_output("cp -r spec/skeleton/* #{DUMMY_APP}")
    Bundler.with_clean_env do
      within_test_app do
        system_with_command_output("bundle install")
        system_with_command_output("rails generate test_app")

        # These factories are autogenerated and conflict with our factories
        system_with_command_output('rm test/factories/users.rb')
        system_with_command_output("rake db:migrate db:test:prepare")
      end
    end
  end
  puts "Done generating test app"
end

task :spec do
  Bundler.with_clean_env do
    within_test_app do
      Rake::Task['rspec'].invoke
    end
  end
end

desc "Run specs"
RSpec::Core::RakeTask.new(:rspec) do |t|
  t.pattern = '../**/*_spec.rb'
  t.rspec_opts = ["--colour -I ../", '--tag ~js:true', '--backtrace', '--profile 20']
end


desc 'Run specs on travis'
task :ci => [:regenerate] do
  ENV['RAILS_ENV'] = 'test'
  ENV['TRAVIS'] = '1'
  Jettywrapper.unzip
  jetty_params = Jettywrapper.load_config
  error = Jettywrapper.wrap(jetty_params) do
    Rake::Task['spec'].invoke
  end
  raise "test failures: #{error}" if error
end
