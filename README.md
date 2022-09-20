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
cache = Cache::RedisCacheStore(String, String).new(expires_in: 1.minute)
cache.fetch("today") do
  Time.utc.day_of_week
end
```

No `namespace` is set by default. Provide one if the Redis cache
server is shared with other apps:

```crystal
Cache::RedisCacheStore(String, String).new(expires_in: 1.minute, namespace: "myapp-cache")
```

This assumes Redis was started with a default configuration, and is listening on localhost, port 6379.

You can connect to Redis by instantiating the `Redis` or `Redis::PooledClient` class.

If you need to connect to a remote server or a different port, try:

```crystal
redis = Redis.new(host: "10.0.1.1", port: 6380, password: "my-secret-pw", database: 1)
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
