require "readline"

class Parser
    def initialize(expression)
        @tokens = expression.scan(/[()]|\??\w+\!?|".*?"|'.*?'/)
    end

    def peek
        @tokens.first
    end

    def next_token
        @tokens.shift
    end

    def parse
        return :"no more forms" if @tokens.empty?

        if (token = next_token) == '('
          read_list
        elsif token =~ /['"].*/
          token[1..-2]
        elsif token =~ /\d+/
          token.to_i
        else
          token.to_sym
        end
    end

    def read_list
        list = []
        list << parse until peek == ')'
        next_token
        list
    end
end


def query_syntax_process(exp)
    expand_question_mark = ->(str){ str[0] == "?" ? ['?', str[1..-1]] : str }
    map_over_symbols expand_question_mark, exp
end

def map_over_symbols(proc, exp)
    if exp.is_a?(Array)
        exp.map do |e|
            map_over_symbols proc, e
        end
    elsif exp.is_a?(Symbol)
        proc.(exp)
    else
        exp
    end
end

def instantiate(exp, frame, unbound_var_handler)
    copy = ->(exp1){  
        if var? exp1
            if frame.has_key? exp1
                copy frame[exp1]
            else
                unbound_var_handler exp1 frame
            end
        elsif exp1.is_a?(Array)
            exp1.map(&copy)
        else
            exp1
        end
    }
    copy.(exp)
end

def add_rule_or_assertion!(assertion)
    if assertion[0] == :rule
        add_rule!(assertion)
    else
        add_assertion!(assertion)
    end
end

def add_rule! rule
    @all_rules << rule
    if indexable? rule[1]
        @indexed_rules[index_key_of rule[1]] = @indexed_rules[index_key_of rule[1]] << rule
    end
end

def add_assertion! assertion
    @all_assertions << assertion
    if indexable? assertion
        @indexed_assertions[index_key_of assertion] = @indexed_assertions[index_key_of assertion] << assertion
    end
end

def indexable? pattern
    pattern[0].is_a?(Symbol) || var?(pattern[0])
end

def index_key_of pat
    var?(pat[0])? "?" : pat[0]
end

def var? item
    item.is_a?(Array) && item[0] == "?"
end

def assertion_to_be_added?(exp)
    exp[0] == :assert!
end

def assertion_body exp
    exp[1]
end

def qeval(query, frames)
    if @built_in.has_key? query[0]
        @built_in[query[0]].(query.drop(1), frames)
    else
        simple_query query, frames
    end
end

def simple_query query, frames
    frames.flat_map do |frame|
        apply_assertions(query, frame) + apply_rules(query, frame) 
    end
end

def apply_rules pattern, frame
    fetch_rules(pattern, frame).flat_map do |rule|
        apply_a_rule rule, pattern, frame
    end
end

def apply_a_rule rule, pattern, frame
    clean_rule = rename rule
    result = unify_match pattern, clean_rule[1], frame
    result == 'failed' ? [] : qeval(rule_body(rule), [result])
end

def rule_body rule
    rule.drop(2).empty? ? [:true] : rule.drop(2)
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
        unify_match p1.drop(1), p2.drop(1), unify_match(p1[0], p2[0], frame)
    else
        'failed'
    end
end

def extend_if_possible var, val, frame
    if frame.has_key? var
        unify_match frame[var], val, frame
    elsif var? val
        if frame.has_key? val
            unify_match var, frame[val], frame
        else
            frame[var] = val
            frame
        end
    elsif depends_on? val, var, frame
        'failed'
    else
        frame[var] = val
        frame
    end
end

def depends_on? exp, var, frame
    if var? exp
        if var == exp
            true
        else
            frame.has_key?(exp) ? depends_on?(frame[exp], var, frame) : false
        end
    elsif exp.is_a?(Array)
        depends_on?(exp[0], var, frame) || depends_on?(exp.drop(1), var, frame)
    else
        false
    end
end

def rename expression
    @rule_application_id += 1
    helper = ->(exp){
        if var? exp
            make_new_var exp, @rule_application_id
        elsif exp.is_a?(Array)
            exp.map { |e| helper.(e) }
        else
            exp
        end
    }
    helper.(expression)
end

def apply_assertions pattern, frame
    fetch_assertions(pattern, frame).flat_map do |datum|
        check_an_assertion datum, pattern, frame
    end
end

def fetch_assertions pattern, frame
    use_index?(pattern) ? @indexed_assertions[index_key_of pattern] : @all_assertions
end

def fetch_rules pattern, frame
    use_index?(pattern) ? @indexed_rules[index_key_of pattern] : @all_rules
end

def use_index? pat
    pat[0].is_a?(Symbol) || var?(pat[0])
end

def check_an_assertion assertion, query_pat, frame
    result = pattern_match query_pat, assertion, frame
    result == "failed" ? [] : [result]
end

def pattern_match pat, dat, frame
    if frame == "failed"
        "failed"
    elsif pat == dat
        frame
    elsif var? pat
        extend_if_consistent pat, dat, frame
    elsif pat.is_a?(Array) && dat.is_a?(Array)
        pattern_match pat.drop(1), dat.drop(1), pattern_match(pat[0], dat[0], frame)
    else
        "failed"
    end
end

def extend_if_consistent var, dat, frame
    if frame.has_key?(var)
        pattern_match frame[var], dat, frame
    else
        frame[var] = dat
        frame
    end
end

def make_new_var var, rule_application_id
    ['?', rule_application_id] + var.drop(1)
end

@rule_application_id = 0
@all_assertions, @all_rules = [], []
@indexed_assertions, @indexed_rules = Hash.new([]), Hash.new([])
@built_in = {
    :and => ->(operands, frames){ operands.empty? ? frames : @built_in[:and].(operands.drop(1), qeval(operands[0], frames)) },
    :or => ->(operands, frames){ operands.empty? ? [] : qeval(operands[0], frames) + @built_in[:or].(operands.drop(1), frames) },
    :not => ->(operands, frames){ frames.flat_map {|frame| qeval(operands[0], [frame]).empty? ? [frame] : []} },
    :true => ->(ignore, frames){ frames }
}

def repl
    loop do
        input = Readline.readline("input> ", true)
        if input == 'reload'
            load 'repl.rb'
            next
        end
        break if input =~ /^exit$/i

        begin
            exp = Parser.new(input).parse
            q = query_syntax_process exp
            # p q

            if assertion_to_be_added? q
                add_rule_or_assertion! assertion_body(q)
                puts "Assertion added to data base."

                # p @all_assertions, @all_rules, @indexed_assertions, @indexed_rules
            else
                p qeval(q, [{}])
            end

        rescue Exception => error
            # ANSI escaped red
            puts "\e[31m"
            puts "on #{error.backtrace.pop}: #{error.message}"
            puts error.backtrace.map { |l| "\tfrom:#{l} " }
            # Clear ANSI escapes
            print "\e[0m"
        end
    end
end

def print_result frames
    if frames == []
        puts "No"
    elsif frames = [{}]
        puts "Yes"
    else
        frames.each { |f| puts f }
    end
end

if __FILE__ == $0
    repl
end