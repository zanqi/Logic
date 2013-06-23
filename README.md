Logic
=====

Overview
---------
Logic provides a simple syntax DSL for logic programming.
```ruby
require 'logic'
database = Logic.new
database.tell {
    mouse 'mickey'
    mouse 'minie'
    funny 'mickey'
    funny_mouse(:who) do
        mouse :who
        funny :who
    end
    love('minie', :x) { funny_mouse :x }
}

database.ask { love 'minie', :who } # output: :who = 'mickey';
```
