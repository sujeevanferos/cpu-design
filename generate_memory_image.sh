# This script takes in an assembly file and generates a file (named "instr_mem.mem") that contains 
# machine code which can be loaded into instr_mem array in Verilog
# Author: Kisaru Liyanage

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <assembly_file>"
    exit 1
fi

assembly_file=$1

# compile assembler if needed and assemble the assembly program into machine code
if [ -f "./Assembler.exe" ]; then
    ./Assembler.exe $assembly_file
elif [ -f "./Assembler" ]; then
    ./Assembler $assembly_file
else
    gcc Assembler.c -o Assembler && ./Assembler $assembly_file
fi

# remove old instr_mem.mem and create new one to store instruction memory content
rm -f instr_mem.mem
touch instr_mem.mem

# generate instruction memory content to be loaded into instr_mem array in Verilog
while read line
do
    byte3=$(echo $line | cut -c1-8)
    byte2=$(echo $line | cut -c9-16)
    byte1=$(echo $line | cut -c17-24)
    byte0=$(echo $line | cut -c25-32)
    echo $byte0" "$byte1" "$byte2" "$byte3 >> instr_mem.mem
    
done < $assembly_file".machine"

echo "Instruction memory content generated!"
