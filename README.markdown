LiveResource
============

This is an in-progress framework for resource discovery, operations, and
notifications. I'll update this file when it's more fully baked.

To-Do
-----

- Replace trace methods with logger.

- Lots of duplication between worker and LR, need to merge worker into LR or maybe extract Redis interactions into its own class.

- Finish rdoc, test to make sure it looks right.

- Meaningful examples, e.g. iostat.



References
----------

* [Google Protocol Buffers docs][1]
* [Protocol Buffers for Ruby][2]

[1]: http://code.google.com/apis/protocolbuffers/docs/proto.html
[2]: http://code.google.com/p/ruby-protobuf/
