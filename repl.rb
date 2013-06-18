require "readline"

loop do
    input = Readline.readline("input> ", true)
    exit if input =~ /^exit$/i

    q = query_syntax_process input

    begin
        exp = Reader.new(line).read
        p lisp.eval(exp)
    rescue Exception => error
        # ANSI escaped red
        puts "\e[31m"
        puts "on #{error.backtrace.pop}: #{error.message}"
        puts error.backtrace.map { |l| "\tfrom:#{l} " }
        # Clear ANSI escapes
        print "\e[0m"
    end
end

def qeval(query, ctx)
    
end

def assertion_to_be_added?(query)
    
end

def query_syntax_process(raw_input)
    
end

def instantiate(exp, frame, unbound_var_handler)

end
