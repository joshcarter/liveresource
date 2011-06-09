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

LiveResource requires access to a Redis 2.2+ server. It has been tested primarily with Redis 2.2.x and 2.3.0. Redis 1.x will not work.

## To-Do

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
