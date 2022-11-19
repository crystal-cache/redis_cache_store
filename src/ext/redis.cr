module Redis
  module Commands
    def del(keys : Enumerable(String))
      command = Array(String).new(initial_capacity: 1 + keys.size)
      command << "del"
      keys.each { |key| command << key }

      run command
    end
  end
end
