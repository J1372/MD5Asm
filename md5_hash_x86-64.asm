%use smartalign

DEFAULT REL
section .rodata
	align 4
	md5_s	dd 7,12,17,22,7,12,17,22,7,12,17,22,7,12,17,22,\
				5,9,14,20,5,9,14,20,5,9,14,20,5,9,14,20,\
				4,11,16,23,4,11,16,23,4,11,16,23,4,11,16,23,\
				6,10,15,21,6,10,15,21,6,10,15,21,6,10,15,21

	md5_k	dd 0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,\
				0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,\
				0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,\
				0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,\
				0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,\
				0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,\
				0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,\
				0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,\
				0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,\
				0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,\
				0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,\
				0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,\
				0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,\
				0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,\
				0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,\
				0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391

	hex_chars db '0123456789abcdef'

section .text
global	md5_hash_file
global	md5_get_hash_rep

alignmode	generic, nojmp

; rdi - ptr to block
; rsi - byte index to start zero pad
align	16
block_zero_pad:
	push	rbp
	mov	rbp, rsp

	lea	rcx, [rdi + rsi] ; rcx = ptr iterator
	lea	rdx, [rdi + 56] ; rdx = end ptr

	cmp	rdx, rcx
	jna	block_zero_pad_loop_break
	block_zero_pad_loop:
	mov	byte [rcx], 0

	; while it < end_it
	inc	rcx
	cmp	rdx, rcx
	ja	block_zero_pad_loop

	block_zero_pad_loop_break:
	leave
	ret

	

; r12 - block ptr
; eax, ebx, edx, edi = ABCD
; esi = i, round number
; r8d = F
; r9d = g
; r13 is in use
; r10, r11 available
%macro MD5_HASH_BLOCK_INTERNAL_SHIFT 0
	; F += A + K[i] + block[g]
	lea	r10, [md5_k]
	add	r8d, eax	; += A
	add	r8d, [r10 + rsi * 4]	; += K[i]
	add	r8d, [r12 + r9 * 4]	; += block[g]

	; F has been set

	; shift digest variables
	mov	eax, edi	; a = d
	mov	edi, edx	; d = c
	mov	edx, ebx	; c = b

	; B = B + (F << S[i]) | (F >> (32 - S[i]))
	; could reuse the g register, it is no longer needed
	lea	r10, [md5_s]
	mov	r9d, [r10 + rsi * 4]	; redefine r9d = S[i]
	mov	cl, 32
	sub	cl, r9b	; cl = 32 - S[i]
	mov	r10d, r8d	; r10d = F
	shr	r10d, cl	; r10d = F >> (32 - S[i])

	mov	cl, r9b
	mov	r11d, r8d
	shl	r11d, cl	; r11d = F << S[i]

	or	r10d, r11d	; r10d = (F << S[i]) | (F >> (32 - S[i]))
	add	ebx, r10d	; B += (F << S[i]) | (F >> (32 - S[i]))

%endmacro


; rdi - block ptr
; rsi - ptr prev hash iteration. new hash will be stored here ( at least 16 bytes )
align	16
md5_hash_block:
	; rax, rcx, rdx, rdi, rsi, r8, r9, r10, r11
	; store mutable in rax, rbx, rdx, rdi
	; rsi = i
	; r8 = F
	; r9 = g
	; r10, r11, rcx left over
	; rcx needed for shifts

	; need two more registers for saving args, and an additional temp register
	push	rbx
	push	r12
	push	r13

	; save block ptr in r12, hash ptr in r13
	mov	r13, rsi
	mov	r12, rdi

	; these 4 will mutate, ABCD
	mov	eax, [r13 + 0]
	mov	ebx, [r13 + 4]
	mov	edx, [r13 + 8]
	mov	edi, [r13 + 12]


	; round # = 0
	xor	esi, esi

	; r8d - F
	; r9d - g

	md5_inner_hash_loop1:
	; F = (B & C) | (~B & D)
	mov	r8d, ebx
	not	r8d
	and	r8d, edi

	mov	r9d, ebx
	and	r9d, edx
	or	r8d, r9d

	; g = i
	mov	r9d, esi

	MD5_HASH_BLOCK_INTERNAL_SHIFT

	inc	esi
	cmp	esi, 16
	jne	md5_inner_hash_loop1

	md5_inner_hash_loop2:
	; F = (D & B) | (~D & C)
	mov	r8d, edi
	not	r8d
	and	r8d, edx

	mov	r9d, edi
	and	r9d, ebx
	or	r8d, r9d

	; g = (5 * i + 1) % 16
	mov	r9d, esi
	imul	r9d, 5
	inc	r9d
	and	r9d, 0x0F

	MD5_HASH_BLOCK_INTERNAL_SHIFT

	inc	esi
	cmp	esi, 32
	jne	md5_inner_hash_loop2





	md5_inner_hash_loop3:
	; F = B ^ C ^ D
	mov	r8d, ebx
	xor	r8d, edx
	xor	r8d, edi
	; g = (3 * i + 5) % 16
	mov	r9d, esi
	imul	r9d, 3
	add	r9d, 5
	and	r9d, 0x0F

	MD5_HASH_BLOCK_INTERNAL_SHIFT

	inc	esi
	cmp	esi, 48
	jne	md5_inner_hash_loop3






	md5_inner_hash_loop4:
	; F = C ^ (B | ~D)
	mov	r8d, edi
	not	r8d
	or	r8d, ebx
	xor	r8d, edx

	; g = (7 * i) % 16
	mov	r9d, esi
	imul	r9d, 7
	and	r9d, 0x0F

	MD5_HASH_BLOCK_INTERNAL_SHIFT

	inc	esi
	cmp	esi, 64
	jne	md5_inner_hash_loop4




	; loop break

	; Add with previous ABCD
	add	eax, [r13 + 0]
	add	ebx, [r13 + 4]
	add	edx, [r13 + 8]
	add	edi, [r13 + 12]
	
	; Store new ABCD
	mov	[r13 + 0], eax
	mov	[r13 + 4], ebx
	mov	[r13 + 8], edx
	mov	[r13 + 12], edi

	pop	r13
	pop	r12
	pop	rbx
	ret



