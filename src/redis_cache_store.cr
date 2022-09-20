require "cache"
require "redis"

module Cache
  # A cache store implementation which stores data in Redis.
  #
  # ```
  # cache = Cache::RedisCacheStore(String, String).new(expires_in: 1.minute)
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
    SCAN_BATCH_SIZE = 1000

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
      @cache.set(namespace_key(key), value, expires_in.total_seconds.to_i)
    end

    private def read_impl(key : K)
      @cache.get(namespace_key(key))
    end

    def delete(key : K) : Bool
      @cache.del(namespace_key(key)) == 1_i64
    end

    def exists?(key : K) : Bool
      @cache.exists(namespace_key(key)) == 1
    end

    def increment(key : K, amount = 1)
      @cache.incrby(namespace_key(key), amount)
    end

    def decrement(key : K, amount = 1)
      @cache.decrby(namespace_key(key), amount)
    end

    def clear
      if @namespace
        delete_matched("*", @namespace.not_nil!)
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

    private def namespace_key(key : String) : String
      if @namespace
        "#{@namespace}:#{key}"
      else
        key
      end
    end
  end
end
