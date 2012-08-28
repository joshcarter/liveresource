module LiveResource
  module Attributes
    def remote_modify(*attributes, &block)
# TODO: support single attribute or list of attributes
#
#       unless methods.map { |m| m.to_sym }.include?(attribute.to_sym)
#         raise ArgumentError.new("remote_modify: no such attribute '#{attribute}'")
#       end
#
#       unless block
#         raise ArgumentError.new("remote_modify requires a block")
#       end
#
#       # Optimistic locking implemented along the lines of:
#       #   http://redis.io/topics/transactions
#       loop do
#         # Watch/get the value
#         redis_space.attribute_watch(attribute)
#         v = redis_space.attribute_get(attribute)
#
#         # Block modifies the value
#         v = block.call(v)
#
#         # Set to new value; if ok, we're done. Otherwise we'll loop and
#         # try again with the new value.
#         redis_space.multi
#         redis_space.attribute_set(attribute, v)
#         break if redis_space.exec
#       end
    end
  end
end
