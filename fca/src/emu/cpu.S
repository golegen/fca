#include "nes.h"

@@@ 
@@@ ����RAM��REG_OP_TABLE���Фǥ��������Ǥ���
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
@@@ �Ĥꥵ�����������å����ƻĤäƤ���м���̿���¹�
@@@ �����������ߤ�����å����ʤ�
@@@ 
@@@ �ʤ�̾�����Ѥ���(�ɡ��Ǥ⤤�����ɡ�
@@@ 
.macro	CYCLE_NEXT	n
	subs	REG_CYCLE, REG_CYCLE, #\n
	@@ gt�Τۤ�������¿���Τ�ͥ�褹��
	ldrgtb	r0, [REG_PC], #1
	ldrgt	pc, [REG_OP_TABLE, r0, lsl #2]
	RETURN_FROM_CPU_EXEC
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ CYCLE_NEXT_INT
@@@ 
@@@ �Ĥꥵ�����������å����ƻĤäƤ���м���̿���¹�
@@@ CLI��PHP�ʤɥե饰���ѹ��������Ϥ���
@@@ 
.macro	CYCLE_NEXT_INT	n
	subs	REG_CYCLE, REG_CYCLE, #\n
	bgt	cpu_exec_check_int
	RETURN_FROM_CPU_EXEC
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ �����ڡ��������ɤ�
@@@ 
.macro	ZP_READ
	add	REG_ADDR, REG_ADDR, #NES_RAM
	ldrb	r0, [REG_ADDR, REG_OP_TABLE]!
.endm

@@@ 
@@@ �ɤ���塤�񤯾��Ϥ����Ȥ�(���եȤʤ�)���Ǥ⡤���Ʊ��
@@@ 
.macro	ZP_READ_W
	ZP_READ
.endm

@@@ 
@@@ ���ɥ쥹���ɤ�
@@@ 
.macro	ZP_READ_ADDR
	ZP_READ
	ldrb	REG_ADDR, [REG_ADDR, #1]
	orr	REG_ADDR, r0, REG_ADDR, lsl #8
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ �����ڡ����˽�
@@@ 
.macro	ZP_WRITE	reg=r0
	add	REG_ADDR, REG_ADDR, #NES_RAM
	strb	\reg, [REG_ADDR, REG_OP_TABLE]
.endm

@@@ 
@@@ ZP_READ_W ���ɤ���塤Ʊ�����ɥ쥹�˽�
@@@ 
.macro	ZP_WRITE_W
	strb	r0, [REG_ADDR]
.endm


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ 16�ӥåȥ��ɥ쥹���ɤ߽�
@@@ 
@@@ REG_ADDR	=> 16�ӥåȥ��ɥ쥹
@@@ r0		=> �񤯥Х���(write)
@@@ r0		<= �ɤ���Х���(read)���񤤤��Х���(write)
@@@ 
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
	@@ �Ȥ����櫓�ǥ����פ���ɬ�פϤʤ�
1:	
.endm

@@@ 
@@@ ľ���Ʊ�����ɥ쥹�˽񤯾��(r3�˥��ɥ쥹��Ĥ��Τǲ����ƤϤ����ʤ�)
@@@ 
.macro	READ_W
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
	bic	r3, REG_ADDR, #0x1800
	add	r3, r3, #NES_RAM
	ldrb	r0, [r3, REG_OP_TABLE]!
	@@ �Ȥ����櫓�ǥ����פ���ɬ�פϤʤ�
1:	
.endm

@@@ 
@@@ �̾�ν񤭹���(STA,STX�ʤ�)(REG_ADDR������Τ�����)
@@@ 
.macro	WRITE
	mov	r1, REG_ADDR, lsr #13
	adr	lr, 1f
	ldr	pc, [pc, r1, lsl #2]
	nop
	.long	2f		@ fast path
	.long	write_ppu_reg
	.long	write_high_reg
	.long	write_save_ram
	.long	write_rom_byte
	.long	write_rom_byte
	.long	write_rom_byte
	.long	write_rom_byte
2:
	bic	REG_ADDR, REG_ADDR, #0x1800
	add	REG_ADDR, REG_ADDR, #NES_RAM
	strb	r0, [REG_ADDR, REG_OP_TABLE]
	@@ �Ȥ����櫓�ǥ����פ���ɬ�פϤʤ�
1:	
.endm

@@@ 
@@@ READ_W ���ɤ����ν񤭹���(INC, LSR�ʤ�)
@@@ 
.macro	WRITE_W
	mov	r1, REG_ADDR, lsr #13
	adr	lr, 1f
	ldr	pc, [pc, r1, lsl #2]
	nop
	.long	2f		@ fast path
	.long	write_ppu_reg
	.long	write_high_reg
	.long	write_save_ram
	.long	write_rom_byte
	.long	write_rom_byte
	.long	write_rom_byte
	.long	write_rom_byte
2:
	strb	r0, [r3]
	@@ �Ȥ����櫓�ǥ����פ���ɬ�פϤʤ�
1:	
.endm

@@@ 
@@@ �����ơ������ɬ�פȤ���Τϥ�����̿�ᡦ�����ߡ��ꥻ�åȤΤߤǤ���
@@@ ���ޤ���פǤʤ��Τ�Ŭ���Ǥ褤��
@@@ �ƥ�ݥ��˻Ȥ���쥸������­��ʤ��Τ� REG_PC ��Ȥ������ˤ����
@@@ ������Ǿ�񤭤���롣
@@@ REG_ADDR���ѹ����뤬���ˤ����
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
@@@ �����å��Υץå��塦�ݥå�
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
	@@ �������� REG_S �Υ����С��ե����򵤤ˤ��Ƥߤ�
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
@@@ ���ɥ�å��󥰥⡼��
@@@ 

.macro	IMPLIED
	@@ �ʤˤ�ɬ�פʤ�
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ ���ڥ��ɤ�1�Х��Ȥξ��
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
.endm


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ ���ڥ��ɤ�2�Х��Ȥξ��
@@@ 

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ $nnnn

.macro	ABS_ADDR
	ldrb	REG_ADDR, [REG_PC], #1
	ldrb	r0, [REG_PC], #1
	orr	REG_ADDR, REG_ADDR, r0, lsl #8
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ $nnnn, X
.macro	ABSX_ADDR
	ABS_ADDR
	add	REG_ADDR, REG_ADDR, REG_X
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ $nnnn, Y
.macro	ABSY_ADDR
	ABS_ADDR
	add	REG_ADDR, REG_ADDR, REG_Y
.endm


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ �ե饰�Υ�����
@@@ ARM�Υե饰��쥸�����˥����ɤ���
.macro	MRS_P
	mrs	REG_P, CPSR
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ �ե饰�Υ��ȥ�
@@@ ARM�Υե饰�˥쥸�����򥹥ȥ�����
@@@ Mappy VM �ΥХ���ư���ʤ��ΤǻȤ�ʤ�
.macro	MSR_P
	bug	bug	bug
	msr	CPSR_f, REG_P
.endm


@@@ P ����������
@@@ r0		=> 6502 �� P �쥸����
@@@ REG_P	<= �������줿 REG_P
@@@ REG_P_REST	<= �������줿 REG_P_REST
.macro	LOAD_P
	mov	REG_P, #0

	tst	r0, #P_Z_FLAG
	orrne	REG_P, REG_P, #ARM_Z_FLAG
	tst	r0, #P_C_FLAG
	orrne	REG_P, REG_P, #ARM_C_FLAG
	tst	r0, #P_N_FLAG
	orrne	REG_P, REG_P, #ARM_N_FLAG

	bic	REG_P_REST, REG_P_REST, #P_REST_FLAGS
	and	r0, r0, #P_REST_FLAGS
	orr	REG_P_REST, REG_P_REST, r0
.endm

@@@ P ����¸����
@@@ 
@@@ REG_P	=> ���ˤ��� REG_P
@@@ REG_P_REST	=> ���ˤ��� REG_P_REST
@@@ r0		<= 6502 �� P
.macro	SAVE_P
	and	r0, REG_P_REST, #P_REST_FLAGS
	tst	REG_P, #ARM_C_FLAG
	orrne	r0, r0, #P_C_FLAG
	tst	REG_P, #ARM_N_FLAG
	orrne	r0, r0, #P_N_FLAG
	tst	REG_P, #ARM_Z_FLAG
	orrne	r0, r0, #P_Z_FLAG
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
@@@ �ʤˤ⤷�ʤ�
opEA:	@ NOP
	IMPLIED
	CYCLE_NEXT	2

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ CLC/SEC/CLD/SED/CLI/SEI/CLV
@@@ 
@@@ �ե饰���̿��
@@@ ���٤�1�Х���
@@@
@@@ CZN��REG_P�ˤ���
@@@ �Ĥ��REG_P_REST�ˤ���
@@@ I���ѹ�������ϳ����ߤ�����å����ʤ�Фʤ�ʤ�
@@@ 
op18:	@ CLC
	IMPLIED
	bic	REG_P, REG_P, #ARM_C_FLAG
	CYCLE_NEXT	2

op38:	@ SEC
	IMPLIED
	orr	REG_P, REG_P, #ARM_C_FLAG
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
@@@ �쥸������ž��̿��
@@@ ���٤�1�Х���
@@@ 
@@@ TXS�ʳ���NZ���ѹ�����
@@@ 
opAA:	@ TAX
	IMPLIED
	and	REG_P, REG_P, #ARM_C_FLAG
	cmp	REG_A, #0
	orreq	REG_P, REG_P, #ARM_Z_FLAG
	orrmi	REG_P, REG_P, #ARM_N_FLAG
	mov	REG_X, REG_A, lsr #24
	CYCLE_NEXT	2

op8A:	@ TXA
	IMPLIED
	and	REG_P, REG_P, #ARM_C_FLAG
	movs	REG_A, REG_X, lsl #24
	orreq	REG_P, REG_P, #ARM_Z_FLAG
	orrmi	REG_P, REG_P, #ARM_N_FLAG
	CYCLE_NEXT	2

opA8:	@ TAY
	IMPLIED
	and	REG_P, REG_P, #ARM_C_FLAG
	cmp	REG_A, #0
	orreq	REG_P, REG_P, #ARM_Z_FLAG
	orrmi	REG_P, REG_P, #ARM_N_FLAG
	mov	REG_Y, REG_A, lsr #24
	CYCLE_NEXT	2

op98:	@ TYA
	IMPLIED
	and	REG_P, REG_P, #ARM_C_FLAG
	movs	REG_A, REG_Y, lsl #24
	orreq	REG_P, REG_P, #ARM_Z_FLAG
	orrmi	REG_P, REG_P, #ARM_N_FLAG
	CYCLE_NEXT	2

opBA:	@ TSX
	IMPLIED
	and	REG_P, REG_P, #ARM_C_FLAG
	cmp	REG_S, #0
	orreq	REG_P, REG_P, #ARM_Z_FLAG
	orrmi	REG_P, REG_P, #ARM_N_FLAG
	mov	REG_X, REG_S, lsr #24
	CYCLE_NEXT	2

op9A:	@ TXS
	IMPLIED
	mov	REG_S, REG_X, lsl #24
	CYCLE_NEXT	2


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ PHA/PHP/PLA/PLP
@@@
@@@ �����å����̿��
@@@ PLA��NZ��PLP�����ƤΥե饰���ѹ�����
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
	and	REG_P, REG_P, #ARM_C_FLAG
	movs	REG_A, r0, lsl #24
	orreq	REG_P, REG_P, #ARM_Z_FLAG
	orrmi	REG_P, REG_P, #ARM_N_FLAG
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
@@@ �쥸�����˥�����
@@@
@@@ NZVC
@@@ ----
@@@ **--
.macro	OP_LDA
	and	REG_P, REG_P, #ARM_C_FLAG
	movs	REG_A, r0, lsl #24
	orreq	REG_P, REG_P, #ARM_Z_FLAG
	orrmi	REG_P, REG_P, #ARM_N_FLAG
.endm

.macro	OP_LDXY	reg
	and	REG_P, REG_P, #ARM_C_FLAG
	movs	\reg, r0
	orreq	REG_P, REG_P, #ARM_Z_FLAG
	tst	\reg, #0x80
	orrne	REG_P, REG_P, #ARM_N_FLAG
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
	ABS_ADDR; READ; OP_LDA
	CYCLE_NEXT	4

opBD:	@ LDA $nnnn, X
	ABSX_ADDR; READ; OP_LDA
	CYCLE_NEXT	4

opB9:	@ LDA $nnnn, Y
	ABSY_ADDR; READ; OP_LDA
	CYCLE_NEXT	4

opA1:	@ LDA ($nn, X)
	INDX_ADDR; READ; OP_LDA
	CYCLE_NEXT	6

opB1:	@ LDA ($nn), Y
	INDY_ADDR; READ; OP_LDA
	CYCLE_NEXT	5



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
	ABS_ADDR; READ; OP_LDX
	CYCLE_NEXT	4

opBE:	@ LDX $nnnn, Y
	ABSY_ADDR; READ; OP_LDX
	CYCLE_NEXT	4



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
	ABS_ADDR; READ; OP_LDY
	CYCLE_NEXT	4

opBC:	@ LDY $nnnn, X
	ABSX_ADDR; READ; OP_LDY
	CYCLE_NEXT	4

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ STA/STX/STY
@@@ 
@@@ �쥸�����Υ��ȥ�
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
	ZERO_ADDR; OP_STA
	ZP_WRITE
	CYCLE_NEXT	4

op8D:	@ STA $nnnn
	ABS_ADDR; OP_STA
	WRITE
	CYCLE_NEXT	4

op9D:	@ STA $nnnn, X
	ABSX_ADDR; OP_STA
	WRITE
	CYCLE_NEXT	5

op99:	@ STA $nnnn, Y
	ABSY_ADDR; OP_STA
	WRITE
	CYCLE_NEXT	5

op81:	@ STA ($nn, X)
	INDX_ADDR; OP_STA
	WRITE
	CYCLE_NEXT	6

op91:	@ STA ($nn), Y
	INDY_ADDR; OP_STA
	WRITE
	CYCLE_NEXT	6



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
	WRITE
	CYCLE_NEXT	4



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
	WRITE
	CYCLE_NEXT	4


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ INC/INX/INY/DEC/DEX/DEY
@@@ ���󥯥���ȡ��ǥ������
@@@ ���٤�NZ���ѹ����롣C���ѹ����ʤ�
@@@
@@@ NZVC
@@@ ----
@@@ **--
.macro	OP_INC
	and	REG_P, REG_P, #ARM_C_FLAG
	add	r0, r0, #1
	movs	r1, r0, lsl #24
	orreq	REG_P, REG_P, #ARM_Z_FLAG
	orrmi	REG_P, REG_P, #ARM_N_FLAG
.endm

.macro	OP_INXY	reg
	and	REG_P, REG_P, #ARM_C_FLAG
	add	\reg, \reg, #1
	movs	\reg, \reg, lsl #24
	orreq	REG_P, REG_P, #ARM_Z_FLAG
	orrmi	REG_P, REG_P, #ARM_N_FLAG
	mov	\reg, \reg, lsr #24
.endm

.macro	OP_DEC
	and	REG_P, REG_P, #ARM_C_FLAG
	subs	r0, r0, #1
	orreq	REG_P, REG_P, #ARM_Z_FLAG
	tst	r0, #0x80
	orrne	REG_P, REG_P, #ARM_N_FLAG
.endm

.macro	OP_DEXY	reg
	and	REG_P, REG_P, #ARM_C_FLAG
	subs	\reg, \reg, #1	
	orreq	REG_P, REG_P, #ARM_Z_FLAG
	tst	\reg, #0x80
	orrne	REG_P, REG_P, #ARM_N_FLAG
	and	\reg, \reg, #0xFF
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
	ABS_ADDR; READ_W; OP_INC
	WRITE_W
	CYCLE_NEXT	6

opFE:	@ INC $nnnn, X
	ABSX_ADDR; READ_W; OP_INC
	WRITE_W
	CYCLE_NEXT	7

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
	ABS_ADDR; READ_W; OP_DEC
	WRITE_W
	CYCLE_NEXT	6

opDE:	@ DEC $nnnn, X
	ABSX_ADDR; READ_W; OP_DEC
	WRITE_W
	CYCLE_NEXT	7

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
@@@ ����꡼/�ܥ����Ĥ��βû�/����

.macro	OP_ADC
	@@ restore carry
	@@ �ʤ� MappyVM �� MSR �˥Х�������ΤǤ�������
	tst	r0, REG_P, lsl #3
	@@ A �β�24�ӥåȤ�FFFFFF�ˤ���
	subcs	REG_A, REG_A, #1
	addcs	REG_A, REG_A, #1 << 24
	@@ ����꡼�Ĥ��βû�
	adcs	REG_A, REG_A, r0, lsl #24
	MRS_P
	orrvs	REG_P_REST, REG_P_REST, #P_REST_V_FLAG
	bicvc	REG_P_REST, REG_P_REST, #P_REST_V_FLAG
.endm

.macro	OP_SBC
	tst	r0, REG_P, lsl #3
	sbcs	REG_A, REG_A, r0, lsl #24
	MRS_P
	orrvs	REG_P_REST, REG_P_REST, #P_REST_V_FLAG
	bicvc	REG_P_REST, REG_P_REST, #P_REST_V_FLAG
	ands	REG_A, REG_A, #0xFF << 24
	orreq	REG_P, REG_P, #ARM_Z_FLAG
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
	ABS_ADDR; READ; OP_ADC
	CYCLE_NEXT	4

op7D:	@ ADC $nnnn, X
	ABSX_ADDR; READ; OP_ADC
	CYCLE_NEXT	4

op79:	@ ADC $nnnn, Y
	ABSY_ADDR; READ; OP_ADC
	CYCLE_NEXT	4

op61:	@ ADC ($nn, X)
	INDX_ADDR; READ; OP_ADC
	CYCLE_NEXT	6

op71:	@ ADC ($nn), Y
	INDY_ADDR; READ; OP_ADC
	CYCLE_NEXT	5


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
	ABS_ADDR; READ; OP_SBC
	CYCLE_NEXT	4

opFD:	@ SBC $nnnn, X
	ABSX_ADDR; READ; OP_SBC
	CYCLE_NEXT	4

opF9:	@ SBC $nnnn, Y
	ABSY_ADDR; READ; OP_SBC
	CYCLE_NEXT	4

opE1:	@ SBC ($nn, X)
	INDX_ADDR; READ; OP_SBC
	CYCLE_NEXT	6

opF1:	@ SBC ($nn), Y
	INDY_ADDR; READ; OP_SBC
	CYCLE_NEXT	5


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ AND/EOR/ORA
@@@ 
@@@ �ӥåȱ黻�����٤�NZ���ѹ�����
@@@
@@@ NZVC
@@@ ----
@@@ **--
.macro	OP_AND
	and	REG_P, REG_P, #ARM_C_FLAG
	ands	REG_A, REG_A, r0, lsl #24
	orreq	REG_P, REG_P, #ARM_Z_FLAG
	orrmi	REG_P, REG_P, #ARM_N_FLAG
.endm

.macro	OP_EOR
	and	REG_P, REG_P, #ARM_C_FLAG
	eors	REG_A, REG_A, r0, lsl #24
	orreq	REG_P, REG_P, #ARM_Z_FLAG
	orrmi	REG_P, REG_P, #ARM_N_FLAG
.endm

.macro	OP_ORA
	and	REG_P, REG_P, #ARM_C_FLAG
	orrs	REG_A, REG_A, r0, lsl #24
	orreq	REG_P, REG_P, #ARM_Z_FLAG
	orrmi	REG_P, REG_P, #ARM_N_FLAG
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
	ABS_ADDR; READ; OP_AND
	CYCLE_NEXT	4

op3D:	@ AND $nnnn, X
	ABSX_ADDR; READ; OP_AND
	CYCLE_NEXT	4

op39:	@ AND $nnnn, Y
	ABSY_ADDR; READ; OP_AND
	CYCLE_NEXT	4

op21:	@ AND ($nn, X)
	INDX_ADDR; READ; OP_AND
	CYCLE_NEXT	6

op31:	@ AND ($nn), Y
	INDY_ADDR; READ; OP_AND
	CYCLE_NEXT	5



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
	ABS_ADDR; READ; OP_EOR
	CYCLE_NEXT	4

op5D:	@ EOR $nnnn, X
	ABSX_ADDR; READ; OP_EOR
	CYCLE_NEXT	4

op59:	@ EOR $nnnn, Y
	ABSY_ADDR; READ; OP_EOR
	CYCLE_NEXT	4

op41:	@ EOR ($nn, X)
	INDX_ADDR; READ; OP_EOR
	CYCLE_NEXT	6

op51:	@ EOR ($nn), Y
	INDY_ADDR; READ; OP_EOR
	CYCLE_NEXT	5



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
	ABS_ADDR; READ; OP_ORA
	CYCLE_NEXT	4

op1D:	@ ORA $nnnn, X
	ABSX_ADDR; READ; OP_ORA
	CYCLE_NEXT	4

op19:	@ ORA $nnnn, Y
	ABSY_ADDR; READ; OP_ORA
	CYCLE_NEXT	4

op01:	@ ORA ($nn, X)
	INDX_ADDR; READ; OP_ORA
	CYCLE_NEXT	6

op11:	@ ORA ($nn), Y
	INDY_ADDR; READ; OP_ORA
	CYCLE_NEXT	5



@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ CMP/CPX/CPY
@@@ 
@@@ ��ӡ����٤�NZC���ѹ�����
@@@
@@@ NZVC
@@@ ----
@@@ **-*
.macro	OP_CMP
	cmp	REG_A, r0, lsl #24
	MRS_P
.endm

.macro	OP_CPXY	reg
	mov	r1, \reg, lsl #24
	cmp	r1, r0, lsl #24
	MRS_P
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
	ABS_ADDR; READ; OP_CMP
	CYCLE_NEXT	4

opDD:	@ CMP $nnnn, X
	ABSX_ADDR; READ; OP_CMP
	CYCLE_NEXT	4

opD9:	@ CMP $nnnn, Y
	ABSY_ADDR; READ; OP_CMP
	CYCLE_NEXT	4

opC1:	@ CMP ($nn, X)
	INDX_ADDR; READ; OP_CMP
	CYCLE_NEXT	6

opD1:	@ CMP ($nn), Y
	INDY_ADDR; READ; OP_CMP
	CYCLE_NEXT	5


opE0:	@ CPX #$nn
	IMM_VALUE; OP_CPX
	CYCLE_NEXT	2

opE4:	@ CPX $nn
	ZERO_ADDR; ZP_READ; OP_CPX
	CYCLE_NEXT	3

opEC:	@ CPX $nnnn
	ABS_ADDR; READ; OP_CPX
	CYCLE_NEXT	4



opC0:	@ CPY #$nn
	IMM_VALUE; OP_CPY
	CYCLE_NEXT	2

opC4:	@ CPY $nn
	ZERO_ADDR; ZP_READ; OP_CPY
	CYCLE_NEXT	3

opCC:	@ CPY $nnnn
	ABS_ADDR; READ; OP_CPY
	CYCLE_NEXT	4


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ BIT
@@@
@@@ Z <= A �� M == 0
@@@ N <= M[7]
@@@ V <= M[6]
@@@ 
@@@ NZVC
@@@ ----
@@@ ***-
.macro	OP_BIT
	and	REG_P, REG_P, #ARM_C_FLAG
	tst	REG_A, r0, lsl #24
	orreq	REG_P, REG_P, #ARM_Z_FLAG
	@@ R0[7] => C, R0[6] => N
	movs	r0, r0, lsl #25
	orrcs	REG_P, REG_P, #ARM_N_FLAG
	orrmi	REG_P_REST, REG_P_REST, #P_REST_V_FLAG
	bicpl	REG_P_REST, REG_P_REST, #P_REST_V_FLAG
.endm

op24:	@ BIT $nn
	ZERO_ADDR; ZP_READ; OP_BIT
	CYCLE_NEXT	3

op2C:	@ BIT $nnnn
	ABS_ADDR; READ; OP_BIT
	CYCLE_NEXT	4


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ ASL/LSR
@@@ 
@@@ �����եȡ������ե�
@@@ 
@@@ NZC���ѹ�����
@@@ 
.macro	OP_ASL
	movs	r0, r0, lsl #25
	mov	r0, r0, lsr #24
	MRS_P
.endm

.macro	OP_LSR
	movs	r0, r0, lsr #1
	MRS_P
.endm

op0A:	@ ASL A
	IMPLIED
	movs	REG_A, REG_A, lsl #1
	MRS_P
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
	ABS_ADDR; READ_W; OP_ASL
	WRITE_W
	CYCLE_NEXT	6

op1E:	@ ASL $nnnn, X
	ABSX_ADDR; READ_W; OP_ASL
	WRITE_W
	CYCLE_NEXT	7



op4A:	@ LSR A
	IMPLIED
	movs	REG_A, REG_A, lsr #25
	mov	REG_A, REG_A, lsl #24
	MRS_P
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
	ABS_ADDR; READ_W; OP_LSR
	WRITE_W
	CYCLE_NEXT	6

op5E:	@ LSR $nnnn, X
	ABSX_ADDR; READ_W; OP_LSR
	WRITE_W
	CYCLE_NEXT	7




@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ ROL/ROR
@@@
@@@ ����ž/����ž
@@@ 
@@@ NZC���ѹ�����
@@@ 
.macro	OP_ROL
	tst	REG_P, #ARM_C_FLAG
	movne	r1, #1 << 24
	moveq	r1, #0
	orrs	r0, r1, r0, lsl #25
	mov	r0, r0, lsr #24
	MRS_P
.endm

.macro	OP_ROR
	tst	REG_P, #ARM_C_FLAG
	movne	r1, #0x80
	moveq	r1, #0
	orrs	r0, r1, r0, lsr #1
	MRS_P
	tst	r0, #0x80
	orrne	REG_P, REG_P, #ARM_N_FLAG
	biceq	REG_P, REG_P, #ARM_N_FLAG
.endm

op2A:	@ ROL A
	IMPLIED
	tst	REG_P, #ARM_C_FLAG
	movne	r1, #1 << 24
	moveq	r1, #0
	orrs	REG_A, r1, REG_A, lsl #1
	MRS_P
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
	ABS_ADDR; READ_W; OP_ROL
	WRITE_W
	CYCLE_NEXT	6

op3E:	@ ROL $nnnn, X
	ABSX_ADDR; READ_W; OP_ROL
	WRITE_W
	CYCLE_NEXT	7


op6A:	@ ROR A
	IMPLIED
	tst	REG_P, #ARM_C_FLAG
	movne	r1, #0x80
	moveq	r1, #0
	orrs	r0, r1, REG_A, lsr #25
	MRS_P
	movs	REG_A, r0, lsl #24
	orrmi	REG_P, REG_P, #ARM_N_FLAG
	bicpl	REG_P, REG_P, #ARM_N_FLAG
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
	ABS_ADDR; READ_W; OP_ROR
	WRITE_W
	CYCLE_NEXT	6

op7E:	@ ROR $nnnn, X
	ABSX_ADDR; READ_W; OP_ROR
	WRITE_W
	CYCLE_NEXT	7

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ BCC/BCS/BNE/BEQ/BPL/BMI/BVC/BVS
@@@ 
@@@ ʬ��
@@@ 
op90:	@ BCC $nn
	IMM_VALUE
	tst	REG_P, #ARM_C_FLAG
	@@ Z ��Ω�Ƥ�
	beq	relative_jump
	CYCLE_NEXT	2

opB0:	@ BCS $nn
	IMM_VALUE
	tst	REG_P, #ARM_C_FLAG
	@@ Z ������Ƥ��
	bne	relative_jump
	CYCLE_NEXT	2

opD0:	@ BNE $nn
	IMM_VALUE
	tst	REG_P, #ARM_Z_FLAG
	@@ ��̤�0�ʤ�
	beq	relative_jump
	CYCLE_NEXT	2

opF0:	@ BEQ $nn
	IMM_VALUE
	tst	REG_P, #ARM_Z_FLAG
	@@ Z ������Ƥ��
	bne	relative_jump
	CYCLE_NEXT	2

op30:	@ BMI $nn
	IMM_VALUE
	tst	REG_P, #ARM_N_FLAG
	@@ ��̤�0�Ǥʤ��ʤ�
	bne	relative_jump
	CYCLE_NEXT	2

op10:	@ BPL $nn
	IMM_VALUE
	tst	REG_P, #ARM_N_FLAG
	@@ ��̤�0�ʤ�
	beq	relative_jump
	CYCLE_NEXT	2

op50:	@ BVC $nn
	IMM_VALUE
	tst	REG_P_REST, #P_REST_V_FLAG
	@@ ��̤�0�ʤ�
	beq	relative_jump
	CYCLE_NEXT	2

op70:	@ BVS $nn
	IMM_VALUE
	tst	REG_P_REST, #P_REST_V_FLAG
	@@ ���0�Ǥʤ��ʤ�
	bne	relative_jump
	CYCLE_NEXT	2


@@@ pc ���ؤ��Ƥ���Х󥯤���Ƭ���ɥ쥹
pc_bank:	.long	0

@@@ 
@@@ PC������ɤ���
@@@ 
@@@ r0	=> ������PC
@@@ 
.macro	LOAD_PC
	adr	r1, memory_map
	mov	r2, r0, lsr #13
	ldr	r1, [r1, r2, lsl #2]
	str	r1, pc_bank
	add	REG_PC, r0, r1
.endm

@@@ 
@@@ ���Х����פ�Ԥ�
@@@ 
@@@ r0	=> ���ե��å�
@@@ 
relative_jump:	
	ldr	r1, pc_bank
	@@ ����PC������
	sub	r1, REG_PC, r1
	mov	r0, r0, lsl #24
	@@ ����ĥ
	add	r0, r1, r0, asr #24
	LOAD_PC
	CYCLE_NEXT	3

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
	LOAD_PC
	CYCLE_NEXT	5

jmp_indirect_bug:
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
	LOAD_PC
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
@@@ ���ɥ쥹���֤�0x2000�Ť�8�ĤΥХ󥯤�ʬ����
@@@ ��������Ͽ����ݥ��󥿤Ϥ��餫���ᥪ�ե��åȤ�����Ƥ�������
@@@ ���������Ϣ³�����ΰ��ޥåפ���Ȥ���Ʊ�����ɥ쥹��Ϳ����
@@@ ���Ȥˤʤ롣
@@@ ���ɥ쥹��ޥ�������ɬ�פ��ʤ��ʤ�ΤϽ��פǤ��롣
	ALIGN
memory_map:	
	.long	nes_internal_ram
	.long	0, 0, 0
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
	b	op00
#if 0
	IMPLIED
	ldr	r0, =0xBBBBBBBB
	mov	r1, r0
1:	b	1b
	TRACE_JUMP_B
	mov	r0, REG_PC, lsr #16
	bl	push_stack_word
	orr	REG_P_REST, REG_P_REST, #P_REST_B_FLAG
	bl	save_P
	bl	push_stack_byte
	orr	REG_P_REST, REG_P_REST, #P_REST_I_FLAG
	ldr	REG_ADDR, = IRQ_VECTOR
	bl	read_word
	orr	r1, r0, REG_PC, lsl #16
	mov	REG_PC, r1, ror #16
	TRACE_JUMP_A
	b	cpu_exec_tail
	.pool
#endif

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
@@@ �����ߤν���
@@@ 
do_int:	
	mov	r0, REG_PC
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

	.globl	cpu_reset

@@@ 
@@@ �ꥻ�åȤν���
@@@ 
cpu_reset:
	stmfd	sp!, {lr}
	mov	REG_P, #ARM_Z_FLAG
	@@ REG_P_RESET �ξ�8�ӥåȤ�S�ʤΤǥޥ������ʤ���
	and	REG_P_REST, REG_P_REST, #0xFF << 24
	orr	REG_P_REST, REG_P_REST, #P_REST_I_FLAG
	mov	REG_ADDR, #0x10000
	sub	REG_ADDR, REG_ADDR, #RESET_VECTOR
	READ_WORD
	LOAD_PC
	ldmfd	sp!, {pc}

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ �������
@@@ 

	ALIGN
	.globl	set_memory_map_8toE
set_memory_map_8toE:	
	adr	r1, memory_map + 0x8 * 2
	str	r0, [r1]
	str	r0, [r1, #4]
	str	r0, [r1, #8]
	str	r0, [r1, #12]
	mov	pc, lr

@@@ 
@@@ r1 �ˤϴ��˥Х��ֹ椬�����ɤ���Ƥ���
@@@ 
read_rom_byte:	
	adr	r0, memory_map
	ldr	r0, [r0, r1, lsl #2]
	ldrb	r0, [r0, REG_ADDR]
	mov	pc, lr

write_rom_byte:	
	b	write_rom_byte

@@@ 
@@@ �ߥ顼��󥰤��θ���ʤ���Фʤ�ʤ�
@@@ 
read_ram_byte:	
	bic	r0, REG_ADDR, #0x1800
	add	r0, r0, #NES_RAM
	ldrb	r0, [r0]
	mov	pc, lr

write_ram_byte:	
	bic	r1, REG_ADDR, #0x1800
	add	r1, r1, #NES_RAM
	strb	r0, [r1]
	mov	pc, lr


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@	
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@	
@@@ 
@@@ �ǥХå��ѵե�����֥�
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
@@@ 6502 �򥨥ߥ�졼�Ȥ���
@@@ 
@@@ REG_CYCLE	=> �¹Ԥ��륵������
@@@ REG_CYCLE	<= �ĤäƤ��륵������(���ޤ�����)
	.globl	cpu_exec

cpu_exec:
	cmp	REG_CYCLE, #0
	movle	pc, lr
	stmfd	sp!, {lr}

	adr	REG_OP_TABLE, cpu_exec_table

	tst	REG_P_REST, #P_REST_NMI_PENDING
	bne	do_int

	@@ 1̿��¹Ԥ���
	@@ �����ߤΥ����å���ɬ�פʾ��Ϥ�������äƤ���
cpu_exec_check_int:
	tst	REG_P_REST, #P_REST_I_FLAG
	ldrneb	r0, [REG_PC], #1
	ldrne	pc, [REG_OP_TABLE, r0, lsl #2]
	@@ �����ߤΥ����å�
	tst	REG_P_REST, #P_REST_INT_PENDING
	bne	do_int

	@@ �����ߤΥ����å���ɬ�פʤ��Ȥ��Ϥ�������
	@@ �Ǥ⡤���ޤꤳ���ˤϵ��äƤ��ʤ�
cpu_exec_no_int:
	ldrb	r0, [REG_PC], #1
	ldr	pc, [REG_OP_TABLE, r0, lsl #2]

	ALIGN
@@@ 
@@@ �ߤ�Ф狼��褦�˥��ڥ����ɤ򥤥�ǥå����ˤ��������ץơ��֥�
@@@ 0x400�Х���
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
@@@ ���ڥ����ɥơ��֥��ľ��ˤ�����֤�REG_OP_TABLE���Ф�
@@@ ���ѤǤ���
@@@ 
nes_internal_ram:
	.fill	0x100, 1, 0
nes_stack:	
	.fill	0x700, 1, 0


	SECTION_SLOW
	ALIGN
	.globl	init_cpu

init_cpu:
	mov	REG_A, #0
	mov	REG_X, #0
	mov	REG_Y, #0
	mov	REG_S, #0xFF << 24
	mov	pc, lr

	.pool

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
1:	b	1b