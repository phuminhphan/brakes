# brakes
Gather brakes and rotor prices

# To get started, please follow these steps
- Install RVM (Ruby version manager)
- Git clone https://github.com/phuminhphan/brakes.git
- cd into brakes
- RVM will prompt to install ruby 2.3.3 and will automatically create gemset (called 'brakes')
- Please install a local MySQL into your MAC
- Install MySQL WorkBench
- Open up MySQL WorkBench and create a new user and password based in config/database.yml
- `gem install bundler` # We need the bundler gem to bundle install
- `bundle install`  # Installs all gems/dependencies found in Gemfile
- `rake db:create`  # Creates database called brake_dev
- `rake db:migrate`
- `rails s`     # Starts the server