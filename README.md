# Kamome

https://circleci.com/gh/t1732/kamome.svg?style=shield&circle-token=fdf9c64cff4f286a7b20f12b77ed4779c2d06425

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

```ruby
class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :name
      t.timestamps
    end
  end
end
```

```ruby
class User < ActiveRecord::Base
  kamome
end
```

```
Kamome.target = :blue
User.create!(name: "blue")

Kamome.target = :green
User.create!(name: "green")
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/kamome/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
