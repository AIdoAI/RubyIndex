def read_dwarf(dwarf_file)
new_lookup_table = {}
file_indexes = []
file_names = []
flag = false
lookup_table = {}
dwarf_file.each_line do |line|
    if flag == false
      if line.match(/file_names/)
        file_index = line.scan(/\d/).join('').to_s
        file_indexes.push(file_index)
      elsif line.match(/name:/)
        file_name = line.scan(/"[^"]*"/).to_s.gsub('"', '').gsub("\\", '')
        file_names.push(file_name)
      elsif line.match(/Discriminator/)
        flag = true
      end 
    end
    if flag == true
      if line.match(/\d+/)
        arr = line.gsub(/\s+/m, ' ').strip.split(" ")
        assembly_addr = arr[0]
        line_number = arr[1]
        file = file_names[arr[3].to_i-1].gsub("[", '').gsub("]", '')
        if lookup_table.has_key?(file)
          value = lookup_table[file]
          value[assembly_addr] = line_number
          lookup_table[file] = value
        else
          lookup_table[file] ={assembly_addr => line_number}
        end 
      end 
    end 
end

lookup_table.each do |key, value|
  new_value = {}
  value.each do |k, v|
    if value.select{|k_1, v_1| v_1 == v}.keys.length > 1
      new_value[value.select{|k_1, v_1| v_1 == v}.keys] = value[k]+". "+IO.readlines(key)[v.to_i-1] #value[k] is the line number
    else
      new_value[k] = value[k] +". "+ IO.readlines(key)[v.to_i-1]
    end
  end
  new_value = new_value
  new_lookup_table[key] = new_value
end

unused_source_code = {}
lookup_table.each do |file, code_line_number|
  line_num = 0
  source_code = File.open(file).read
  source_code.gsub!(/\r\n?/, "\n")
  source_code.each_line do |code|
     line_num = line_num + 1
#puts code_line_number.values
    if !code_line_number.values.include?(line_num.to_s)
      if unused_source_code.has_key?(file)  
        value = unused_source_code[file]
        value[line_num] = code
        unused_source_code[file] = value
      else
        unused_source_code[file] = {line_num => code}
      end
    end
  end
end
return [new_lookup_table, unused_source_code]
end

dwarf_dump= `llvm-dwarfdump --debug-line #{ARGV[0]}`
assembly = `objdump --disassemble #{ARGV[0]}`
lookup_table_master = read_dwarf(dwarf_dump)
lookup_table = lookup_table_master[0]
unused_table = lookup_table_master[1]
#puts "Lookup Table"
#puts lookup_table

#Create html header
result = "<!DOCTYPE html>
    <html>
            <h1>zai3<h1>
            <h2>Cross Indexing<h2>
            <h3>CSC 254 Assignment 4</h3>
            <style>
            table {
            border-collapse: collapse;
            width: 100%;
            }
            td {
            padding: 8px;
            border-bottom: 2px solid black;
            vertical-align: bottom;
            width: 50%;
            }
            th{
            border: 1px solid black;
            }
            tr:nth-child(odd) {background-color: #faeaea;}
</style>
            <div>"
#add first row of assembly table
assembly_table =  "  <table style=i\"float: left\">
    <tr>
    	<th>Assembly</th>
        <th>Source</th>
    </tr>"

f = false
linenum =0
previous_key= ""
assembly.each_line do |line|
  linenum = linenum + 1
  linenum_string = linenum.to_s
  linenum_string= linenum_string + ". "
  tmp = line.strip
  line =line.gsub("<", "&lt").gsub(">", "&gt")
  arr = line.gsub(/\s/m, ' ').strip.split(" ")
  addr = arr[0]
  if !addr.nil? == true && addr.match(/:/)
    addr = addr.gsub(/:/, '')
  lookup_table.each do |key, value|
    asmly_addr = value.keys
    asmly_addr.each do |item|
      current_source_line = value[item][0].to_i
      if item.kind_of?(Array)
        if item[0].match(/#{addr}/)
          if item[0].match(/&ltmain&gt/)
            assembly_table += "<tr><td><a id=\"target\"></a>"
          else
            assembly_table += "<tr><td>"
          end
          #puts "#{tmp}                               #{'c:'+value[item]}"
          if key.eql? previous_key
          else
           assembly_table += "<tr><td>~</td><td>#{key}</td></tr><tr><td>"
          end
          previous_key = key
          assembly_table = assembly_table +"#{linenum_string}#{tmp}</td><td>#{value[item]}</td></tr>"
          f = true
          more_lines = true
          while more_lines
            current_source_line= current_source_line +1
            if unused_table.key?(key)
              source_lines= unused_table[key]
              if source_lines.key?(current_source_line)
                 assembly_table += "<tr><td>~</td><td>#{source_lines[current_source_line]}</td></tr><tr><td>"
              else
                 more_lines = false
              end
            end
          end
        end
      else
        if item.match(/#{addr}/)
          if item.match(/&ltmain&gt/)
            assembly_table += "<tr><td><a id=\"target\"></a>"
          else
            assembly_table += "<tr><td>"
          end
          #puts "#{tmp}                               #{'c:'+value[item]}"
          if key.eql? previous_key
          else
            assembly_table += "<tr><td>~</td><td>#{key}</td></tr><tr><td>"
          end
          previous_key = key
          assembly_table = assembly_table +"#{linenum_string}#{tmp}</td><td>#{value[item]}</td></tr>"
          f = true
          more_lines = true
          while more_lines
            current_source_line = current_source_line + 1
            if unused_table.key?(key)
              source_lines= unused_table[key]
              if source_lines.key?(current_source_line)
                 assembly_table += "<tr><td>~</td><td>#{source_lines[current_source_line]}</td></tr><tr><td>"
              else
                 more_lines = false
              end
            end
          end #end of while loop
        end
      end #end of if/else
    end #end of item loop
  end #end of |key,value| loop
  end
 if f == false
#puts line
   if line.match(/&ltmain&gt/)
            assembly_table += "<tr><td><a id=\"target\"></a>"
   else
      assembly_table += "<tr><td>"
   end
   assembly_table = assembly_table  +linenum_string+ line + "</td></tr>"
 end
 f = false
end
result = result + assembly_table + "<a href=\"#target\">Link</a>
</div>
        </body>
    </html>"
#puts "HTML CODE GENERATED:"
#puts result

#Create directory and write html files
Dir.mkdir('HTML') unless Dir.exist?('HTML')
File.open('HTML/index.html','w') do |file|
  file.write(result)
end



