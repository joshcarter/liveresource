LiveResource
============

LiveResource is a framework for coordinating processes and status within a distributed system. It provides the following abilities:

* Call methods on objects in other threads and processes. Synchronous and asynchronous calling supported, arguments and return values are serialized properly (YAML by default), exceptions are also propagated back to the caller.

* Set attributes that other threads and processes can use.

* Subscribe to attribute updates; receive callback when new value is set.

These support a variety of use models, for example:

* Web application (Rails, Sinatra, etc.) which needs to gather state from multiple places and render it on a web page. The app should never block for long in its render path, so it either needs state *right now* or it needs to render something about the state not being available. Since daemons that know that state may be busy (blocked on IO, for example), they really need to *push* the state into LiveResource when they can, and let the GUI pull it when needed.

* Process needs to efficiently monitor the state of another daemon. The monitoring process should stay blocked until something interesting comes up -- in this case, when a remote attribute changes value. For example, a process that pings network routers notices that a router isn't responding, so it updates a list (remote attribute) of online routers. An email notifier process is subscribed to that attribute, wakes up, and notices that the router list is one router light. It then generates an email to an unhappy system administrator.

* Processes that need to call into another process to do a job. In our router example above, the system administrator fixes the router and wants it monitored again. The sysad uses a web app to re-instate the router, and the web app calls an remote method (asynchronously) on the ping process to update its list.

LiveResource is built for Ruby and is designed to be familiar to Ruby programmers. It uses terms which are as Ruby-esque as possible instead of borrowing from other domains (pub/sub, RMI, and so forth).

The underlying tools, however, are available to any language: Redis is the hub for communications, and all objects are stored with YAML encoding. Ports to other languages would be straightforward (and may be forthcoming).

## Requirements

LiveResource requires:

