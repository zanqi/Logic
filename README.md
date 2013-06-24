Logic
=====

Overview
---------
Logic provides a Prolog-style DSL for logic programming in Ruby.
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

database.ask { love 'minie', :who } 
```
Outputs:
```
=>
:who = 'mickey';
```

Get Started
-----------
```require "logic"``` in your project or irb (Logic needs Ruby 2.0+), then create a database by ```database = Logic.new```. You are now ready to input data and query them.

Input
--------
Entering data into the database is by providing a block to the ```tell``` method. Like Prolog, Logic supports two data types: fact and rule.  
**Fact**: Logic use a method call and its arguments to represent Fact in Prolog.
```ruby
database.tell { salary 'Ben', 1000 }
```
**Rule**: Rule in Prolog has a head and body. Logic uses a method call and a block following it to represent head and body respectively.
```ruby
database.tell do
    rich(:x) { salary :x, 1000 }
end
```
**Variable**: Logic use ```Symbol``` to represent variable in Prolog. The rule above states ":x is rich if the salary of :x is 1000". You can create compound rule that has multiple requirements.
```ruby
database.tell do
    super_rich(:x) do
        salary :x, 1000
        has_a_dog :x
    end
end
```
This states ":x is super_rich if the salary of :x is 1000 and :x has_a_dog"

Query
------
Querying the data entered so far is by providing a block to the ```ask``` method. 
```ruby
database.ask { rich 'Ben' }
```
Outputs:
```
=>
Yes
```
Again, ```Symbol``` is treated as variable.
```ruby
database.ask { salary 'Ben', :x }
```
Output:
```
=>
:x = 1000;
```

That's it!
----------
Feel free to play with it. If you have improvement idea, please let me know or send me a pull request.
