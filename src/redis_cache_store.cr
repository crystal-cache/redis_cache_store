require "cache"
require "redis"

module Cache
  # A cache store implementation which stores data in Redis.
  #
  # ```
  # cache = Cache::RedisCacheStore(String, String).new(expires_in: 1.minute, namespace: "myapp-cache")
  #
  # # Fetches data from the Redis, using "myapp-cache:today" key. If there is data in
  # # the REdis with the given key, then that data is returned.
  # #
  # # If there is no such data in the Redis (a cache miss or expired), then
  # # block will be written to the Redis under the given cache key, and that
  # # return value will be returned.
  # cache.fetch("today") do
  #   Time.utc.day_of_week
  # end
  # ```
  #
  # This assumes Redis was started with a default configuration, and is listening on localhost, port 6379.
  #
  # You can connect to Redis by instantiating the `Redis` or `Redis::PooledClient` class.
  #
  # If you need to connect to a remote server or a different port, try:
  #
  # ```
  # redis = Redis.new(host: "10.0.1.1", port: 6380, password: "my-secret-pw", database: 1)
  # cache = Cache::RedisCacheStore(String, String).new(expires_in: 1.minute, cache: redis)
  # ```
  struct RedisCacheStore(K, V) < Store(K, V)
    @cache : Redis | Redis::PooledClient

    # The maximum number of entries to receive per SCAN call.
    private SCAN_BATCH_SIZE = 1000

    getter expires_in, namespace

    # Creates a new Redis cache store.
    #
    # No `namespace` is set by default. Provide one if the Redis cache
    # server is shared with other apps:
    #
    # ```
    # Cache::RedisCacheStore(String, String).new(expires_in: 1.minute, namespace: "myapp-cache")
    # ```
    def initialize(@expires_in : Time::Span, @cache = Redis::PooledClient.new, @namespace : String? = nil)
    end

    private def write_impl(key : K, value : V, *, expires_in = @expires_in)
      @cache.set(key, value, expires_in.total_seconds.to_i)
    end

    private def read_impl(key : K)
      @cache.get(key)
    end

    def delete_impl(key : K) : Bool
      @cache.del(key) == 1_i64
    end

    def exists_impl(key : K) : Bool
      @cache.exists(key) == 1
    end

    # Increment a cached value. This method uses the Redis incr atomic operator.
    #
    # Calling it on a value not stored will initialize that value to zero.
    def increment(key : K, amount = 1)
      key = namespace_key(key)

      @cache.incrby(key, amount).tap do
        write_key_expiry(key)
      end
    end

    # Decrement a cached value. This method uses the Redis decr atomic operator.
    #
    # Calling it on a value not stored will initialize that value to zero.
    def decrement(key : K, amount = 1)
      key = namespace_key(key)

      @cache.decrby(key, amount).tap do
        write_key_expiry(key)
      end
    end

    private def write_key_expiry(key : K)
      @cache.expire(key, @expires_in.total_seconds.to_i)
    end

    # Clear the entire cache on all Redis servers.
    # Safe to use on shared servers if the cache is namespaced.
    def clear
      if (namespace = @namespace)
        delete_matched("*", namespace)
      else
        @cache.flushdb
      end
    end

    # `matcher` is Redis KEYS glob pattern.
    #
    # See https://redis.io/commands/keys/ for details
    private def delete_matched(matcher : String, namespace : String)
      parent = namespace_key(matcher)
      cursor = "0"

      loop do
        # Fetch keys in batches using SCAN to avoid blocking the Redis server.
        cursor, keys = @cache.scan(cursor, match: parent, count: SCAN_BATCH_SIZE)

        @cache.del(keys)

        break if cursor == "0"
      end
    end

    def redis
      @cache
    end

    def inspect
      "#<" +
        [
          self.class,
          "redis=#{@cache.inspect}",
          "expires_in=#{expires_in.inspect}",
          "namespace=#{namespace.inspect}",
        ].join(' ') +
        ">"
    end
  end
end
