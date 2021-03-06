require "set"

class Logic
    def initialize
        @database = Hash.new { |h, k| h[k]=[] }
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
        @frames
    end

    def ask &block
        display compute(&block)
    end

    def compute &block
        @rule_application_id = 0
        bindings = query(&block)
        begin
            bindings.peek
        rescue StopIteration
            return []
        end
        @query_vars = Set.new
        @mode = :record_vars
        instance_eval(&block)

        resolve = ->(atom, frame){  
            if atom.is_a? Symbol
                frame.include?(atom) ? resolve.(frame[atom], frame) : atom
            else
                atom
            end
        }

        bindings.map { |frame|  
            Hash[@query_vars.map { |var| [var, resolve.(var, frame)] }]
        }
    end

    def display bindings
        puts '=>'
        puts 'No' if bindings == [] 

        bindings.each { |frame|
            puts 'Yes' if frame == {}
            frame.each_pair.with_index { |(var, val), j|
                val = val.is_a?(Symbol) ? '_unbound_' : val
                if j == frame.size-1
                    puts ":#{var} = #{val};"
                else
                    puts ":#{var} = #{val}"
                end
            }
        }
    end
    
    def predicate pred_name, *args, &block
        if @mode == :tell
            data = block_given? ? [pred_name, args, block] : [pred_name, args]
            @database[pred_name] << data # Could a set help?
        elsif @mode == :query
            @frames = [] if not @database.include? pred_name
            return if @frames == []
            @frames = @frames.lazy.flat_map do |frame|
                @database[pred_name].lazy.flat_map do |entry|
                    if not entry[-1].is_a? Proc
                        match_result = pattern_match args, entry[1], frame
                        match_result == 'failed' ? [] : [match_result]
                    else
                        clean_rule = rename_rule entry
                        unify_result = unify_match args, clean_rule[1], frame
                        unify_result == 'failed' ? [] : query([unify_result], &clean_rule[-1])
                    end
                end
            end
        elsif @mode == :rename_vars
            new_vars = args.map { |arg| arg.is_a?(Symbol) ? ":#{arg}#{@rule_application_id}" : arg }
            @rule_body << "#{pred_name} #{new_vars.join(', ')};"
        elsif @mode == :record_vars
            @query_vars.merge(args.select { |e| e.is_a? Symbol })
        end
    end

    def rename_rule rule
        @rule_application_id += 1
        vars = rule[1].map { |var| var.is_a?(Symbol) ? "#{var}#{@rule_application_id}".to_sym : var }
        @rule_body = ""
        @mode = :rename_vars
        instance_eval(&rule[-1])
        [rule[0], vars, eval("Proc.new { #{@rule_body} }")]
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
        if exp.is_a? Symbol
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
