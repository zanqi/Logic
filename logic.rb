require "set"

class Logic
    def initialize
        @database = {}
    end
    
    def tell &block
        @mode = :tell
        instance_eval(&block)
        @database
    end
    
    def query frames = [{}], &block
        @mode = :query
        @frames = frames
        instance_eval(&block)
    end

    def ask &block
        display query(&block), &block        
    end

    def display result, &block
        puts "Yes" if result == [{}]
        puts "No" if result == []
        @query_vars = Set.new
        alias method_missing record_var
        instance_eval(&block)
        alias method_missing predicate

        resolve = ->(atom, frame){  
            if atom.is_a? Symbol
                frame.include?(atom) ? resolve.(frame[atom], frame) : atom
            else
                atom
            end
        }

        result.each_with_index { |frame, j|
            @query_vars.each_with_index { |var, i|
                if i == @query_vars.size-1
                    puts ":#{var} = #{resolve.(var, frame)};"
                else
                    puts ":#{var} = #{resolve.(var, frame)}"
                end
            }
            puts if j != result.size-1
        }
    end

    def record_var pred_name, *args
        @query_vars.merge(args.select { |e| e.is_a? Symbol })
    end
    
    def predicate pred_name, *args, &block
        if @mode == :tell
            data = block_given? ? [pred_name, args, block] : [pred_name, args]
            @database[pred_name] = @database[pred_name] ? @database[pred_name] << data : [data] # Could a set help?
        elsif @mode == :query
            @frames = [] if not @database.include? pred_name
            return if @frames == []
            @frames = @frames.flat_map do |frame|
                @database[pred_name].flat_map do |assertion|
                    if not assertion[-1].is_a? Proc
                        match_result = pattern_match args, assertion[1], frame
                        # p args, assertion[1], frame, match_result
                        match_result == 'failed' ? [] : [match_result]
                    else
                        # Need to rename var
                        unify_result = unify_match args, assertion[1], frame
                        unify_result == 'failed' ? [] : query([unify_result], &assertion[-1])
                    end
                end
            end
        end
    end

    def extend_if_consistent var, dat, frame
        if frame.include? var
            pattern_match frame[var], dat, frame
        else
            frame.merge var => dat
        end
    end
    
    def extend_if_possible var, val, frame
        if frame.has_key? var
            unify_match frame[var], val, frame
        elsif val.is_a? Symbol
            if frame.has_key? val
                unify_match var, frame[val], frame
            else
                frame.merge var => val
            end
        elsif depends_on? val, var, frame
            'failed'
        else
            frame.merge var => val
        end
    end
    
    def depends_on? exp, var, frame
        if exp.is_a Symbol
            if var == exp
                true
            else
                frame.has_key?(exp) ? depends_on?(frame[exp], var, frame) : false
            end
        elsif exp.is_a? Array
            exp.any? {|e| depends_on? e, var, frame }
        else
            false
        end
    end
    
    def pattern_match pat, dat, frame
        if frame == "failed"
            "failed"
        elsif pat == dat
            frame
        elsif pat.is_a? Symbol
            extend_if_consistent pat, dat, frame
        elsif pat.is_a?(Array) && dat.is_a?(Array)
            pat.zip(dat).reduce(frame) {|memo,(pattern,data)| pattern_match pattern, data, memo }
        else
            "failed"
        end
    end
    
    def unify_match p1, p2, frame
        if frame == 'failed'
            'failed'
        elsif p1 == p2
            frame
        elsif p1.is_a? Symbol
            extend_if_possible p1, p2, frame
        elsif p2.is_a? Symbol
            extend_if_possible p2, p1, frame
        elsif p1.is_a?(Array) && p2.is_a?(Array)
            p1.zip(p2).reduce(frame) {|memo,(p_1,p_2)| unify_match p_1, p_2, memo }
        else
            'failed'
        end
    end
    
    alias method_missing predicate
end

a = Logic.new
a.tell {
    mouse 'mickey'
    mouse 'minie'
    pretty 'minie'
    funny 'mickey'
    funny_mouse(:who) do
        mouse :who
        funny :who
    end
}

a.ask { mouse :x }