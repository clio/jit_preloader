# JitPreloader

N+1 queries are a silent killer for performance. Sometimes they can be noticeable; other times they're just a minor tax. We want a way to remove them.

Imagine you have contacts that have many emails, phone numbers, and addresses. You might have code like this:

```ruby
def do_my_thing(contact)
  contact.emails.each do |email|
    # Do a thing with the email
  end
  contact.phone_numbers.each do |phone_number|
    # Do a thing with the phone number
  end
end

# This will generate two N+1 queries, one for emails and one for phone numbers.
Contact.all.each do |contact|
  do_my_thing(contact)
end
```

Rails solves this with `includes` (or better, `preload`/`eager_load`, as they are what `includes` uses in the background). So to get around this problem in Rails you would do something like this:

```ruby
Contact.preload(:emails, :phone_numbers).each do |contact|
  do_my_thing(contact)
end
```

However this does have some limitations.

1) When doing the `preload`, you have to understand what the code does in order to properly load the associations. When this is a brand new method or a simple method this may be simple, but sometimes it can be difficult or time-consuming to figure this out.

2) Imagine we change the method to also use the `addresses` association:

```ruby
def do_my_thing(contact)
  contact.emails.each do |email|
    # Do a thing with the email
  end
  contact.phone_numbers.each do |phone_number|
    # Do a thing with the phone number
  end
  contact.addresses.each do |address|
    # Do a thing with the address
  end
end
```

All of a sudden we have an N+1 query again. So now you need to go hunt down all of the places were you were preloading and preload the new association.

3) Imagine we change the method to do this:

```ruby
def do_my_thing(contact)
  contact.emails.each do |email|
    # Do a thing with the email
  end
end
```

We don't have an N+1 query here, but now we are preloading the `phone_numbers` association but not doing anything with it. This is still bad, especially when there are a lot of associations on the object.

This gem provides a "magic bullet" that can remove most N+1 queries in the application.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'jit_preloader'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install jit_preloader

## Usage

This gem provides three features:

### N+1 query tracking

This gem will publish an `n_plus_one_query` event via ActiveSupport::Notifications whenever it detects one. This lets you do a variety of useful things. Here are some examples:

You could implement some basic tracking. This will let you measure the extent of the N+1 query problems in your app:
```ruby
ActiveSupport::Notifications.subscribe("n_plus_one_query") do |event, data|
  statsd.increment "web.#{Rails.env}.n_plus_one_queries.global"
end
```

You could log the N+1 queries. In your development environment, you could throw N+1 queries into the logs along with a stack trace:
```ruby
ActiveSupport::Notifications.subscribe("n_plus_one_query") do |event, data|
  message = "N+1 Query detected: #{data[:association]} on #{data[:source].class}"
  backtrace = caller.select{|r| r.starts_with?(Rails.root.to_s) }
  Rails.logger.debug("\n\n#{message}\n#{backtrace.join("\n")}\n".red)
end
```

If you use rspec, you could wrap your specs in an `around(:each)` that throws an exception if an N+1 query is detected. You could even provide a tag that allows tests that have known N+1 queries to still pass:
```ruby
config.around(:each) do |example|
  callback = ->(event, data) do
    unless example.metadata[:known_n_plus_one_query]
      message = "N+1 Query detected: #{data[:source].class} on #{data[:association]}"
      raise QueryError.new(message)
    end
  end
  ActiveSupport::Notifications.subscribed(callback, "n_plus_one_query") do
    example.run
  end
end
```

### Jit preloading on a case-by-case basis

There is now a `jit_preload` and `jit_preload!` method on ActiveRecord::Relation objects. This means instead of using `includes`, `preload` or `eager_load` with the association you want to load, you can simply just use `jit_preload`

```ruby
# old
Contact.preload(:addresses, :email_addresses).each do |contact|
  contact.addresses.to_a
  contact.email_addresses.to_a
end

# new
Contact.jit_preload.each do |contact|
  contact.addresses.to_a
  contact.email_addresses.to_a
end
```

### Loading aggregate methods on associations

There is now a `has_many_aggregate` method available for ActiveRecord::Base. This will dynamically create a method available on objects that will allow making aggregate queries for a collection.

