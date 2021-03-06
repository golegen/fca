#include "nes.h"
#include "struct.h"

//#define CPU_TEST

@@@ 
@@@ 内部RAMはREG_OP_TABLE相対でアクセスできる
@@@ 
#define NES_RAM (nes_internal_ram - cpu_exec_table)
#define NES_STACK (nes_stack - cpu_exec_table)

	SECTION_FAST

.macro	RETURN_FROM_CPU_EXEC
	ldmfd	sp!, {pc}
.endm


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@
@@@ CYCLE_NEXT
@@@ 
@@@ 残りサイクルをチェックして残っていれば次の命令を実行
@@@ ただし割り込みをチェックしない
@@@ 
@@@ なんか名前が変だな(どーでもいーけどー
@@@ 
.macro	CYCLE_NEXT	n
	subs	REG_CYCLE, REG_CYCLE, #\n
	@@ gtのほうが断然多いので優先する
	ldrgtb	r0, [REG_PC], #1
	ldrgt	pc, [REG_OP_TABLE, r0, lsl #2]
	RETURN_FROM_CPU_EXEC
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ CYCLE_NEXT_INT
@@@ 
@@@ 残りサイクルをチェックして残っていれば次の命令を実行
@@@ CLI・PHPなどフラグを変更した場合はこれ
@@@ 
.macro	CYCLE_NEXT_INT	n
	subs	REG_CYCLE, REG_CYCLE, #\n
	bgt	cpu_exec_check_int
	RETURN_FROM_CPU_EXEC
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ ゼロページから読む
@@@ 
.macro	ZP_READ
	add	REG_ADDR, REG_ADDR, #NES_RAM
	ldrb	r0, [REG_ADDR, REG_OP_TABLE]!
.endm

@@@ 
@@@ 読んだ後，書く場合はこれを使う(シフトなど)。でも，上と同じ
@@@ 
.macro	ZP_READ_W
	ZP_READ
.endm

@@@ 
@@@ アドレスを読む
@@@ 
.macro	ZP_READ_ADDR
	ZP_READ
	ldrb	REG_ADDR, [REG_ADDR, #1]
	orr	REG_ADDR, r0, REG_ADDR, lsl #8
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ ゼロページに書く
@@@ 
.macro	ZP_WRITE	reg=r0
	add	REG_ADDR, REG_ADDR, #NES_RAM
	strb	\reg, [REG_ADDR, REG_OP_TABLE]
.endm

@@@ 
@@@ ZP_READ_W で読んだ後，同じアドレスに書く
@@@ 
.macro	ZP_WRITE_W
	strb	r0, [REG_ADDR]
.endm


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ 16ビットアドレスの読み書き
@@@ 
@@@ REG_ADDR	=> 16ビットアドレス
@@@ r0		=> 書くバイト(write)
@@@ r0		<= 読んだバイト(read)・書いたバイト(write)
@@@ 

@@@ 
@@@ 3種類の命令がある
@@@ 
@@@ 一番多いのが
@@@ 16ビットアドレスから8ビットロードするだけの命令
@@@ 次に多いのが
@@@ ロード，計算，ストアをする命令
@@@ 残りは
@@@ ストアするだけの命令

@@@ 
@@@ 16ビットアドレスからロードのみ
@@@ 
@@@ RAMからのロードが一番多いので優先する
@@@ 
@@@ READ_1
@@@ OP
@@@ READ_2
@@@ OP
@@@ 
@@@ のように使う

.macro	READ_1
	movs	r1, REG_ADDR, lsr #13
	adr	lr, 9999f
	@@ 0でない時はジャンプする。
	@@ ちょっと工夫して1クロック減らす
	ldrne	pc, [lr, -r1, lsl #2]
	@@ RAMからロード
	bic	r0, REG_ADDR, #0x1800
	add	r0, r0, #NES_RAM
	ldrb	r0, [r0, REG_OP_TABLE]
.endm

.macro	READ_2
	.long	read_rom_byte
	.long	read_rom_byte
	.long	read_rom_byte
	.long	read_rom_byte
	.long	read_save_ram
	.long	read_high_reg
	.long	read_ppu_reg
9999:	
.endm

.macro	READ
	mov	r1, REG_ADDR, lsr #13
	adr	lr, 1f
	ldr	pc, [pc, r1, lsl #2]
	nop
	.long	2f		@ fast path
	.long	read_ppu_reg
	.long	read_high_reg
	.long	read_save_ram
	.long	read_rom_byte
	.long	read_rom_byte
	.long	read_rom_byte
	.long	read_rom_byte
2:
	bic	r0, REG_ADDR, #0x1800
	add	r0, r0, #NES_RAM
	ldrb	r0, [r0, REG_OP_TABLE]
	@@ というわけでジャンプする必要はない
1:	
.endm

@@@ 
@@@ 読んだあと書く場合
@@@ 
@@@ READ_WRITE_1
@@@ OP
@@@ READ_WRITE_2
@@@ 
@@@ READ_WRITE_3
@@@ OP
@@@ READ_WRITE_4
@@@ のように使う
@@@ OPではr3を保存しなければならない

.macro	READ_WRITE_1
	movs	r3, REG_ADDR, lsr #13
	adr	lr, 9999f
	@@ 0でない時はジャンプする。
	@@ ちょっと工夫して1クロック減らす
	ldrne	pc, [lr, -r3, lsl #2]
	@@ RAMからロード
	bic	REG_ADDR, REG_ADDR, #0x1800
	add	REG_ADDR, REG_ADDR, #NES_RAM
	ldrb	r0, [REG_ADDR, REG_OP_TABLE]!
.endm

.macro	READ_WRITE_2
	strb	r0, [REG_ADDR]
.endm

.macro	READ_WRITE_3
	.long	read_rom_byte
	.long	read_rom_byte
	.long	read_rom_byte
	.long	read_rom_byte
	.long	read_save_ram
	.long	read_high_reg
	.long	read_ppu_reg
9999:	
.endm

.macro	READ_WRITE_4
	adr	lr, 1f
	ldr	pc, [pc, r3, lsl #2]
	nop
	nop
	.long	write_ppu_reg
	.long	write_high_reg
	.long	write_save_ram
	.long	write_rom_byte
	.long	write_rom_byte
	.long	write_rom_byte
	.long	write_rom_byte
1:	
.endm

@@@ 
@@@ 書き込みだけの場合
@@@ 
@@@ WRITE_1
@@@ TAIL
@@@ WRITE_2
@@@ TAIL
@@@ とする

.macro	WRITE_1
	movs	r1, REG_ADDR, lsr #13
	adr	lr, 9999f
	ldrne	pc, [lr, -r1, lsl #2]
	bic	REG_ADDR, REG_ADDR, #0x1800
	add	REG_ADDR, REG_ADDR, #NES_RAM
	strb	r0, [REG_ADDR, REG_OP_TABLE]
.endm

.macro	WRITE_2
	.long	write_rom_byte
	.long	write_rom_byte
	.long	write_rom_byte
	.long	write_rom_byte
	.long	write_save_ram
	.long	write_high_reg
	.long	write_ppu_reg
9999:	
.endm

@@@ 
@@@ そして，これを必要とするのはジャンプ命令・割り込み・リセットのみである
@@@ あまり重要でないので適当でよい。
@@@ テンポラリに使えるレジスタが足りないので REG_PC を使うが気にするな
@@@ すぐ後で上書きされる。
@@@ REG_ADDRを変更するが気にするな
@@@ 
.macro	READ_WORD
	READ
	mov	REG_PC, r0
	add	REG_ADDR, REG_ADDR, #1
	READ
	orr	r0, REG_PC, r0, lsl #8
.endm


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ スタックのプッシュ・ポップ
@@@ 
@@@ 
.macro	PUSH_BYTE
	add	r1, REG_OP_TABLE, #NES_STACK
	strb	r0, [r1, REG_S, lsr #24]
	sub	REG_S, REG_S, #1 << 24
.endm

.macro	PUSH_WORD
	add	r1, REG_OP_TABLE, #NES_STACK
	mov	r2, r0, lsr #8
	strb	r2, [r1, REG_S, lsr #24]
	@@ いちおう REG_S のオーバーフローを気にしてみる
	sub	REG_S, REG_S, #1 << 24
	strb	r0, [r1, REG_S, lsr #24]
	sub	REG_S, REG_S, #1 << 24
.endm

.macro	POP_BYTE
	add	r0, REG_OP_TABLE, #NES_STACK
	add	REG_S, REG_S, #1 << 24
	ldrb	r0, [r0, REG_S, lsr #24]
.endm

.macro	POP_WORD
	add	r0, REG_OP_TABLE, #NES_STACK
	add	REG_S, REG_S, #1 << 24
	ldrb	r1, [r0, REG_S, lsr #24]
	add	REG_S, REG_S, #1 << 24
	ldrb	r0, [r0, REG_S, lsr #24]
	orr	r0, r1, r0, lsl #8
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ アドレッシングモード
@@@ 

.macro	IMPLIED
	@@ なにも必要ない
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ オペランドが1バイトの場合
@@@ 

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ #$nn
.macro	IMM_VALUE
	ldrb	r0, [REG_PC], #1
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ $nn
.macro	ZERO_ADDR
	ldrb	REG_ADDR, [REG_PC], #1
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ $nn, X
.macro	ZEROX_ADDR
	ZERO_ADDR
	add	REG_ADDR, REG_ADDR, REG_X
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ $nn, Y
.macro	ZEROY_ADDR
	ZERO_ADDR
	add	REG_ADDR, REG_ADDR, REG_Y
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ ($nn, X)
.macro	INDX_ADDR
	ZEROX_ADDR
	ZP_READ_ADDR
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ ($nn), Y
.macro	INDY_ADDR
	ZERO_ADDR
	ZP_READ_ADDR
	add	REG_ADDR, REG_ADDR, REG_Y
	bic	REG_ADDR, REG_ADDR, #0x10000
.endm


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ オペランドが2バイトの場合
@@@ 

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ $nnnn

.macro	ABS_ADDR
	tst	REG_PC, #1
	ldreqh	REG_ADDR, [REG_PC], #2
	ldrneb	REG_ADDR, [REG_PC], #1
	ldrneb	r0, [REG_PC], #1
	orrne	REG_ADDR, REG_ADDR, r0, lsl #8
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ $nnnn, X
.macro	ABSX_ADDR
	ABS_ADDR
	add	REG_ADDR, REG_ADDR, REG_X
	bic	REG_ADDR, REG_ADDR, #0x10000
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ $nnnn, Y
.macro	ABSY_ADDR
	ABS_ADDR
	add	REG_ADDR, REG_ADDR, REG_Y
	bic	REG_ADDR, REG_ADDR, #0x10000
.endm

@@@ P を復元する
@@@ r0		=> 6502 の P レジスタ
@@@ REG_NZ	<= 復元された REG_NZ
@@@ REG_P_REST	<= 復元された REG_P_REST
.macro	LOAD_P
	mov	REG_NZ, #0
	tst	r0, #P_Z_FLAG
	moveq	REG_NZ, #0x01
	tst	r0, #P_N_FLAG
	orrne	REG_NZ, REG_NZ, #0x80 << 24

	bic	REG_P_REST, REG_P_REST, #P_REST_FLAGS
	and	r0, r0, #P_REST_FLAGS
	orr	REG_P_REST, REG_P_REST, r0
.endm

@@@ P を保存する
@@@ 
@@@ REG_NZ	=> 元にする REG_NZ
@@@ REG_P_REST	=> 元にする REG_P_REST
@@@ r0		<= 6502 の P
.macro	SAVE_P
	and	r0, REG_P_REST, #P_REST_FLAGS
	tst	REG_NZ, #0x80 << 24
	orrne	r0, r0, #P_N_FLAG
	tst	REG_NZ, #0xFF
	orreq	r0, r0, #P_Z_FLAG
	orr	r0, r0, #P_R_FLAG
.endm

	SECTION_FAST
	ALIGN
@@@ 
@@@ Op-codes
@@@ 


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ NOP
@@@
@@@ なにもしない
opEA:	@ NOP
	IMPLIED
	CYCLE_NEXT	2

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ CLC/SEC/CLD/SED/CLI/SEI/CLV
@@@ 
@@@ フラグ操作命令
@@@ すべて1バイト
@@@
@@@ これで変更できるフラグは全てREG_P_RESTにある
@@@ Iを変更する場合は割り込みをチェックしなればならない
@@@ 
op18:	@ CLC
	IMPLIED
	bic	REG_P_REST, REG_P_REST, #P_REST_C_FLAG
	CYCLE_NEXT	2

op38:	@ SEC
	IMPLIED
	orr	REG_P_REST, REG_P_REST, #P_REST_C_FLAG
	CYCLE_NEXT	2

opD8:	@ CLD
	IMPLIED
	bic	REG_P_REST, REG_P_REST, #P_REST_D_FLAG
	CYCLE_NEXT	2

opF8:	@ SED
	IMPLIED
	orr	REG_P_REST, REG_P_REST, #P_REST_D_FLAG
	CYCLE_NEXT	2

op58:	@ CLI
	IMPLIED
	bic	REG_P_REST, REG_P_REST, #P_REST_I_FLAG
	CYCLE_NEXT_INT	2

op78:	@ SEI
	IMPLIED
	orr	REG_P_REST, REG_P_REST, #P_REST_I_FLAG
	CYCLE_NEXT	2

opB8:	@ CLV
	IMPLIED
	bic	REG_P_REST, REG_P_REST, #P_REST_V_FLAG
	CYCLE_NEXT	2

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ TAX/TXA/TAY/TYA/TSX/TXS
@@@ 
@@@ レジスタ間転送命令
@@@ すべて1バイト
@@@ 
@@@ TXS以外はNZを変更する
@@@ 
opAA:	@ TAX
	IMPLIED
	mov	REG_X, REG_A, lsr #24
	mov	REG_NZ, REG_A, asr #24
	CYCLE_NEXT	2

op8A:	@ TXA
	IMPLIED
	mov	REG_A, REG_X, lsl #24
	mov	REG_NZ, REG_A, asr #24
	CYCLE_NEXT	2

opA8:	@ TAY
	IMPLIED
	mov	REG_Y, REG_A, lsr #24
	mov	REG_NZ, REG_A, asr #24
	CYCLE_NEXT	2

op98:	@ TYA
	IMPLIED
	mov	REG_A, REG_Y, lsl #24
	mov	REG_NZ, REG_A, asr #24
	CYCLE_NEXT	2

opBA:	@ TSX
	IMPLIED
	mov	REG_X, REG_S, lsr #24
	orr	REG_NZ, REG_X, REG_X, lsl #24
	CYCLE_NEXT	2

op9A:	@ TXS
	IMPLIED
	bic	REG_S, REG_S, #0xFF << 24
	orr	REG_S, REG_S, REG_X, lsl #24
	CYCLE_NEXT	2


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ PHA/PHP/PLA/PLP
@@@
@@@ スタック操作命令
@@@ PLAはNZをPLPは全てのフラグを変更する
@@@ 
op48:	@ PHA
	IMPLIED
	mov	r0, REG_A, lsr #24
	PUSH_BYTE
	CYCLE_NEXT	3

op08:	@ PHP
	IMPLIED
	SAVE_P
	orr	r0, r0, #P_B_FLAG
	PUSH_BYTE
	CYCLE_NEXT	3

op68:	@ PLA
	IMPLIED
	POP_BYTE
	mov	REG_A, r0, lsl #24
	mov	REG_NZ, REG_A, asr #24
	CYCLE_NEXT	4

op28:	@ PLP
	IMPLIED
	POP_BYTE
	LOAD_P
	CYCLE_NEXT_INT	4

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ LDA/LDX/LDY
@@@ 
@@@ レジスタにロード
@@@
@@@ NZVC
@@@ ----
@@@ **--
.macro	OP_LDA
	mov	REG_A, r0, lsl #24
	mov	REG_NZ, REG_A, asr #24
.endm

.macro	OP_LDXY	reg
	mov	\reg, r0
	orr	REG_NZ, r0, r0, lsl #24
.endm

.macro	OP_LDX
	OP_LDXY	REG_X
.endm
.macro	OP_LDY
	OP_LDXY REG_Y
.endm

opA9:	@ LDA #$nn
	IMM_VALUE; OP_LDA
	CYCLE_NEXT	2

opA5:	@ LDA $nn
	ZERO_ADDR; ZP_READ; OP_LDA
	CYCLE_NEXT	3

opB5:	@ LDA $nn, X
	ZEROX_ADDR; ZP_READ; OP_LDA
	CYCLE_NEXT	4

opAD:	@ LDA $nnnn
	ABS_ADDR
	READ_1;	OP_LDA;	CYCLE_NEXT	4
	READ_2;	OP_LDA;	CYCLE_NEXT	4

opBD:	@ LDA $nnnn, X
	ABSX_ADDR
	READ_1;	OP_LDA;	CYCLE_NEXT	4
	READ_2;	OP_LDA;	CYCLE_NEXT	4

opB9:	@ LDA $nnnn, Y
	ABSY_ADDR
	READ_1;	OP_LDA;	CYCLE_NEXT	4
	READ_2;	OP_LDA;	CYCLE_NEXT	4

opA1:	@ LDA ($nn, X)
	INDX_ADDR
	READ_1;	OP_LDA;	CYCLE_NEXT	6
	READ_2;	OP_LDA;	CYCLE_NEXT	6

opB1:	@ LDA ($nn), Y
	INDY_ADDR
	READ_1;	OP_LDA;	CYCLE_NEXT	5
	READ_2;	OP_LDA;	CYCLE_NEXT	5


opA2:	@ LDX #$nn
	IMM_VALUE; OP_LDX
	CYCLE_NEXT	2

opA6:	@ LDX $nn
	ZERO_ADDR; ZP_READ; OP_LDX
	CYCLE_NEXT	3

opB6:	@ LDX $nn, Y
	ZEROY_ADDR; ZP_READ; OP_LDX
	CYCLE_NEXT	4

opAE:	@ LDX $nnnn
	ABS_ADDR
	READ_1;	OP_LDX;	CYCLE_NEXT	4
	READ_2;	OP_LDX;	CYCLE_NEXT	4

opBE:	@ LDX $nnnn, Y
	ABSY_ADDR
	READ_1;	OP_LDX;	CYCLE_NEXT	4
	READ_2;	OP_LDX;	CYCLE_NEXT	4



opA0:	@ LDY #$nn
	IMM_VALUE; OP_LDY
	CYCLE_NEXT	2

opA4:	@ LDY $nn
	ZERO_ADDR; ZP_READ; OP_LDY
	CYCLE_NEXT	3

opB4:	@ LDY $nn, X
	ZEROX_ADDR; ZP_READ; OP_LDY
	CYCLE_NEXT	4

opAC:	@ LDY $nnnn
	ABS_ADDR
	READ_1;	OP_LDY;	CYCLE_NEXT	4
	READ_2;	OP_LDY;	CYCLE_NEXT	4

opBC:	@ LDY $nnnn, X
	ABSX_ADDR
	READ_1;	OP_LDY;	CYCLE_NEXT	4
	READ_2;	OP_LDY;	CYCLE_NEXT	4

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ STA/STX/STY
@@@ 
@@@ レジスタのストア
@@@
@@@ NZVC
@@@ ----
@@@ ----
.macro	OP_STA
	mov	r0, REG_A, lsr #24
.endm

op85:	@ STA $nn
	ZERO_ADDR; OP_STA
	ZP_WRITE
	CYCLE_NEXT	3

op95:	@ STA $nn, X
	ZEROX_ADDR; OP_STA
	ZP_WRITE
	CYCLE_NEXT	4

op8D:	@ STA $nnnn
	ABS_ADDR; OP_STA
	WRITE_1; CYCLE_NEXT 4
	WRITE_2; CYCLE_NEXT 4

op9D:	@ STA $nnnn, X
	ABSX_ADDR; OP_STA
	WRITE_1; CYCLE_NEXT 5
	WRITE_2; CYCLE_NEXT 5

op99:	@ STA $nnnn, Y
	ABSY_ADDR; OP_STA
	WRITE_1; CYCLE_NEXT 5
	WRITE_2; CYCLE_NEXT 5

op81:	@ STA ($nn, X)
	INDX_ADDR; OP_STA
	WRITE_1; CYCLE_NEXT 6
	WRITE_2; CYCLE_NEXT 6

op91:	@ STA ($nn), Y
	INDY_ADDR; OP_STA
	WRITE_1; CYCLE_NEXT 6
	WRITE_2; CYCLE_NEXT 6


op86:	@ STX $nn
	ZERO_ADDR
	ZP_WRITE	REG_X
	CYCLE_NEXT	3

op96:	@ STX $nn, Y
	ZEROY_ADDR
	ZP_WRITE	REG_X
	CYCLE_NEXT	4

op8E:	@ STX $nnnn
	ABS_ADDR
	mov	r0, REG_X
	WRITE_1; CYCLE_NEXT 4
	WRITE_2; CYCLE_NEXT 4


op84:	@ STY $nn
	ZERO_ADDR
	ZP_WRITE	REG_Y
	CYCLE_NEXT	3

op94:	@ STY $nn, X
	ZEROX_ADDR
	ZP_WRITE	REG_Y
	CYCLE_NEXT	4

op8C:	@ STY $nnnn
	ABS_ADDR
	mov	r0, REG_Y
	WRITE_1; CYCLE_NEXT 4
	WRITE_2; CYCLE_NEXT 4


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ INC/INX/INY/DEC/DEX/DEY
@@@ インクリメント，デクリメント
@@@ すべてNZを変更する。Cは変更しない
@@@
@@@ NZVC
@@@ ----
@@@ **--
.macro	OP_INC
	add	r0, r0, #1
	and	r0, r0, #0xFF
	orr	REG_NZ, r0, r0, lsl #24
.endm

.macro	OP_INXY	reg
	add	\reg, \reg, #1
	and	\reg, \reg, #0xFF
	orr	REG_NZ, \reg, \reg, lsl #24
.endm

.macro	OP_DEC
	sub	r0, r0, #1
	and	r0, r0, #0xFF
	orr	REG_NZ, r0, r0, lsl #24
.endm

.macro	OP_DEXY	reg
	sub	\reg, \reg, #1	
	and	\reg, \reg, #0xFF
	orr	REG_NZ, \reg, \reg, lsl #24
.endm

opE6:	@ INC $nn
	ZERO_ADDR; ZP_READ_W; OP_INC
	ZP_WRITE_W
	CYCLE_NEXT	5

opF6:	@ INC $nn, X
	ZEROX_ADDR; ZP_READ_W; OP_INC
	ZP_WRITE_W
	CYCLE_NEXT	6

opEE:	@ INC $nnnn
	ABS_ADDR
	READ_WRITE_1; OP_INC; READ_WRITE_2; CYCLE_NEXT	6
	READ_WRITE_3; OP_INC; READ_WRITE_4; CYCLE_NEXT	6

opFE:	@ INC $nnnn, X
	ABSX_ADDR
	READ_WRITE_1; OP_INC; READ_WRITE_2; CYCLE_NEXT	7
	READ_WRITE_3; OP_INC; READ_WRITE_4; CYCLE_NEXT	7

opE8:	@ INX
	IMPLIED
	OP_INXY	REG_X
	CYCLE_NEXT	2

opC8:	@ INY
	IMPLIED
	OP_INXY	REG_Y
	CYCLE_NEXT	2

opC6:	@ DEC $nn
	ZERO_ADDR; ZP_READ_W; OP_DEC
	ZP_WRITE_W
	CYCLE_NEXT	5

opD6:	@ DEC $nn, X
	ZEROX_ADDR; ZP_READ_W; OP_DEC
	ZP_WRITE_W
	CYCLE_NEXT	6

opCE:	@ DEC $nnnn
	ABS_ADDR
	READ_WRITE_1; OP_DEC; READ_WRITE_2; CYCLE_NEXT	6
	READ_WRITE_3; OP_DEC; READ_WRITE_4; CYCLE_NEXT	6

opDE:	@ DEC $nnnn, X
	ABSX_ADDR
	READ_WRITE_1; OP_DEC; READ_WRITE_2; CYCLE_NEXT	7
	READ_WRITE_3; OP_DEC; READ_WRITE_4; CYCLE_NEXT	7

opCA:	@ DEX
	IMPLIED
	OP_DEXY	REG_X
	CYCLE_NEXT	2

op88:	@ DEY
	IMPLIED
	OP_DEXY	REG_Y
	CYCLE_NEXT	2


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ ADC/SBC
@@@ 
@@@ キャリー/ボローつきの加算/減算

.macro	OP_ADC
	@@ キャリーをセットして
	movs	r1, REG_P_REST, lsr #1
	@@ 上24ビットを全て1に
	subcs	r0, r0, #0x100
	@@ キャリーつきの加算
	adcs	REG_A, REG_A, r0, ror #8
	mov	REG_NZ, REG_A, asr #24
	adc	REG_P_REST, r1, r1
	orrvs	REG_P_REST, REG_P_REST, #P_REST_V_FLAG
	bicvc	REG_P_REST, REG_P_REST, #P_REST_V_FLAG
.endm

.macro	OP_SBC
	@@ キャリーをセットして
	movs	r1, REG_P_REST, lsr #1
	@@ キャリーつきの減算
	sbcs	REG_A, REG_A, r0, lsl #24
	and	REG_A, REG_A, #0xFF << 24
	mov	REG_NZ, REG_A, asr #24
	adc	REG_P_REST, r1, r1
	orrvs	REG_P_REST, REG_P_REST, #P_REST_V_FLAG
	bicvc	REG_P_REST, REG_P_REST, #P_REST_V_FLAG
.endm

op69:	@ ADC #$nn
	IMM_VALUE; OP_ADC
	CYCLE_NEXT	2

op65:	@ ADC $nn
	ZERO_ADDR; ZP_READ; OP_ADC
	CYCLE_NEXT	3

op75:	@ ADC $nn, X
	ZEROX_ADDR; ZP_READ; OP_ADC
	CYCLE_NEXT	4

op6D:	@ ADC $nnnn
	ABS_ADDR
	READ_1;	OP_ADC;	CYCLE_NEXT	4
	READ_2;	OP_ADC;	CYCLE_NEXT	4

op7D:	@ ADC $nnnn, X
	ABSX_ADDR
	READ_1;	OP_ADC;	CYCLE_NEXT	4
	READ_2;	OP_ADC;	CYCLE_NEXT	4

op79:	@ ADC $nnnn, Y
	ABSY_ADDR
	READ_1;	OP_ADC;	CYCLE_NEXT	4
	READ_2;	OP_ADC;	CYCLE_NEXT	4

op61:	@ ADC ($nn, X)
	INDX_ADDR
	READ_1;	OP_ADC;	CYCLE_NEXT	6
	READ_2;	OP_ADC;	CYCLE_NEXT	6

op71:	@ ADC ($nn), Y
	INDY_ADDR
	READ_1;	OP_ADC;	CYCLE_NEXT	5
	READ_2;	OP_ADC;	CYCLE_NEXT	5


opE9:	@ SBC #$nn
	IMM_VALUE; OP_SBC
	CYCLE_NEXT	2

opE5:	@ SBC $nn
	ZERO_ADDR; ZP_READ; OP_SBC
	CYCLE_NEXT	3

opF5:	@ SBC $nn, X
	ZEROX_ADDR; ZP_READ; OP_SBC
	CYCLE_NEXT	4

opED:	@ SBC $nnnn
	ABS_ADDR
	READ_1;	OP_SBC;	CYCLE_NEXT	4
	READ_2;	OP_SBC;	CYCLE_NEXT	4

opFD:	@ SBC $nnnn, X
	ABSX_ADDR
	READ_1;	OP_SBC;	CYCLE_NEXT	4
	READ_2;	OP_SBC;	CYCLE_NEXT	4

opF9:	@ SBC $nnnn, Y
	ABSY_ADDR
	READ_1;	OP_SBC;	CYCLE_NEXT	4
	READ_2;	OP_SBC;	CYCLE_NEXT	4

opE1:	@ SBC ($nn, X)
	INDX_ADDR
	READ_1;	OP_SBC;	CYCLE_NEXT	6
	READ_2;	OP_SBC;	CYCLE_NEXT	6

opF1:	@ SBC ($nn), Y
	INDY_ADDR
	READ_1;	OP_SBC;	CYCLE_NEXT	5
	READ_2;	OP_SBC;	CYCLE_NEXT	5


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ AND/EOR/ORA
@@@ 
@@@ ビット演算。すべてNZを変更する
@@@
@@@ NZVC
@@@ ----
@@@ **--
.macro	OP_AND
	and	REG_A, REG_A, r0, lsl #24
	mov	REG_NZ, REG_A, asr #24
.endm

.macro	OP_EOR
	eor	REG_A, REG_A, r0, lsl #24
	mov	REG_NZ, REG_A, asr #24
.endm

.macro	OP_ORA
	orr	REG_A, REG_A, r0, lsl #24
	mov	REG_NZ, REG_A, asr #24
.endm

op29:	@ AND #$nn
	IMM_VALUE; OP_AND
	CYCLE_NEXT	2

op25:	@ AND $nn
	ZERO_ADDR; ZP_READ; OP_AND
	CYCLE_NEXT	3

op35:	@ AND $nn, X
	ZEROX_ADDR; ZP_READ; OP_AND
	CYCLE_NEXT	4

op2D:	@ AND $nnnn
	ABS_ADDR
	READ_1;	OP_AND;	CYCLE_NEXT	4
	READ_2;	OP_AND;	CYCLE_NEXT	4

op3D:	@ AND $nnnn, X
	ABSX_ADDR
	READ_1;	OP_AND;	CYCLE_NEXT	4
	READ_2;	OP_AND;	CYCLE_NEXT	4

op39:	@ AND $nnnn, Y
	ABSY_ADDR
	READ_1;	OP_AND;	CYCLE_NEXT	4
	READ_2;	OP_AND;	CYCLE_NEXT	4

op21:	@ AND ($nn, X)
	INDX_ADDR
	READ_1;	OP_AND;	CYCLE_NEXT	6
	READ_2;	OP_AND;	CYCLE_NEXT	6

op31:	@ AND ($nn), Y
	INDY_ADDR
	READ_1;	OP_AND;	CYCLE_NEXT	5
	READ_2;	OP_AND;	CYCLE_NEXT	5


op49:	@ EOR #$nn
	IMM_VALUE; OP_EOR
	CYCLE_NEXT	2

op45:	@ EOR $nn
	ZERO_ADDR; ZP_READ; OP_EOR
	CYCLE_NEXT	3

op55:	@ EOR $nn, X
	ZEROX_ADDR; ZP_READ; OP_EOR
	CYCLE_NEXT	4

op4D:	@ EOR $nnnn
	ABS_ADDR
	READ_1;	OP_EOR;	CYCLE_NEXT	4
	READ_2;	OP_EOR;	CYCLE_NEXT	4

op5D:	@ EOR $nnnn, X
	ABSX_ADDR
	READ_1;	OP_EOR;	CYCLE_NEXT	4
	READ_2;	OP_EOR;	CYCLE_NEXT	4

op59:	@ EOR $nnnn, Y
	ABSY_ADDR
	READ_1;	OP_EOR;	CYCLE_NEXT	4
	READ_2;	OP_EOR;	CYCLE_NEXT	4

op41:	@ EOR ($nn, X)
	INDX_ADDR
	READ_1;	OP_EOR;	CYCLE_NEXT	6
	READ_2;	OP_EOR;	CYCLE_NEXT	6

op51:	@ EOR ($nn), Y
	INDY_ADDR
	READ_1;	OP_EOR;	CYCLE_NEXT	5
	READ_2;	OP_EOR;	CYCLE_NEXT	5


op09:	@ ORA #$nn
	IMM_VALUE; OP_ORA
	CYCLE_NEXT	2

op05:	@ ORA $nn
	ZERO_ADDR; ZP_READ; OP_ORA
	CYCLE_NEXT	3

op15:	@ ORA $nn, X
	ZEROX_ADDR; ZP_READ; OP_ORA
	CYCLE_NEXT	4

op0D:	@ ORA $nnnn
	ABS_ADDR
	READ_1;	OP_ORA;	CYCLE_NEXT	4
	READ_2;	OP_ORA;	CYCLE_NEXT	4

op1D:	@ ORA $nnnn, X
	ABSX_ADDR
	READ_1;	OP_ORA;	CYCLE_NEXT	4
	READ_2;	OP_ORA;	CYCLE_NEXT	4

op19:	@ ORA $nnnn, Y
	ABSY_ADDR
	READ_1;	OP_ORA;	CYCLE_NEXT	4
	READ_2;	OP_ORA;	CYCLE_NEXT	4

op01:	@ ORA ($nn, X)
	INDX_ADDR
	READ_1;	OP_ORA;	CYCLE_NEXT	6
	READ_2;	OP_ORA;	CYCLE_NEXT	6

op11:	@ ORA ($nn), Y
	INDY_ADDR
	READ_1;	OP_ORA;	CYCLE_NEXT	5
	READ_2;	OP_ORA;	CYCLE_NEXT	5



@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ CMP/CPX/CPY
@@@ 
@@@ 比較。すべてNZCを変更する
@@@
@@@ NZVC
@@@ ----
@@@ **-*
.macro	OP_CMP
	subs	REG_NZ, REG_A, r0, lsl #24
	mov	REG_NZ, REG_NZ, asr #24
	orrcs	REG_P_REST, REG_P_REST, #P_REST_C_FLAG
	biccc	REG_P_REST, REG_P_REST, #P_REST_C_FLAG
.endm

.macro	OP_CPXY	reg
	mov	r1, \reg, lsl #24
	subs	REG_NZ, r1, r0, lsl #24
	mov	REG_NZ, REG_NZ, asr #24
	orrcs	REG_P_REST, REG_P_REST, #P_REST_C_FLAG
	biccc	REG_P_REST, REG_P_REST, #P_REST_C_FLAG
.endm

.macro	OP_CPX
	OP_CPXY	REG_X
.endm

.macro	OP_CPY
	OP_CPXY	REG_Y
.endm

opC9:	@ CMP #$nn
	IMM_VALUE; OP_CMP
	CYCLE_NEXT	2

opC5:	@ CMP $nn
	ZERO_ADDR; ZP_READ; OP_CMP
	CYCLE_NEXT	3

opD5:	@ CMP $nn, X
	ZEROX_ADDR; ZP_READ; OP_CMP
	CYCLE_NEXT	4

opCD:	@ CMP $nnnn
	ABS_ADDR
	READ_1;	OP_CMP;	CYCLE_NEXT	4
	READ_2;	OP_CMP;	CYCLE_NEXT	4

opDD:	@ CMP $nnnn, X
	ABSX_ADDR
	READ_1;	OP_CMP;	CYCLE_NEXT	4
	READ_2;	OP_CMP;	CYCLE_NEXT	4

opD9:	@ CMP $nnnn, Y
	ABSY_ADDR
	READ_1;	OP_CMP;	CYCLE_NEXT	4
	READ_2;	OP_CMP;	CYCLE_NEXT	4

opC1:	@ CMP ($nn, X)
	INDX_ADDR
	READ_1;	OP_CMP;	CYCLE_NEXT	6
	READ_2;	OP_CMP;	CYCLE_NEXT	6

opD1:	@ CMP ($nn), Y
	INDY_ADDR
	READ_1;	OP_CMP;	CYCLE_NEXT	5
	READ_2;	OP_CMP;	CYCLE_NEXT	5


opE0:	@ CPX #$nn
	IMM_VALUE; OP_CPX
	CYCLE_NEXT	2

opE4:	@ CPX $nn
	ZERO_ADDR; ZP_READ; OP_CPX
	CYCLE_NEXT	3

opEC:	@ CPX $nnnn
	ABS_ADDR
	READ_1;	OP_CPX;	CYCLE_NEXT	4
	READ_2;	OP_CPX;	CYCLE_NEXT	4


opC0:	@ CPY #$nn
	IMM_VALUE; OP_CPY
	CYCLE_NEXT	2

opC4:	@ CPY $nn
	ZERO_ADDR; ZP_READ; OP_CPY
	CYCLE_NEXT	3

opCC:	@ CPY $nnnn
	ABS_ADDR
	READ_1;	OP_CPY;	CYCLE_NEXT	4
	READ_2;	OP_CPY;	CYCLE_NEXT	4


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ BIT
@@@
@@@ Z <= A ∧ M == 0
@@@ N <= M[7]
@@@ V <= M[6]
@@@ 
@@@ NZVC
@@@ ----
@@@ ***-
.macro	OP_BIT
	and	REG_NZ, r0, REG_A, lsr #24
	@@ R0[7] => C, R0[6] => N
	movs	r0, r0, lsl #25
	orrcs	REG_NZ, REG_NZ, #0x80 << 24
	orrmi	REG_P_REST, REG_P_REST, #P_REST_V_FLAG
	bicpl	REG_P_REST, REG_P_REST, #P_REST_V_FLAG
.endm

op24:	@ BIT $nn
	ZERO_ADDR; ZP_READ; OP_BIT
	CYCLE_NEXT	3

op2C:	@ BIT $nnnn
	ABS_ADDR
	READ_1;	OP_BIT;	CYCLE_NEXT	4
	READ_2;	OP_BIT;	CYCLE_NEXT	4


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ ASL/LSR
@@@ 
@@@ 右シフト・左シフト
@@@ 
@@@ NZCを変更する
@@@ 
.macro	OP_ASL
	movs	REG_NZ, r0, lsl #25
	mov	r0, REG_NZ, lsr #24
	mov	REG_NZ, REG_NZ, asr #24
	orrcs	REG_P_REST, REG_P_REST, #P_REST_C_FLAG
	biccc	REG_P_REST, REG_P_REST, #P_REST_C_FLAG
.endm

.macro	OP_ASL_A
	movs	REG_A, REG_A, lsl #1
	mov	REG_NZ, REG_A, asr #24
	orrcs	REG_P_REST, REG_P_REST, #P_REST_C_FLAG
	biccc	REG_P_REST, REG_P_REST, #P_REST_C_FLAG
.endm

.macro	OP_LSR
	movs	r0, r0, lsr #1
	@@ Nは立たない
	mov	REG_NZ, r0
	orrcs	REG_P_REST, REG_P_REST, #P_REST_C_FLAG
	biccc	REG_P_REST, REG_P_REST, #P_REST_C_FLAG
.endm

.macro	OP_LSR_A
	@@ Nは立たない
	movs	REG_NZ, REG_A, lsr #25
	mov	REG_A, REG_NZ, lsl #24
	orrcs	REG_P_REST, REG_P_REST, #P_REST_C_FLAG
	biccc	REG_P_REST, REG_P_REST, #P_REST_C_FLAG
.endm	

op0A:	@ ASL A
	IMPLIED
	OP_ASL_A
	CYCLE_NEXT	2

op06:	@ ASL $nn
	ZERO_ADDR; ZP_READ_W; OP_ASL
	ZP_WRITE_W
	CYCLE_NEXT	5

op16:	@ ASL $nn, X
	ZEROX_ADDR; ZP_READ_W; OP_ASL
	ZP_WRITE_W
	CYCLE_NEXT	6

op0E:	@ ASL $nnnn
	ABS_ADDR
	READ_WRITE_1; OP_ASL; READ_WRITE_2; CYCLE_NEXT	6
	READ_WRITE_3; OP_ASL; READ_WRITE_4; CYCLE_NEXT	6

op1E:	@ ASL $nnnn, X
	ABSX_ADDR
	READ_WRITE_1; OP_ASL; READ_WRITE_2; CYCLE_NEXT	7
	READ_WRITE_3; OP_ASL; READ_WRITE_4; CYCLE_NEXT	7


op4A:	@ LSR A
	IMPLIED
	OP_LSR_A
	CYCLE_NEXT	2

op46:	@ LSR $nn
	ZERO_ADDR; ZP_READ_W; OP_LSR
	ZP_WRITE_W
	CYCLE_NEXT	5

op56:	@ LSR $nn, X
	ZEROX_ADDR; ZP_READ_W; OP_LSR
	ZP_WRITE_W
	CYCLE_NEXT	6

op4E:	@ LSR $nnnn
	ABS_ADDR
	READ_WRITE_1; OP_LSR; READ_WRITE_2; CYCLE_NEXT	6
	READ_WRITE_3; OP_LSR; READ_WRITE_4; CYCLE_NEXT	6

op5E:	@ LSR $nnnn, X
	ABSX_ADDR
	READ_WRITE_1; OP_LSR; READ_WRITE_2; CYCLE_NEXT	7
	READ_WRITE_3; OP_LSR; READ_WRITE_4; CYCLE_NEXT	7


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ ROL/ROR
@@@
@@@ 左回転/右回転
@@@ 
@@@ NZCを変更する
@@@ 
.macro	OP_ROL
	@@ キャリーをセット
	movs	r1, REG_P_REST, lsr #1
	@@ シフト
	adc	r0, r0, r0
	@@ NZとキャリーをセット
	orrs	REG_NZ, r0, r0, lsl #24
	@@ キャリーを保存
	adc	REG_P_REST, r1, r1
.endm

.macro	OP_ROL_A
	@@ キャリーをセット
	movs	r1, REG_P_REST, lsr #1
	orrcs	REG_A, REG_A, #0x80 << 16
	movs	REG_A, REG_A, lsl #1
	mov	REG_NZ, REG_A, asr #24
	adc	REG_P_REST, r1, r1
.endm

.macro	OP_ROR
	movs	r1, REG_P_REST, lsr #1
	orrcs	r0, r0, #0x100
	movs	r0, r0, lsr #1
	orr	REG_NZ, r0, r0, lsl #24
	adc	REG_P_REST, r1, r1
.endm

.macro	OP_ROR_A
	movs	r1, REG_P_REST, lsr #1
	mov	REG_NZ, REG_A, rrx
	movs	REG_NZ, REG_NZ, asr #24
	mov	REG_A, REG_NZ, lsl #24
	adc	REG_P_REST, r1, r1
.endm

op2A:	@ ROL A
	IMPLIED
	OP_ROL_A
	CYCLE_NEXT	2

op26:	@ ROL $nn
	ZERO_ADDR; ZP_READ_W; OP_ROL
	ZP_WRITE_W
	CYCLE_NEXT	5

op36:	@ ROL $nn, X
	ZEROX_ADDR; ZP_READ_W; OP_ROL
	ZP_WRITE_W
	CYCLE_NEXT	6

op2E:	@ ROL $nnnn
	ABS_ADDR
	READ_WRITE_1; OP_ROL; READ_WRITE_2; CYCLE_NEXT	6
	READ_WRITE_3; OP_ROL; READ_WRITE_4; CYCLE_NEXT	6

op3E:	@ ROL $nnnn, X
	ABSX_ADDR
	READ_WRITE_1; OP_ROL; READ_WRITE_2; CYCLE_NEXT	7
	READ_WRITE_3; OP_ROL; READ_WRITE_4; CYCLE_NEXT	7


op6A:	@ ROR A
	IMPLIED
	OP_ROR_A
	CYCLE_NEXT	2

op66:	@ ROR $nn
	ZERO_ADDR; ZP_READ_W; OP_ROR
	ZP_WRITE_W
	CYCLE_NEXT	5

op76:	@ ROR $nn, X
	ZEROX_ADDR; ZP_READ_W; OP_ROR
	ZP_WRITE_W
	CYCLE_NEXT	6

op6E:	@ ROR $nnnn
	ABS_ADDR
	READ_WRITE_1; OP_ROR; READ_WRITE_2; CYCLE_NEXT	6
	READ_WRITE_3; OP_ROR; READ_WRITE_4; CYCLE_NEXT	6

op7E:	@ ROR $nnnn, X
	ABSX_ADDR
	READ_WRITE_1; OP_ROR; READ_WRITE_2; CYCLE_NEXT	7
	READ_WRITE_3; OP_ROR; READ_WRITE_4; CYCLE_NEXT	7


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ BCC/BCS/BNE/BEQ/BPL/BMI/BVC/BVS
@@@ 
@@@ 分岐
@@@ 

.macro	BRANCH_EQ
	ldreqsb	r0, [REG_PC], #1
	movne	r0, #1
	add	REG_PC, REG_PC, r0
	subeq	REG_CYCLE, REG_CYCLE, #1
.endm

.macro	BRANCH_NE
	ldrnesb	r0, [REG_PC], #1
	moveq	r0, #1
	add	REG_PC, REG_PC, r0
	subne	REG_CYCLE, REG_CYCLE, #1
.endm

op90:	@ BCC $nn
	tst	REG_P_REST, #P_REST_C_FLAG
	@@ Z が立てば
	BRANCH_EQ
	CYCLE_NEXT	2

opB0:	@ BCS $nn
	tst	REG_P_REST, #P_REST_C_FLAG
	@@ Z が下りてれば
	BRANCH_NE
	CYCLE_NEXT	2

opD0:	@ BNE $nn
	tst	REG_NZ, #0xFF
	BRANCH_NE
	CYCLE_NEXT	2

opF0:	@ BEQ $nn
	tst	REG_NZ, #0xFF
	BRANCH_EQ
	CYCLE_NEXT	2

op30:	@ BMI $nn
	tst	REG_NZ, #0x80 << 24
	@@ 結果が0でないなら
	BRANCH_NE
	CYCLE_NEXT	2

op10:	@ BPL $nn
	tst	REG_NZ, #0x80 << 24
	@@ 結果が0なら
	BRANCH_EQ
	CYCLE_NEXT	2

op50:	@ BVC $nn
	tst	REG_P_REST, #P_REST_V_FLAG
	@@ 結果が0なら
	BRANCH_EQ
	CYCLE_NEXT	2

op70:	@ BVS $nn
	tst	REG_P_REST, #P_REST_V_FLAG
	@@ 結果0でないなら
	BRANCH_NE
	CYCLE_NEXT	2

trace_jump:
	stmfd	sp!, {lr}
	ldr	r1, =0xFF45
	teq	r1, r0
	beq	2f
	mov	r1, #0x04000000
	ldr	r1, [r1, #0x130]
	tst	r1, #0x200
	bne	2f
	@beq	2f
	@cmp	r0, #0x2000
	@bcs	2f
	bleq	emu_break
	ldr	r1, pc_bank
	sub	r1, REG_PC, r1
	mov	r3, REG_PC
	mov	r2, r0
	adr	r0, 1f
	bl	emu_printf
2:	
	ldmfd	sp!, {r1}
	ldmfd	sp!, {r0, lr}
	mov	pc, r1
1:	.string "jump %x=>%x %x\n"
	ALIGN
	

@@@ pc が指しているバンクの先頭アドレス
	.globl	pc_bank
pc_bank:	.long	0

@@@ 
@@@ PCをロードする
@@@ 
@@@ r0	=> 新しいPC
@@@ 
.macro	LOAD_PC
#if 0
	stmfd	sp!, {r0, lr}
	bl	trace_jump
#endif
	adr	r1, memory_map
	movs	r2, r0, lsr #13
	ldr	r1, [r1, r2, lsl #2]
	and	r2, r0, #0x1800
	subeq	r1, r1, r2
	str	r1, pc_bank
	add	REG_PC, r0, r1
.endm


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ JMP_INDIRECT
@@@
@@@ NZVC
@@@ ----
@@@ ----
@ JMP ($nnnn)
op6C:	
	ABS_ADDR
	and	r0, REG_ADDR, #0xFF
	teq	r0, #0xFF
	beq	jmp_indirect_bug
	READ_WORD
#if 0
	mov	REG_ADDR, r0
	mov	r1, r0
	adr	r0, 1f
	bl	emu_printf
	mov	r0, REG_ADDR
#endif
	LOAD_PC
	CYCLE_NEXT	5

1:	.string	"jmp %x\n"
	ALIGN

jmp_indirect_bug:
	mov	r0, #0x6C
	b	emu_panic
	b	jmp_indirect_bug
#if 0
	bl	read_byte
	@@ low byte
	orr	REG_PC, r0, REG_PC, lsl #16
	bic	REG_ADDR, REG_ADDR, #0xFF
	bl	read_byte
	@@ high byte
	orr	REG_PC, REG_PC, r0, lsl #8
	mov	REG_PC, REG_PC, ror #16
	TRACE_JUMP_A
	b	cpu_exec_tail
#endif

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ JMP_ABSOLUTE
@@@
@@@ NZVC
@@@ ----
@@@ ----
@ JMP $nnnn
op4C:	
	ABS_ADDR
	mov	r0, REG_ADDR
	sub	r3, REG_PC, #3
	LOAD_PC
	teq	r3, REG_PC
	moveq	REG_CYCLE, #0	
	CYCLE_NEXT	3

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ JSR
@@@
@@@ NZVC
@@@ ----
@@@ ----
@ JSR $nnnn
op20:	
	ABS_ADDR
	ldr	r0, pc_bank
	sub	r0, REG_PC, r0
	sub	r0, r0, #1
	PUSH_WORD
	mov	r0, REG_ADDR
	LOAD_PC
	CYCLE_NEXT	6



@@@ 
@@@ アドレス空間を0x2000づつ8個のバンクに分ける
@@@ ここに登録するポインタはあらかじめオフセットを引いておくこと
@@@ こうすると連続する領域をマップするときは同じアドレスを与える
@@@ ことになる。
@@@ アドレスをマスクする必要がなくなるのは重要である。
	ALIGN
memory_map:	
	.long	nes_internal_ram
	.long	0, 0, save_ram - 0x6000
prg_rom_memory_map:
	.long	0, 0, 0, 0

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ BRK
@@@
@@@ NZVC BI
@@@ ---- --
@@@ ---- 11
op00:	@ BRK
	IMPLIED
	add	REG_PC, REG_PC, #1
	ldr	r0, pc_bank
	sub	r0, REG_PC, r0
	PUSH_WORD
	orr	REG_P_REST, REG_P_REST, #P_REST_B_FLAG
	SAVE_P
	PUSH_BYTE
	orr	REG_P_REST, REG_P_REST, #P_REST_I_FLAG
	mov	REG_ADDR, #0x10000
	sub	REG_ADDR, REG_ADDR, #IRQ_VECTOR
	READ_WORD
	LOAD_PC
	CYCLE_NEXT	7

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ RTI
@@@
@@@ NZVC
@@@ ----
@@@ ----
@ RTI
op40:	
	IMPLIED
	POP_BYTE
	LOAD_P
	POP_WORD
	LOAD_PC
	CYCLE_NEXT_INT	6

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ RTS
@@@
@@@ NZVC
@@@ ----
@@@ ----
@ RTS
op60:
	IMPLIED
	POP_WORD
	add	r0, r0, #1
	LOAD_PC
	CYCLE_NEXT	6

@@@ 
@@@ 割り込みの処理
@@@ 
do_int:	
	ldr	r0, pc_bank
	sub	r0, REG_PC, r0
	PUSH_WORD
	bic	REG_P_REST, REG_P_REST, #P_REST_B_FLAG
	SAVE_P
	PUSH_BYTE
	orr	REG_P_REST, REG_P_REST, #P_REST_I_FLAG
	tst	REG_P_REST, #P_REST_NMI_PENDING
	biceq	REG_P_REST, REG_P_REST, #P_REST_INT_PENDING
	bicne	REG_P_REST, REG_P_REST, #P_REST_NMI_PENDING
	mov	REG_ADDR, #0x10000
	subeq	REG_ADDR, REG_ADDR, #IRQ_VECTOR
	subne	REG_ADDR, REG_ADDR, #NMI_VECTOR
	READ_WORD
	LOAD_PC
	CYCLE_NEXT	7

@@@ 
@@@ リセットの処理
@@@ 
	.globl	reset_cpu

reset_cpu:	
	stmfd	sp!, {lr}
	mov	REG_NZ, #0
	@@ REG_P_RESET の上8ビットはSなのでマスクしないと
	@@ P_REST_HAS_VRAM もマスクしないと
	mov	r0, #0xFF << 24
	orr	r0, r0, #P_REST_HAS_VRAM
	and	REG_P_REST, REG_P_REST, r0
	orr	REG_P_REST, REG_P_REST, #P_REST_I_FLAG
	mov	REG_ADDR, #0x10000
	sub	REG_ADDR, REG_ADDR, #RESET_VECTOR
	READ_WORD
	LOAD_PC
	ldmfd	sp!, {pc}

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ メモリ操作
@@@ 

prg_rom_start:	.long	0

	ALIGN
	.globl	set_memory_map_8toE
set_memory_map_8toE:	
	ldr	r1, prg_rom_start
	add	r0, r1, r0, lsl #13
	sub	r0, r0, #0x8000
	str	r0, prg_rom_memory_map + 0x0
	str	r0, prg_rom_memory_map + 0x4
	str	r0, prg_rom_memory_map + 0x8
	str	r0, prg_rom_memory_map + 0xC
	mov	pc, lr

	.globl	set_memory_map_8
set_memory_map_8:
	ldr	r1, prg_rom_start
	add	r0, r1, r0, lsl #13
	sub	r0, r0, #0x8000
	str	r0, prg_rom_memory_map + 0x0
	mov	pc, lr

	.globl	set_memory_map_A
set_memory_map_A:
	ldr	r1, prg_rom_start
	add	r0, r1, r0, lsl #13
	sub	r0, r0, #0xA000
	str	r0, prg_rom_memory_map + 0x4
	mov	pc, lr

	.globl	set_memory_map_C
set_memory_map_C:
	ldr	r1, prg_rom_start
	add	r0, r1, r0, lsl #13
	sub	r0, r0, #0xC000
	str	r0, prg_rom_memory_map + 0x8
	mov	pc, lr

	.globl	set_memory_map_E
set_memory_map_E:
	ldr	r1, prg_rom_start
	add	r0, r1, r0, lsl #13
	sub	r0, r0, #0xE000
	str	r0, prg_rom_memory_map + 0xC
	mov	pc, lr

	.globl	set_memory_map_8toA
set_memory_map_8toA:
	ldr	r1, prg_rom_start
	add	r0, r1, r0, lsl #13
	sub	r0, r0, #0x8000
	str	r0, prg_rom_memory_map + 0x0
	str	r0, prg_rom_memory_map + 0x4
	mov	pc, lr

	.globl	set_memory_map_CtoE
set_memory_map_CtoE:
	ldr	r1, prg_rom_start
	add	r0, r1, r0, lsl #13
	sub	r0, r0, #0xC000
	str	r0, prg_rom_memory_map + 0x8
	str	r0, prg_rom_memory_map + 0xC
	mov	pc, lr

@@@ 
@@@ r1 には既にバンク番号がロードされている
@@@ 
read_rom_byte:	
	adrl	r0, memory_map
	ldr	r0, [r0, r1, lsl #2]
	ldrb	r0, [r0, REG_ADDR]
	mov	pc, lr

rom_write_handler:	.long	0

@@@ 
@@@ 
write_rom_byte:	
	and	r0, r0, #0xFF
	ldr	r1, rom_write_handler
	teq	r1, #0
	movne	pc, r1
	mov	pc, lr

@@@ 
@@@ 
@@@ 
	.globl	install_rom_write_handler

install_rom_write_handler:	
	str	r0, rom_write_handler
	mov	pc, lr

@@@ 
@@@ スプライトDMA
@@@ 
	.globl	write_4014
write_4014:	
	movs	r1, r0, lsr #5
	biceq	r0, r0, #0x18
	ldr	r2, =memory_map
	ldr	r2, [r2, r1, lsl #2]
	add	r0, r2, r0, lsl #8
	b	spr_dma

	.pool

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@	
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@	
@@@ 
@@@ デバッグ用逆アセンブラ
@@@ 
#if 0
emu_disass:
	stmfd	sp!, {r0, r1, r2, lr}
	mov	r3, REG_PC, lsr #16
	adr	lr, 1f
	ldr	pc, =do_disass
1:	ldmfd	sp!, {r0, r1, r2, pc}
	.pool

	ALIGN
#endif

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ 6502 をエミュレートする
@@@ 
@@@ REG_CYCLE	=> 実行するサイクル
@@@ REG_CYCLE	<= 残っているサイクル(零または負)
	.globl	cpu_exec

cpu_exec:
	cmp	REG_CYCLE, #0
	movle	pc, lr
	stmfd	sp!, {lr}

@@@ 
@@@	ここでDMCのチェックを行う
@@@	DMC割り込みが起きるとREG_P_RESTにフラグを立てるが
@@@	それはこのサイクルを実行後にINTフラグに送られる
@@@ 
	bl	sync_dmc

	adr	REG_OP_TABLE, cpu_exec_table

@@@ 
@@@	NMIのチェックはここで一度だけ行う
@@@ 
	tst	REG_P_REST, #P_REST_NMI_PENDING
	bne	do_int
@@@ 
@@@	 割り込みのチェックが必要な場合はここに戻ってくる
@@@ 
cpu_exec_check_int:
	tst	REG_P_REST, #P_REST_I_FLAG
	@@ I が立っている場合は割り込みを無視
	ldrneb	r0, [REG_PC], #1
	ldrne	pc, [REG_OP_TABLE, r0, lsl #2]
	@@ 割り込みのチェック
	tst	REG_P_REST, #P_REST_INT_PENDING
	ldreqb	r0, [REG_PC], #1
	ldreq	pc, [REG_OP_TABLE, r0, lsl #2]
	b	do_int

	ALIGN
@@@ 
@@@ みればわかるようにオペコードをインデックスにしたジャンプテーブル
@@@ 0x400バイト
@@@ 
cpu_exec_table:
	.long	op00, op01, op02, op03, op04, op05, op06, op07
	.long	op08, op09, op0A, op0B, op0C, op0D, op0E, op0F

	.long	op10, op11, op12, op13, op14, op15, op16, op17
	.long	op18, op19, op1A, op1B, op1C, op1D, op1E, op1F

	.long	op20, op21, op22, op23, op24, op25, op26, op27
	.long	op28, op29, op2A, op2B, op2C, op2D, op2E, op2F

	.long	op30, op31, op32, op33, op34, op35, op36, op37
	.long	op38, op39, op3A, op3B, op3C, op3D, op3E, op3F

	.long	op40, op41, op42, op43, op44, op45, op46, op47
	.long	op48, op49, op4A, op4B, op4C, op4D, op4E, op4F

	.long	op50, op51, op52, op53, op54, op55, op56, op57
	.long	op58, op59, op5A, op5B, op5C, op5D, op5E, op5F

	.long	op60, op61, op62, op63, op64, op65, op66, op67
	.long	op68, op69, op6A, op6B, op6C, op6D, op6E, op6F

	.long	op70, op71, op72, op73, op74, op75, op76, op77
	.long	op78, op79, op7A, op7B, op7C, op7D, op7E, op7F

	.long	op80, op81, op82, op83, op84, op85, op86, op87
	.long	op88, op89, op8A, op8B, op8C, op8D, op8E, op8F

	.long	op90, op91, op92, op93, op94, op95, op96, op97
	.long	op98, op99, op9A, op9B, op9C, op9D, op9E, op9F

	.long	opA0, opA1, opA2, opA3, opA4, opA5, opA6, opA7
	.long	opA8, opA9, opAA, opAB, opAC, opAD, opAE, opAF

	.long	opB0, opB1, opB2, opB3, opB4, opB5, opB6, opB7
	.long	opB8, opB9, opBA, opBB, opBC, opBD, opBE, opBF

	.long	opC0, opC1, opC2, opC3, opC4, opC5, opC6, opC7
	.long	opC8, opC9, opCA, opCB, opCC, opCD, opCE, opCF

	.long	opD0, opD1, opD2, opD3, opD4, opD5, opD6, opD7
	.long	opD8, opD9, opDA, opDB, opDC, opDD, opDE, opDF

	.long	opE0, opE1, opE2, opE3, opE4, opE5, opE6, opE7
	.long	opE8, opE9, opEA, opEB, opEC, opED, opEE, opEF

	.long	opF0, opF1, opF2, opF3, opF4, opF5, opF6, opF7
	.long	opF8, opF9, opFA, opFB, opFC, opFD, opFE, opFF

@@@ 
@@@ オペコードテーブルの直後にこれを置くREG_OP_TABLE相対で
@@@ 利用できる
@@@ 
nes_internal_ram:
	.fill	0x100, 1, 0
nes_stack:	
	.fill	0x700, 1, 0


	SECTION_SLOW
	ALIGN
	.globl	init_cpu

init_cpu:
	ldr	r0, = prg_rom_start
	ldopt	r1, EMU_OPT_prg_rom_start
	str	r1, [r0]
	mov	REG_A, #0
	mov	REG_X, #0
	mov	REG_Y, #0
	mov	REG_S, #0xFF << 24
	mov	REG_CYCLE, #0
	mov	pc, lr

	.pool

@@@ 
@@@ CPU テストコード
@@@ 
#ifdef CPU_TEST
#include "cpu-test.S"
#else
	.globl	run_cpu_test
run_cpu_test:	
	mov	pc, lr
#endif

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ Undefined Opcodes
@@@ 
op0B:	@ ANC #$nn
op2B:	@ ANC #$nn
op8B:	@ ANE #$nn
op6B:	@ ARR #$nn
op4B:	@ ASR #$nn
opC7:	@ DCP $nn
opD7:	@ DCP $nn, X
opCF:	@ DCP $nnnn
opDF:	@ DCP $nnnn, X
opDB:	@ DCP $nnnn, Y
opC3:	@ DCP ($nn, X)
opD3:	@ DCP ($nn), Y
op80:	@ NOP #$nn
op82:	
op89:	
opC2:	
opE2:	
op14:	@ NOP $nn, X
op34:	
op54:	
op74:	
opD4:	
opF4:	
op04:	@ NOP $nn
op44:	
op64:	
opE7:	@ ISB $nn
opF7:	@ ISB $nn, X
opEF:	@ ISB $nnnn
opFF:	@ ISB $nnnn, X
opFB:	@ ISB $nnnn, Y
opE3:	@ ISB ($nn, X)
opF3:	@ ISB ($nn), Y
op02:	@ JAM
op12:	
op22:	
op32:	
op42:	
op52:	
op62:	
op72:	
op92:	
opB2:	
opD2:	
opF2:	
opBB:	
opA7:	@ LAX $nn
opB7:	@ LAX $nn, Y
opAF:	@ LAX $nnnn
opBF:	@ LAX $nnnn, Y
opA3:	@ LAX ($nn, X)
opB3:	@ LAX ($nn), Y
opAB:	@ LXA #$nn
op1A:	@ NOP
op3A:	
op5A:	
op7A:	
opDA:	
opFA:	
op27:	@ RLA $nn
op37:	@ RLA $nn, X
op2F:	@ RLA $nnnn
op3F:	@ RLA $nnnn, X
op3B:	@ RLA $nnnn, Y
op23:	@ RLA ($nn, X)
op33:	@ RLA ($nn), Y
op67:	@ RRA $nn
op77:	@ RRA $nn, X
op6F:	@ RRA $nnnn
op7F:	@ RRA $nnnn, X
op7B:	@ RRA $nnnn, Y
op63:	@ RRA ($nn, X)
op73:	@ RRA ($nn), Y
op87:	@ SAX $nn
op97:	@ SAX $nn, Y
op8F:	@ SAX $nnnn
op83:	@ SAX ($nn, X)
opEB:	@ USBC #$nn
opCB:	
op9F:	@ SHA $nnnn, Y
op93:	@ SHA ($nn), Y
op9B:	@ SHS $nnnn, Y
op9E:	@ SHX $nnnn, Y
op9C:	@ SHY $nnnn, X
op07:	@ SLO $nn
op17:	@ SLO $nn, X
op0F:	@ SLO $nnnn
op1F:	@ SLO $nnnn, X
op1B:	@ SLO $nnnn, Y
op03:	@ SLO ($nn, X)
op13:	@ SLO ($nn), Y
op47:	@ SRE $nn
op57:	@ SRE $nn, X
op4F:	@ SRE $nnnn
op5F:	@ SRE $nnnn, X
op5B:	@ SRE $nnnn, Y
op43:	@ SRE ($nn, X)
op53:	@ SRE ($nn), Y
op0C:	@ NOP $nnnn
op1C:	@ NOP $nnnn, X
op3C:	
op5C:	
op7C:	
opDC:	
opFC:	
	.globl	emu_panic
emu_panic:
	mov	r4, #0x04000000
	mov	r5, #0
	strh	r5, [r4, #0xBA]
	strh	r5, [r4, #0x4]
	str	r5, [r4, #0x10]
	ldr	r2, = pc_bank
	ldr	r2, [r2]
	sub	r1, REG_PC, r2
	ldr	r2, = nes_stack
	add	r2, r2, REG_S, lsr #24
	mov	r3, REG_PC
	ldr	pc, =panic
1:	b	1b
	.pool

	.globl	emu_panic_from_int
emu_panic_from_int:	
	ldmfd	sp!, {r0-r3, r12, lr}
	str	lr, orig_pc
#if 0
	adr	lr, 1f
	subs	pc, lr, #0
1:	nop
	nop
#endif
	str	r0, orig_r0
	mov	r0, #0x03000000
	stmia	r0, {r0-r15}
	ldr	r1, orig_r0
	str	r1, [r0, #0x40]
	ldr	r1, orig_pc
	str	r1, [r0, #0x44]
	ldr	pc, = panic_from_int

orig_pc:	.long	0
orig_r0:	.long	0
	.pool
