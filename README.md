LiveResource 2
==============

LiveResource is a framework for coordinating processes, statuses, and
messaging within a distributed system. It provides the following
abilities:

* Call methods on objects in other threads and processes, locally or
  on remote machines. Synchronous and asynchronous calling supported,
  arguments and return values are serialized, exceptions are also
  propagated back to the caller.

* Set attributes that other threads and processes can see.

These support a variety of use models, for example:

* Web application (Rails, Sinatra, etc.) which needs to gather state
  from multiple places and render it on a web page. The app should
  never block for long in its render path, so it needs to pull the
  state *right now*. Daemons that know the state may be busy (blocked
  on IO, for example), so they should *push* state into LiveResource
  when they can, and let the GUI pull it when needed.

* Processes that need to call into another process to do a job. Any
  process can search the list of resources by resource class, either
  looking for a specific instance by name, grabbing any, or iterating
  over all of them. It can call methods synchronously, looking just
  like a Ruby method call, or async and check for the result later.

LiveResource is built for Ruby and is designed to be familiar to Ruby
programmers. It uses terms which are as Ruby-esque as possible instead
of borrowing from other domains (pub/sub, RMI, and so forth).

The underlying tools, however, are available to any language: Redis is
the hub for communications, and all objects are stored with YAML
encoding. Ports to other languages would be straightforward (and may
be forthcoming).

**NOTE: LiveResource 2 introduces significant improvements in its API,
but breaks compatibility with versions 1.x. The older API is
maintained on the `stable-1` branch.**

## Requirements

LiveResource requires:

* Ruby 1.9.3 or JRuby in 1.9 mode (`export JRUBY_OPTS=--1.9`).

