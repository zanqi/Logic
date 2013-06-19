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
    if exp.kind_of?(Array)
        exp.map do |e|
            map_over_symbols proc, e
        end
    elsif exp.kind_of?(Symbol)
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
        elsif exp1.kind_of?(Array)
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
    if indexable? rule
        @indexed_rules[index_key_of rule] = @indexed_rules[index_key_of rule] << rule
    end
end

def add_assertion! assertion
    p assertion
    @all_assertions << assertion
    if indexable? assertion
        @indexed_assertions[index_key_of assertion] = @indexed_assertions[index_key_of assertion] << assertion
    end
end

def indexable? pattern
    pattern[0].kind_of?(Symbol) || var?(pattern)
end

def index_key_of pat
    var?(pat[0])? "?" : pat[0]
end

def var? item
    item.kind_of?(Array) && item[0] == "?"
end

def assertion_to_be_added?(exp)
    exp[0] == :assert!
end

def assertion_body exp
    exp[1]
end

def qeval(query, frames)
    if built_in.has_key? query[0]
        built_in[query[0]].(query.drop(1), frames)
    else
        simple_query query, frames
    end
end

def simple_query query, frames
    frames.flat_map do |frame|
        find_assertions(query, frame) + find_rules(query, frame) 
    end
end

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
            puts "done"
            repl
            return        
        end
        break if input =~ /^exit$/i

        begin
            exp = Parser.new(input).parse
            q = query_syntax_process exp
            # p q

            if assertion_to_be_added? q
                add_rule_or_assertion! assertion_body(q)
                puts
                puts "Assertion added to data base."

                p @all_assertions, @all_rules, @indexed_assertions, @indexed_rules
            else
                puts
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

if __FILE__ == $0
    repl
end