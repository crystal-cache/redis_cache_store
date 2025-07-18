require "./spec_helper"

describe Cache do
  context Cache::RedisCacheStore do
    Spec.before_each do
      redis = Redis::Client.new
      redis.flushdb
    end

    context "#initialize" do
      it "initialize" do
        store = Cache::RedisCacheStore(String, String).new(expires_in: 12.hours)

        store.should be_a(Cache::RedisCacheStore(String, String))
      end

      it "initialize with Redis::Client" do
        redis_uri = URI.parse("redis://localhost:6379/1")
        redis = Redis::Client.new(uri: redis_uri)
        store = Cache::RedisCacheStore(String, String).new(expires_in: 12.hours, cache: redis)

        store.should be_a(Cache::RedisCacheStore(String, String))
      end
    end

    context "instance methods" do
      it "#inspect without namescape" do
        store = Cache::RedisCacheStore(String, String).new(expires_in: 12.hours)

        store.inspect.should match(
          /\A#<Cache\:\:RedisCacheStore\(String, String\) redis=#<Redis\:\:Client\:0x.*expires_in=12:00:00.*namespace=nil>\z/
        )
      end

      it "#inspect with namescape" do
        store = Cache::RedisCacheStore(String, String).new(expires_in: 12.hours, namespace: "myapp-cache")

        store.inspect.should match(
          /\A#<Cache\:\:RedisCacheStore\(String, String\) redis=#<Redis\:\:Client\:0x.*expires_in=12:00:00.*namespace=\"myapp-cache\">\z/
        )
      end

      it "#redis" do
        store = Cache::RedisCacheStore(String, String).new(expires_in: 12.hours)
        store.redis.should be_a(Redis::Client)
      end

      it "#expires_in" do
        store = Cache::RedisCacheStore(String, String).new(expires_in: 12.hours)
        store.expires_in.should eq(12.hours)
      end

      it "#namespace" do
        store = Cache::RedisCacheStore(String, String).new(expires_in: 12.hours, namespace: "myapp-cache")
        store.namespace.should eq("myapp-cache")
      end
    end

    it "write to cache first time" do
      store = Cache::RedisCacheStore(String, String).new(12.hours)

      value = store.fetch("foo") { "bar" }
      value.should eq("bar")
    end

    it "fetch from cache" do
      store = Cache::RedisCacheStore(String, String).new(12.hours)

      value = store.fetch("foo") { "bar" }
      value.should eq("bar")

      value = store.fetch("foo") { "baz" }
      value.should eq("bar")
    end

    it "fetch from cache with custom Redis::Client" do
      redis_uri = URI.parse("redis://localhost:6379/1")
      redis = Redis::Client.new(uri: redis_uri)
      store = Cache::RedisCacheStore(String, String).new(expires_in: 12.hours, cache: redis)

      value = store.fetch("foo") { "bar" }
      value.should eq("bar")

      value = store.fetch("foo") { "baz" }
      value.should eq("bar")
    end

    it "don't fetch from cache if expired" do
      store = Cache::RedisCacheStore(String, String).new(1.seconds)

      value = store.fetch("foo") { "bar" }
      value.should eq("bar")

      sleep 2.seconds

      value = store.fetch("foo") { "baz" }
      value.should eq("baz")
    end

    it "fetch with expires_in from cache" do
      store = Cache::RedisCacheStore(String, String).new(1.seconds)

      value = store.fetch("foo", expires_in: 1.hours) { "bar" }
      value.should eq("bar")

      sleep 2.seconds

      value = store.fetch("foo") { "baz" }
      value.should eq("bar")
    end

    it "don't fetch with expires_in from cache if expires" do
      store = Cache::RedisCacheStore(String, String).new(12.hours)

      value = store.fetch("foo", expires_in: 1.seconds) { "bar" }
      value.should eq("bar")

      sleep 2.seconds

      value = store.fetch("foo") { "baz" }
      value.should eq("baz")
    end

    it "write" do
      store = Cache::RedisCacheStore(String, String).new(12.hours)
      store.write("foo", "bar", expires_in: 1.minute)

      value = store.fetch("foo") { "bar" }
      value.should eq("bar")
    end

    it "rewrite value" do
      store = Cache::RedisCacheStore(String, String).new(12.hours)
      store.write("foo", "bar", expires_in: 1.minute)
      store.write("foo", "baz", expires_in: 1.minute)

      value = store.read("foo")
      value.should eq("baz")
    end

    it "read" do
      store = Cache::RedisCacheStore(String, String).new(12.hours)
      store.write("foo", "bar")

      value = store.read("foo")
      value.should eq("bar")
    end

    it "set a custom expires_in value for entry on write" do
      store = Cache::RedisCacheStore(String, String).new(12.hours)
      store.write("foo", "bar", expires_in: 1.second)

      store.keys.should eq(Set{"foo"})

      sleep 2.seconds

      store.keys.should be_empty

      value = store.read("foo")
      value.should eq(nil)
    end

    it "delete from cache" do
      store = Cache::RedisCacheStore(String, String).new(12.hours)

      value = store.fetch("foo") { "bar" }
      value.should eq("bar")

      result = store.delete("foo")
      result.should eq(true)

      value = store.read("foo")
      value.should eq(nil)
      store.keys.should be_empty
    end

    it "deletes all items from the cache" do
      store = Cache::RedisCacheStore(String, String).new(12.hours)

      value = store.fetch("foo") { "bar" }
      value.should eq("bar")

      store.clear

      value = store.read("foo")
      value.should eq(nil)
      store.keys.should be_empty
    end

    it "#exists?" do
      store = Cache::RedisCacheStore(String, String).new(12.hours)

      store.write("foo", "bar")

      store.exists?("foo").should eq(true)
      store.exists?("foz").should eq(false)
    end

    it "#exists? expires" do
      store = Cache::RedisCacheStore(String, String).new(1.second)

      store.write("foo", "bar")

      sleep 2.seconds

      store.exists?("foo").should eq(false)
    end

    it "#increment" do
      store = Cache::RedisCacheStore(String, Int32).new(12.hours)

      store.write("num", 1)
      store.increment("num", 1)

      value = store.read("num")

      value.should eq("2")
    end

    it "#decrement" do
      store = Cache::RedisCacheStore(String, Int32).new(12.hours)

      store.write("num", 2)
      store.decrement("num", 1)

      value = store.read("num")

      value.should eq("1")
    end

    it "#increment non-existent value" do
      store = Cache::RedisCacheStore(String, Int32).new(12.hours)

      store.increment("undef_num", 1)

      value = store.read("undef_num")

      value.should eq("1")
    end

    it "clear" do
      store = Cache::RedisCacheStore(String, String).new(12.hours)

      store.write("foo", "bar", expires_in: 1.minute)

      store.clear

      value = store.read("foo")
      value.should be_nil
    end

    context "with namespace" do
      it "write" do
        store1 = Cache::RedisCacheStore(String, String).new(12.hours, namespace: "myapp-cache")
        store1.write("foo1", "bar", expires_in: 1.minute)

        store2 = Cache::RedisCacheStore(String, String).new(12.hours)
        store2.write("foo2", "baz", expires_in: 1.minute)

        store1.keys.should eq(Set{"myapp-cache:foo1"})
        store2.keys.should eq(Set{"myapp-cache:foo1", "foo2"})

        value = store1.fetch("foo") { "bar" }
        value.should eq("bar")
      end

      it "clear" do
        store = Cache::RedisCacheStore(String, String).new(12.hours, namespace: "myapp-cache")
        other_store = Cache::RedisCacheStore(String, String).new(12.hours, namespace: "other-cache")

        1001.times do |i|
          store.write("#{i + 1}", "bar", expires_in: 1.minute)
        end

        other_store.write("foo", "bar", expires_in: 1.minute)

        value = store.read("1001")
        value.should eq("bar")

        store.clear

        value = store.read("1001")
        value.should be_nil

        other_value = other_store.read("foo")
        other_value.should eq("bar")
      end
    end
  end
end