* [Redis 2.2+.](http://redis.io/) server. (Redis 1.x does not support commands needed by LiveResource.)

* [redis-rb](https://github.com/ezmobius/redis-rb) gem.

## Attributes

Here's a simple attribute publisher:

    class FavoriteColorPublisher
      include LiveResource::Attribute

      remote_writer :favorite
    end
    
    publisher = FavoriteColorPublisher.new
    publisher.namespace = "color"
    publisher.favorite = "blue"

The publisher demonstrates several points:

* LiveResource features are defined in modules -- you include what you need for your use. This publisher only uses `Attribute`. Other modules are `Subscriber`, `MethodProvider`, and `MethodSender`.

* "Remote" Attributes are defined much like Ruby's attributes: `remote_reader`, `remote_writer`, and `remote_accessor` are used to automatically create methods for reading and writing a given attribute.

* LiveResource attributes have a namespace, which is simply a string to identify the resource. If multiple attribute writers use the same namespace (even if they are in separate processes) an assignment to one will overwrite the others.

Let's create a class which can access the above-published favorite color:

    class FavoriteColor
      include LiveResource::Attribute

      remote_reader :favorite
    end

    reader = FavoriteColor.new
    reader.namespace = "color"
    reader.favorite # --> "blue"

Not real fancy, but consider that this object could be running in a separate process. Further, let's explicitly assign a Redis client instance to both objects:

    # On machine A
    publisher.redis = Redis.new(:hostname => 'machine-c.local')
    
    # On machine B
    reader.redis = Redis.new(:hostname => 'machine-c.local')
    
Now this code can run on separate machines.

Note that attributes can be set to any Ruby objects; they are automatically marshaled using YAML. (If you want to create a LiveResource-like interface in another programming language, you just need a Redis client and YAML.)

## Attribute Read-Modify-Write

Reading an attribute is an atomic operation; so is writing one. However, sometimes you need to read, modify, and write an attribute as an atomic operation. LiveResource provides a special notation for that:

    class FavoriteColorPublisher
      include LiveResource::Attribute

      remote_accessor :favorite

      # Update favorite color to anything except the currently-published
      # favorite.
      def update_favorite
        colors = ['red', 'blue', 'green']

        remote_modify(:favorite) do |current_favorite|
          colors.delete(current_favorite)

          # Value of block will become the new value of the attribute.
          colors.shuffle.first
        end
      end
    end

The method `remote_modify` takes the attribute to modify (as as symbol) and a block. The block is provided the current value of the attribute; the ending value of the block becomes the new attribute value.

Rather than perform locking on an attribute (which would slow down *all* reads and writes), LiveResource performs *optimistic locking* thanks to features in Redis. If the value of the attribute changes while the `remote_modify` block is executing, LiveResource simply replays the block with the changed value. This preserves the performance of attribute read/write and eliminates potential deadlocks.

As a consequence, however, the **block passed to `remote_modify` should not change external state that relies on the block only executing once.**

## Attribute Subscribers

Attribute get/set is useful for publishing state in one place, then reading it in another. However, in some cases you want on object that monitors a state and performs an action when it changes. An example:

    class FavoriteColorSubscriber
      include LiveResource::Subscriber

      remote_subscription :favorite

      def favorite(new_favorite)
        puts "Publisher changed its favorite to #{new_favorite}"
      end
    end

    subscriber = FavoriteColorSubscriber.new
    subscriber.namespace = "color"
    subscriber.subscribe # Spawns thread

    # Publisher object from the "Attribute" section above.
    publisher.favorite = "red"
    # --> callback prints: "Publisher changed their favorite to red"
    publisher.favorite = "green"
    # --> callback prints: "Publisher changed their favorite to green"

    subscriber.unsubscribe # Stops and joins callback thread

While the subscription thread is running, the `favorite` method in this subscriber will called any time a new favorite color is published. If desired, you can explicitly set a different callback method name:

    remote_subscription :favorite, :my_callback_method

Callbacks take one parameter, the newly-published value.

Note that the callback thread stays blocked when it's not executing a callback; it does not spin and poll Redis.

## Methods

Finally, LiveResource allows method calling from one object to another. Like attributes, it works great across processes and machines. An example:

    class Server
      include LiveResource::MethodProvider

      remote_method :divide

      def divide(dividend, divisor)
        raise ArgumentError.new("cannot divide by zero") if divisor == 0
    
        dividend / divisor
      end
    end

    class Client
      include LiveResource::MethodSender
  
      def fancy_process(a, b)
        begin
          puts remote_send :divide, a, b
        rescue ArgumentError => e
          puts "oops, I messed up: #{e}"
        end
      end
    end

    s = Server.new
    s.namespace = "math"
    s.start_method_dispatcher

    c = Client.new
    c.namespace = "math"
    c.fancy_process(10, 5)
    c.fancy_process(1, 0)

    s.stop_method_dispatcher

The provider includes `MethodProvider` and uses the `remote_method` declaration to tell LiveResource what methods it provides. Method senders include `MethodSender` and there are a couple of ways to send a method:

* `remote_send` is the most similar to Ruby's built-in `send`: it waits for the method to complete and gives you back the method's return value.

* `remote_send_async` allows the sender to fire off a method without blocking. `remote_send_async` returns a token that the caller can later pass to `done_with?` or `wait_for_done`. To get the method's return value, `wait_for_done` will block (if needed) for the remote method to complete and give you the return value. To check on a method without blocking, call `done_with?` which returns true if the method is complete.

The provider must run a thread that dispatches methods. This stays blocked except when a method is executing. If a Ruby process only exists to be a LiveResource method provider, you could use a construct like this to block the initial thread until an interrupt signal is received:

    Signal.trap("INT") { s.stop_method_dispatcher }
    s.start_method_dispatcher.join

As with normal Ruby method calls, the number of parameters passed into `remote_send` must match the number of parameters expected by the method. If these don't match, an `ArgumentError` will be raised.

If an exception is raised by the method provider, that exception is trapped by LiveResource and raised by whoever is getting the method's return value. Thus `remote_send` and `wait_for_done` will raise any exceptions thrown by the remote method.

## To-Do

(This section is my to-do list for future versions of LiveResource. -jdc)

Enhance subscriber notation, use hash for options:

    class C
      include LiveResource::Subscriber

      # List of symbols implies subscription with callback methods 
      # of the same name.
      remote_subscription :foo, :bar
      
      # Hash (or list of hashes) implies subscriptions with callback
      # methods explicitly specified.
      remote_subscription :baz => :method
    end

Simplify setting the namespace when it's the same for all instances of a class:

    class C
      include LiveResource::Attribute
  
      # Current way to set it (works great for per-instance namespaces):
      def initialize(namespace)
        self.namespace = namespace
      end
  
      # Additional way (would be great for per-class namespace):
      remote_namespace 'foo.bar'
    end

Useful namespace default when none is set explicitly (e.g., pid of current process).

Investigate odd benchmark results (4 core/8 thread Xserve, local Redis process):

- Best attribute read/write performance with one thread; seems like we'd do better with multiple due to IO multiplexing if nothing else. (Perhaps my benchmark is busted.)  -->  On further thought, I'm pretty sure the Redis gem is using a single client for all threads. This would be a plausible explanation since the one client is blocked during IO.

- Best method call performance is synchronous with one thread.  -->  Also sharing one client?

Port all tests from old/state_publisher_test.rb.

Finish rdoc, test to make sure it looks right.

Meaningful examples, e.g. iostat.

Race condition when method transitions from in-progress to done:

    1) Error:
    test_wait_for_done_after_done(MethodTest):
    ArgumentError: No method 56329 pending
      ./lib/live_resource/method_sender.rb:56:in `done_with?'
      ./test/method_test.rb:159:in `test_wait_for_done_after_done'
      ./test/method_test.rb:103:in `call'
      ./test/method_test.rb:103:in `with_servers'
      ./test/method_test.rb:154:in `test_wait_for_done_after_done'
      /Library/Ruby/Gems/1.8/gems/mocha-0.9.10/lib/mocha/integration/test_unit/ruby_version_186_and_above.rb:22:in `__send__'
      /Library/Ruby/Gems/1.8/gems/mocha-0.9.10/lib/mocha/integration/test_unit/ruby_version_186_and_above.rb:22:in `run'

## Future Plans

Integrate (or merge) with ActiveService for automatic discovery of resources.

## Contributors

* Josh Carter: original author
* Rob Grimm: TTL on remote_writer (thanks Rob!)
