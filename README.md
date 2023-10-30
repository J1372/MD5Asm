# MD5Asm

Provides functionality for computing the MD5 hash of multiple files in parallel using POSIX threads.
File hashing functionality is written in x86-64 assembly.

## Building
A makefile is provided. Running make will produce an executable named 'md5hash'.
Requires NASM for assembling .asm files.
	

## Usage
./md5hash [opt_num_threads, default=1] file1 file2 ... fileN


