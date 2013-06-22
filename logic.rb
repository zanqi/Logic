class Logic
    def initialize
        @database = {}
    end
    
    def install &block
        @mode = :install
        instance_eval &block
        @database
    end
    
    def query frames = [{}], &block
        @mode = :query
        @rule_application_id = 0
        @frames = frames
        instance_eval &block
    end
    
    def predicate pred_name, *args, &block
        if @mode == :install
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
        elsif var? val
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
        elsif var? p1
            extend_if_possible p1, p2, frame
        elsif var? p2
            extend_if_possible p2, p1, frame
        elsif p1.is_a?(Array) && p2.is_a?(Array)
            p1.zip(p2).reduce(frame) {|memo,(p_1,p_2)| unify_match p_1, p_2, memo }
        else
            'failed'
        end
    end
    
    alias method_missing predicate
end