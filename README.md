# Cache::RedisCacheStore

![Crystal CI](https://github.com/crystal-cache/redis_cache_store/workflows/Crystal%20CI/badge.svg)
[![GitHub release](https://img.shields.io/github/release/crystal-cache/redis_cache_store.svg)](https://github.com/crystal-cache/redis_cache_store/releases)

A [cache](https://github.com/crystal-cache/cache) store implementation that stores data in Redis

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     redis_cache_store:
       github: crystal-cache/redis_cache_store
   ```

2. Run `shards install`

## Usage

```crystal
require "redis_cache_store"
```

It's important to note that Redis cache value must be string.

```crystal
cache = Cache::RedisCacheStore(String, String).new(expires_in: 1.minute, namespace: "myapp-cache")

# Fetches data from the Redis, using "myapp-cache:today" key. If there is data in
# the Redis with the given key, then that data is returned.
#
# If there is no such data in the Redis (a cache miss or expired), then
# block will be written to the Redis under the given cache key, and that
# return value will be returned.
cache.fetch("today") do
  Time.utc.day_of_week
end
# => Wednesday
```

No `namespace` is set by default. Provide one if the Redis cache
server is shared with other apps:

This assumes Redis was started with a default configuration, and is listening on localhost, port 6379.

You can connect to Redis by instantiating the `Redis::Client` class.

If you need to connect to a remote server or a different port, try:

```crystal
redis_uri = URI.parse("rediss://:my-secret-pw@10.0.1.1:6380/1")
redis = Redis::Client.new(uri: redis_uri)
cache = Cache::RedisCacheStore(String, String).new(expires_in: 1.minute, cache: redis)
```

## Contributing

1. Fork it (<https://github.com/crystal-cache/redis_cache_store/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Anton Maminov](https://github.com/mamantoha) - creator and maintainer