* [Redis 2.2+.](http://redis.io/) server. (Redis 1.x does not support commands needed by LiveResource.)

* [redis-rb](https://github.com/ezmobius/redis-rb) gem.

## Attributes

Here's a resource with an attribute:

    class FavoriteColor
      include LiveResource::Resource

      # Set up resource class and instance naming			
      resource_class :favorite_color
      resource_name :object_id

      # Declare remote attributes
      remote_writer :favorite
    end
    
    resource = FavoriteColor.new
    resource.favorite = "blue"

This resource demonstrates several points:

* LiveResource features are defined in the Resource modules -- you can
  add LiveResource features to existing classes with little effort.

* "Remote" Attributes are defined much like Ruby's attributes:
  `remote_reader`, `remote_writer`, and `remote_accessor` are used to
  automatically create methods for reading and writing a given
  attribute.

* LiveResource instances have both a class and a name, making your
  remote interface look just like a normal Ruby object API. (When you
  don't care about naming, tell LiveResource to assign names based on
  `:object_id`.)

* By default, LiveResource connects to a Redis server at
  `localhost:6379`, but you can change any Redis client parameters you
  need to.

Now let's access the above-published favorite color:

    r = LiveResource::any(:favorite_color)
    r.favorite # --> "blue"

LiveResource includes the finders `find`, `any`, and `all`. The object
returned is a *proxy* for the real resource, which could be in a
different process or on a whole different machine.

Note that attributes can be set to any Ruby objects; they are
automatically marshaled using YAML. (If you want to create a
LiveResource interface in another programming language, you just need
a Redis client and YAML.)

## Attribute Read-Modify-Write
Reading an attribute is an atomic operation; so is writing one. However, sometimes you need to read,
modify, and write an attribute or set of attributes as an atomic operation.  LiveResource provides a
special notation for that:

    class FavoriteColor
      include LiveResource::Resource 

      # Set up resource class and instance naming			
      resource_class :favorite_color
      resource_name :object_id

      remote_accessor :old_favorite
      remote_accessor :favorite

      # Update favorite color to anything except the currently-published
      # favorite. Also save off the old favorite.
      def update_favorite
        colors = ['red', 'blue', 'green']

        remote_attribute_modify(:old_favorite, :favorite) do |attribute, value|
          # Value of block will become the new value of the given attribute.
          if attribute == :old_favorite
            # Make the old_favorite our current favorite
            self.favorite
          else
            # Choose a new favorite
            colors.delete(current_favorite)
            colors.shuffle.first
          end
        end
      end

The method `remote_attribute_modify` takes the attribute(s) to modify (as symbols) and a block. The block is
provided the attribute name and the current value of the attribute; the ending value of the block
becomes the new attribute value.

Rather than perform locking on an attribute (which would slow down *all* reads and writes), LiveResource performs *optimistic locking* thanks to features in Redis. If the value of the attribute changes while the `remote_attribute_modify` block is executing, LiveResource simply replays the block with the changed value. This preserves the performance of attribute read/write and eliminates potential deadlocks.

As a consequence, however, the **block passed to `remote_attribute_modify` should not change external state that relies on the block only executing once.**

## Methods

Attributes are good for publishing state information, but how do you
*interact* with a resource? LiveResource provides actor-like method
calling from one object to another. Like attributes, it works great
across processes and machines. An example:

    #
    # Running in process A
    #
    class MathResource
      include LiveResource::Resource

      remote_class :math
      remote_name :object_id

      def divide(dividend, divisor)
        raise ArgumentError.new("cannot divide by zero") if divisor == 0
        dividend / divisor
      end
    end

    # Creating an instances starts its method dispatcher thread.
    MathResource.new
    sleep

    # 
    # Running in processs B
    #
    m = LiveResource::any(:math)
    m.divide(10, 5) # --> 2
    m.divide(1, 0)  # --> raises ArgumentError

The resource does not need to explicitly declare its remote methods;
any public methods are automatically remote-callable. (Methods of
superclasses, however, are not remoted.) When an instance is created,
a thread is also created to service remote method calls.

When you get a resource proxy (as in process B above) there are a
couple ways to call a remote method:

* Just call the method exactly as-is, like `divide(...)`, which blocks
  the calling thread until the resource responds. If the resource's
  method raises an exception, LiveResource's method dispatcher traps
  the exception, serializes it, and the exception is raised in the
  caller's thread.

* Call asynchronously in a fire-and-forget matter by adding an
  exclamation point to the end of the method name, like
  `divide!(...)`, with the downside of not being able to get a
  response.

* Call asynchronously and get the return value later by adding a
  question mark to the end of the method name, like `divide?(...)`,
  which we'll discuss shortly.

### Call Method and Check Value Later

There are many times when blocking on a remote method isn't
acceptable. Continuing the above example, here's how to fire off the
method and come back for the result later:

    m = LiveResource::any(:math)
    m.divide?(10, 5)
    # .. do something else ..
    m.value # may block, then --> 2

    m.divide?(15, 5)
    m.done? # --> true or false
    # .. time elapses ..
    m.done? # --> true
    m.value # will not block --> 3

    m.divide?(20, 5)
    m.value(10) # wait up to 10 seconds, then --> 4

The return value from question-mark form `method?` calls is a Future,
which allows both polling, blocking, and block-with-timeout
conventions.

### Forwarding Methods

TODO: needs documentation. In the meantime, refer to
`test/method_forward_continue_test.rb`.

## Configuring the Redis Client

LiveResource will try to connect to Redis at `localhost` and its
default port, 6379. If you need to change that, or any other client
parameters, just assign a new Redis client.

    LiveResource::RedisClient.redis = Redis.new(hostname: 'machine-c.local')

## Missing LiveResource 1.x Features

Some features from 1.x have not been brought to 2.0 yet.

### Attribute Publish/Subscribe

NOTE: attribute pub/sub from LiveResource 1 is not currently supported
in LiveResource 2. It was never used within Spectra Logic, so it may
be dropped.

## To-Do

(This section is my to-do list for future versions of LiveResource. -jdc)

* More formally specify and test edge-case behaviors, for example:

  - Getting/setting attributes that don't exist.

  - Forward/continue with methods that fail, methods that time out
    because no resource is available.

  - Startup order problems with resources and clients of them. Any way
    allow clients to wait and retry?

  - Serialize exceptions in a less Ruby-specific manner.

  - Merge exception backtrace properly. (ResourceProxy#wait_for_done)

* Benchmarking: try multiple redis clients

* Tools/Debugging:

  - Text/graphical resource monitor/explorer

  - Logging: allow runtime logging level changes (possibly via built-in remote method)

  - Logging: syslog setup

* Finish rdoc, test to make sure it looks right.

## License / Copying

See the file `COPYING`.

## Contributors

LiveResource is brought to you by Josh Carter, Mark von Minden, and
Rob Grimm of Spectra Logic.
