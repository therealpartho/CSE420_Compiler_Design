#!/bin/bash

yacc -d -y --debug --verbose 22301572.y
echo 'Generated the parser C file as well the header file'
g++ -fpermissive -w -c -o y.o y.tab.c
echo 'Generated the parser object file'
flex 22301572.l
echo 'Generated the scanner C file'
g++ -fpermissive -w -c -o l.o lex.yy.c
echo 'Generated the scanner object file'
g++ -fpermissive -w -o a.exe y.o l.o
echo 'All ready, running'
./a.exe input2.c
