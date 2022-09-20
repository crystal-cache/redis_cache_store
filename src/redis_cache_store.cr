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

    def initialize(@expires_in : Time::Span, @cache = Redis.new)
    end

    private def write_impl(key : K, value : V, *, expires_in = @expires_in)
      @cache.set(key, value, expires_in.total_seconds.to_i)
    end

    private def read_impl(key : K)
      @cache.get(key)
    end

    def delete(key : K) : Bool
      @cache.del(key) == 1_i64
    end

    def exists?(key : K) : Bool
      @cache.exists(key) == 1
    end

    def increment(key : K, amount = 1)
      @cache.incrby(key, amount)
    end

    def decrement(key : K, amount = 1)
      @cache.decrby(key, amount)
    end

    def clear
      @cache.flushdb
    end
  end
end
