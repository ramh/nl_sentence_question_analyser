########################################################
#### Question Word Annotator                        ####
#### CS7650, Fall 2010                              ####
#### Ram Kumar Hariharan (GTID: 902631808)          ####
#### Blair Daly (GTID: 902268308)                   ####
########################################################

ENV["JAVA_HOME"] = "/usr/lib/jvm/java-6-openjdk/"
ENV["CLASSPATH"] = "/home/ram/Data/gatech/NL/assignment1/stanford-parser-2010-08-20/stanford-parser-2010-08-20.jar"
require "rubygems"
require "stanfordparser"
require "tree"
require "ruby-debug"

# File for Storing Trained Model
TRAINED_MODEL_FILE = "trained_model.txt"

#Training Code
def get_tree_object(stanford_parser_tree)
  stanford_parser_tree_string = stanford_parser_tree.to_s
  root_node = Tree::TreeNode.new("MAINROOT", "NON-LEAF") # "-1")
  stanford_parser_tree_string.gsub!(/\n/, '')
  process_node(stanford_parser_tree_string, root_node)
  puts root_node.printTree
  root_node.children[0]
end

$random_number = 0
def process_node(stanford_parser_tree_string, root_node)
  stanford_parser_tree_string.strip!
  if stanford_parser_tree_string =~ /^\([^\)]+\(/
    node_name = stanford_parser_tree_string.match(/^\(([A-Z]+)/)
    $random_number+=1
    random = ($random_number % 10).to_s
    child = Tree::TreeNode.new(random + node_name[1], "NON-LEAF")   #(root_node.content.to_i + 1).to_s)
    root_node << child
    sub_string = stanford_parser_tree_string.match(/^\([^\)\(]+(\(.*\))\)$/)
    process_node(sub_string[1], child)
  elsif stanford_parser_tree_string =~ /^\([^\)]+\)/
    sub_strings = []
    bracket_counter = 0
    start_index = 0
    current_index = 0
    stanford_parser_tree_string.each_char do |c|
      bracket_counter+=1 if c == '('
      bracket_counter-=1 if c == ')'
      if bracket_counter == 0
        sub_string = stanford_parser_tree_string[start_index..current_index]
        sub_strings << sub_string if sub_string.strip.length > 0
        start_index = current_index + 1
      end
      current_index+=1
    end
    if sub_strings.length == 1
      node_name = sub_strings[0].match(/^\(([\.A-Z]+)/)
      node_content = sub_strings[0].match(/\]\s*([\?'A-Za-z]+)/)
      $random_number+=1
      random = ($random_number % 10).to_s
      child = Tree::TreeNode.new(random + node_name[1], node_content[1])
      root_node << child
    else
      for sub_string in sub_strings
        process_node(sub_string, root_node)
      end    
    end
  end
end

def train(sentence)
  # Step 1: Parse the Sentence using StanfordParser 
  parser = StanfordParser::LexicalizedParser.new
  stanford_parser_tree = parser.apply(sentence)
  puts stanford_parser_tree
  parser_tree = get_tree_object(stanford_parser_tree)

  # Step 2: get paths for all words
  words = sentence.split(/\s+/)
  path_hash = {}
  array = []
  get_path_hash(parser_tree, path_hash, array)
  p path_hash

  # Step 3: Open the existing trained data from file
  begin
    trained_data_hash = File.open(TRAINED_MODEL_FILE, "rb") {|f| Marshal.load(f)}
  rescue Exception => e:
    trained_data_hash = {}
  end
  puts "Current Trained Data:" + trained_data_hash.to_s
  puts "Identify the following word as (who, where, what, why, when, none):"
  path_hash.each do |word, postag_path|
    puts word + " (" + postag_path + ") : "
    question_word = STDIN.gets.chomp
    if ["who", "where", "what", "why", "when"].include? question_word
      debugger if trained_data_hash[postag_path] && trained_data_hash[postag_path] != question_word
      trained_data_hash[postag_path] = question_word
    end
  end
  puts "Updated Trained Data:"
  p trained_data_hash
  
  # Step 4: Update the trained data file
  File.open(TRAINED_MODEL_FILE, "wb") {|f| Marshal.dump(trained_data_hash, f)}
end

# Parsing Code
def get_word_from_line(line)
  line.gsub!(/\)/, '')
  line.split(' ')[-1]
end

def get_path_hash(parser_tree, path_hash, array)
  name = parser_tree.name[1..-1] # remember we added random one letter string to avoid TreeNode uniqueness problem
  if parser_tree.content == "NON-LEAF"
    array << name
    for child in parser_tree.children
      get_path_hash(child, path_hash, array.dup)
    end
  else
    array << name
    path_hash[parser_tree.content] = array.join("-")
  end
end

def parse(sentence)
  # Step 1: Parse the Sentence using StanfordParser 
  parser = StanfordParser::LexicalizedParser.new
  stanford_parser_tree = parser.apply(sentence)
  puts stanford_parser_tree
  parser_tree = get_tree_object(stanford_parser_tree)

  # Step 2: get paths for all words
  words = sentence.split(/\s+/)
  path_hash = {}
  array = []
  get_path_hash(parser_tree, path_hash, array)
  
  # Step 3: Look at training data
  sentence_words = {'who'   => [],
                    'what'  => [],
                    'where' => [],
                    'why'   => [],
                    'when'  => []}
  trained_data_hash = File.open(TRAINED_MODEL_FILE, "rb") {|f| Marshal.load(f)}
  path_hash.each do |word, postag_path|
    question_word = trained_data_hash[postag_path]
    sentence_words[question_word] << word if question_word
  end

  # Step 4: Printing output 
  puts "The output is:"
  for key in sentence_words.keys
    puts key.to_s + ":"
    for value in sentence_words[key]
      puts "\t" + value
    end
  end
end

# Check input sentence
if ARGV.length != 2 && (ARGV[0] == "train" || ARGV[0] == "parse")
  puts 'Usage: ruby parse_sentence.rb train "This is a sentence"'
  puts 'OR'
  puts 'Usage: ruby parse_sentence.rb parse "This is a sentence"'
  exit
end

# Call Train or Parse based on the command line arguments
if ARGV[0] == "train"
  train(ARGV[1])
else
  parse(ARGV[1])
end