; rdi - file descriptor
; rsi - ptr md5 hash ( 16 bytes )
align	16
md5_hash_file:
	push	rbp
	mov	rbp, rsp

	push	rbx
	push	r12
	push	r13
	push	r14
	sub	rsp, 64	; allocate size for an md5 block

	; rbx file descriptor
	; r12 store ptr
	; r13 bytes read last read
	; r14 msg len in bytes -> bits

	mov	rbx, rdi
	mov	r12, rsi

	; write initial digest, A 0x67452301 B 0xefcdab89 C 0x98badcfe D 0x10325476
	; LE, so can do reg BA DC
	mov	rax, 0xefcdab8967452301
	mov	rdx, 0x1032547698badcfe
	mov	qword [r12 + 0], rax
	mov	qword [r12 + 8], rdx

	xor	r14, r14	; r14 = total msg len in bytes = 0

	align	16
	md5_hash_file_loop:
	; read block
	mov	rdi, rbx
	mov	rsi, rsp
	mov	rdx, 64
	mov	rax, 0
	syscall
	mov	r13, rax	; store bytes read
	add	r14, rax	; increment msg len

	cmp	r13, 64	; while last read was full block
	jne	md5_hash_file_loop_break

	; hash full block
	mov	rdi, rsp
	mov	rsi, r12
	call	md5_hash_block

	jmp	md5_hash_file_loop
	
	md5_hash_file_loop_break:

	shl	r14, 3		; convert msg length bytes to bits

	mov	byte [rsp + r13], 0x80	; append bit at end of msg
	inc	r13	; increment bytes read for zero padding

	; Zero out rest of block.
	mov	rdi, rsp
	mov	rsi, r13
	call	block_zero_pad

	; can only store length if bytes_read + 1 (r13) <= 56
	cmp	r13, 56
	jbe	md5_hash_file_if_cannot_store_length_after
	; need to store length in a separate block.
	; first hash this one.
	mov	rdi, rsp
	mov	rsi, r12
	call	md5_hash_block

	; zero pad a new block
	mov	rdi, rsp
	mov	rsi, 0
	call	block_zero_pad

	md5_hash_file_if_cannot_store_length_after:
	
	; store msg length (bits) in last 8 bytes of block, little endian
	mov	[rsp + 56], r14	; auto little endian

	; hash current block
	mov	rdi, rsp
	mov	rsi, r12
	call	md5_hash_block

	add	rsp, 64 ; deallocate block
	pop	r14
	pop	r13
	pop	r12
	pop	rbx
	leave
	ret

; rdi - md5 hash ptr ( 16 bytes, LE )
; rsi - store ( at least 33 bytes )
align	16
md5_get_hash_rep:
	push	rbp
	mov	rbp, rsp

	lea	rdx, [rdi + 16]	; end ptr
	lea	r8, [hex_chars]	; load relative address
	md5_get_hash_rep_loop:
	movzx	eax, byte [rdi]
	mov	ecx, eax

	shr	eax, 4	; eax = upper 4 bits
	and	ecx, 0x0f	; ecx = lower 4 bits

	; load hex representations
	movzx	eax, byte [r8 + rax]
	movzx	ecx, byte [r8 + rcx]

	; store hex reps in string.
	mov [rsi + 0], al
	mov [rsi + 1], cl

	inc	rdi
	add	rsi, 2
	cmp	rdi, rdx
	jne	md5_get_hash_rep_loop

	; loop break

	; Null terminate string.
	mov	byte [rsi], 0
	leave
	ret
	