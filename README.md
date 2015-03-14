# Kamome

![build status](https://circleci.com/gh/t1732/kamome.svg?style=shield&circle-token=fdf9c64cff4f286a7b20f12b77ed4779c2d06425)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'kamome', github: 't1732/kamome'
```

And then execute:

```
bundle install
```

## Usage

Rails >= 4.2

### Configuration

* example database.yml

```yaml
defaults: &defaults
  adapter: mysql2
  encoding: utf8
  pool: 5
  username: root
  password:
  host: 127.0.0.1

development:
  <<: *defaults
  database: kamome_development

test:
  <<: *defaults
  database: kamome_test
```

* example kamome.yml

```yaml
defaults: &defaults
  adapter: mysql2
  encoding: utf8
  pool: 5
  username: root
  password:
  host: 127.0.0.1

development:
  blue:
    <<: *defaults
    database: kamome_blue_development
  green:
    <<: *defaults
    database: kamome_green_development

test:
  blue:
    <<: *defaults
    database: kamome_blue_test
  green:
    <<: *defaults
    database: kamome_green_test
```

### Models

```ruby
class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.timestamps
    end
  end
end
```

```ruby
class User < ActiveRecord::Base
  kamome
  validats :name, presence: true
end
```

```ruby
Kamome.target = :blue
User.create!(name: "blue")
Kamome.target = :green
User.create!(name: "green")
```

### Switched temporarily

```ruby
Kamome.target = :blue
User.create!(name: "blue")
Kamome.anchor(:green) do
  User.create!(name: "green")
end
```

## Targetting Transaction

The default transaction is directed to a database that is set in database.yml

```ruby
Kamome.target = :blue
ActiveRecord::Base.transaction do
  User.create!(name: 'blue')
  User.create! # validation error
end
User.count #=> 1
```

```ruby
Kamome.target = :blue
Kamome.transaction do
  User.create!(name: 'blue')
  User.create!
end
User.count #=> 0
```

transaction of default kamome is directed to a database that is specified in the Kamome.target

```ruby
Kamome.target = :blue
Kamome.transaction do
  Kamome.anchor(:green) do
    User.create!(name: 'green')
    User.create!
  end
end
Kamome.target = :green
User.count #=> 1
```

```ruby
Kamome.target = :blue
Kamome.transaction(:blue, :green) do
  Kamome.anchor(:green) do
    User.create!(name: "green")
  end
  User.create!(name: "blue")
  User.create! # validation error
end
User.count #=> 1
Kamome.target = :green
User.count #=> 0
```

or

```ruby
Kamome.full_transaction do
  # transaction kamome.yml all targets
end
```

## Customize

### config path

* sample config/initializers/kamome.rb

```ruby
Rails.application.config.to_prepare do
  Kamome.configure do |config|
    config.config_path = "/tmp/kamome.yml"
  end
end
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/kamome/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