```ruby
# old
Contact.all.each do |contact|
  contact.addresses.maximum("LENGTH(street)")
  contact.addresses.count
end
# SELECT * FROM contacts
# SELECT MAX(LENGTH(street)) FROM addresses WHERE contact_id = 1
# SELECT COUNT(*) FROM addresses WHERE contact_id = 1
# SELECT MAX(LENGTH(street)) FROM addresses WHERE contact_id = 2
# SELECT COUNT(*) FROM addresses WHERE contact_id = 2
# SELECT MAX(LENGTH(street)) FROM addresses WHERE contact_id = 3
# SELECT COUNT(*) FROM addresses WHERE contact_id = 3
# ...

#new
class Contact < ActiveRecord::Base
  has_many :addresses
  has_many_aggregate :addresses, :max_street_length, :maximum, "LENGTH(street)", default: nil
  has_many_aggregate :addresses, :count_all, :count, "*"
end

Contact.jit_preload.each do |contact|
  contact.addresses_max_street_length
  contact.addresses_count_all
end
# SELECT * FROM contacts
# SELECT contact_id, MAX(LENGTH(street)) FROM addresses WHERE contact_id IN (1, 2, 3, ...) GROUP BY contact_id
# SELECT contact_id, COUNT(*) FROM addresses WHERE contact_id IN (1, 2, 3, ...) GROUP BY contact_id

```

### Preloading a subset of an association

There are often times when you want to preload a subset of an association, or change how the SQL statement is generated. For example, if a `Contact` model has
an `addresses` association, you may want to be able to get all of the addresses that belong to a specific country without introducing an N+1 query.
This is a method `preload_scoped_relation` that is available that can handle this for you.

```ruby
#old
class Contact < ActiveRecord::Base
  has_many :addresses
  has_many :usa_addresses, ->{ where(country: Country.find_by_name("USA")) }
end

Contact.jit_preload.all.each do |contact|
  # This will preload the association as expected, but it must be defined as an association in advance
  contact.usa_addresses

  # This will preload as the entire addresses association, and filters it in memory
  contact.addresses.select{|address| address.country == Country.find_by_name("USA") }

  # This is an N+1 query
  contact.addresses.where(country: Country.find_by_name("USA"))
end

# New
Contact.jit_preload.all.each do |contact|
  contact.preload_scoped_relation(
    name: "USA Addresses",
    base_association: :addresses,
    preload_scope: Address.where(country: Country.find_by_name("USA"))
  )
end
# SELECT * FROM contacts
# SELECT * FROM countries WHERE name = "USA" LIMIT 1
# SELECT "addresses".* FROM "addresses" WHERE "addresses"."country_id" = 10 AND "addresses"."contact_id" IN (1, 2, 3, ...)
```

### Jit preloading globally across your application

The JitPreloader can be globally enabled, in which case most N+1 queries in your app should just disappear. It is off by default.

```ruby
# Can be true or false
JitPreloader.globally_enabled = true

# Can also be given anything that responds to `call`.
# You could build a kill switch with Redis (or whatever you'd like)
# so that you can turn it on or off dynamically.
JitPreloader.globally_enabled = ->{ $redis.get('always_jit_preload') == 'on' }

# When enabled globally, this would not generate an N+1 query.
Contact.all.each do |contact|
  contact.emails.each do |email|
    # do something
  end
end
```

## What it doesn't solve

This is mostly a magic bullet, but it doesn't solve all database-related problems. If you reload an association, or call a query or aggregate function on the association, it will not remove those extra queries. These problems cannot be solved by using Rails' `preload` so it cannot be solved with the Jit Preloader.

```ruby
Contact.all.each do |contact|
  contact.emails.reload                         # Reloading the association
  contact.addresses.where(billing: true).to_a   # Querying the association (Use: preload_scoped_relation to avoid these)
end
```

## Consequences

1) This gem introduces more Magic. This is fine, but you should really understand what is going on under the hood. You should understand what makes an N+1 query happen and what this gem is doing to help address it.

2) We may do more work than you require. If you have turned the preloader on globally but you only want to access a single record's association, it will load the association for the entire collection you were looking at.

3) Each result set will have a JitPreloader setup on it, and the preloader will have a reference to all of the other objects in a result set. This means that so long as one object of that result set exists in memory, the others will not be cleaned up by the garbage collector. This shouldn't have much impact, but it's good to be aware of it.

## Contributing

1. Fork it ( https://github.com/clio/jit_preloader/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
