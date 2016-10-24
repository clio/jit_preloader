# JitPreloader

N+1 queries are a silent killer to performance. Sometimes they can be noticable, other times that are just a minor tax. We want a way to remove them. 

Imagine you have contact that have many emails, phone numbers, and addresses. You could have this:

```ruby
def do_my_thing(contact)
  contact.emails.each do |email|
    # Do a thing with the email
  end
  contact.phone_numbers.each do |phone|
    # Do a thing with the phone
  end
end

# This will generate an N+1 query for emails and phone numbers. 
Contact.all.each do |contact|
  do_my_thing(contact)
end
```

Rails does have a solution for this with `includes` (or better `preload`/`eager_load` as it is what `includes` uses in the background). So to get around this problem in Rails you would do something like this:

```ruby
Contact.preload(:emails, :phone_numbers).each do |contact|
  do_my_thing(contact)
end
```

However this does have some limitations. 

1) When doing the preload, you have to understand what the code does in order to properly load the associations. When this is a brand new method or a simple method this may be simple, but it can be difficult or time consuming to figure this out. 

2) Imagine we change the method to do this:

```ruby
def do_my_thing(contact)
  contact.emails.each do |email|
    # Do a thing with the email
  end
  contact.phone_numbers.each do |phone|
    # Do a thing with the phone
  end
  contact.addresses.each do |address|
    # Do a thing with the address
  end
end
```

All of a sudden we have an N+1 query again. So now you need to go hunt down all of the places were you were preloading and preload the extra association. 

3) Imagine we change the method to do this:

```ruby
def do_my_thing(contact)
  contact.emails.each do |email|
    # Do a thing with the email
  end
end
```

We don't  have an N+1 query here, but now we are preloading the `phone_numbers` association but not doing anything with it. This is still bad, especially when there is a lot of associations on the object. 

This gem provides a "magic" bullet that can remove most N+1 queries in the application. 


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

This gem provides three things that can be used:

1) N+1 query tracking

This gem will publish an event "n_plus_one_query" via ActiveSupport::Notifications whenever it detects one. This can let you do whatever might be useful for you. Here are some examples

You could implement some basic tracking. This will let you understand to what degree your app has N+1 query problems and then you can measure it once you start using the Jit preloader
```ruby
ActiveSupport::Notifications.subscribe("n_plus_one_query") do |event, data|
  statsd.increment "web.#{Rails.env}.n_plus_one_queries.global"
end
```

You could implement it as some logging. This may be useful for a development environment so that N+1 instances are thrown into the logs as a stack trace. 
```ruby
ActiveSupport::Notifications.subscribe("n_plus_one_query") do |event, data|
  message = "N+1 Query detected: #{data[:association]} on #{data[:source].class}"
  backtrace = caller.select{|r| r.starts_with?(Rails.root.to_s) }
  Rails.logger.debug("\n\n#{message}\n#{backtrace.join("\n")}\n".red)
end
```

If you use rspec, you could wrap your specs in an around each that throws an exception if an N+1 query is detected. You could even provide a tag that allows tests that have known N+1 queries to pass still. 
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

2) Jit preloading on a case-by-case basis

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

3) Jit preloading globally across your application

The JitPreloader can be globally enabled in which case most N+1 queries in your will should just disappear. It is off by default

```ruby
# Can be assigned true or false
JitPreloader.globally_enabled = true

# Can also be given anything that responds to `call`. 
# You could build a kill switch with Redis (or whatever you'd like) so that you can turn in on or off dynamically
JitPreloader.globally_enabled = ->{ $redis.get('always_jit_preload') == 'on' }

# When enabled globally, this would not generate an N+1 query. 
Contact.all.each do |contact|
  do_my_thing(contact)
end


```

## What it doesn't solve

This is mostly a magic bullet, but it doesn't solve all problems. If you reload an association, excecute a query, or use an aggregate function on the association it will not remove that. These problems cannot be solved by using Rails' `preload` so it cannot be solved with the Jit Preloader

```ruby
Contact.all.each do |contact|
  contact.emails.reload # Reloading the association
  contact.phone_numbers.max("LENGTH(number)") # Aggregate functions
  contact.addresses.where(billing: true).to_a # Exuecting a new query
end
```

## Consequences

1) This gem introduces more Magic. This is fine, but you should really understand what is going on under the hood. You should understand what makes an N+1 query and what this gem is doing to help address it. 

2) We may do more work than you require. If you have turned the preloader on Globally and you only want to access a single record's association, it will load the association for the entire collection you were looking at. 

3) Each record result set will have a JitPreloader setup on it, and the preloader will have a reference to all of the other objects in a result set. This means that so long as one object of that result set exists in memory, the others will not be cleaned up with the garbage collection. This shouldn't impact much, but it is best to acknowledge it. 

## Contributing

1. Fork it ( https://github.com/[my-github-username]/jit_preloader/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
