#include "nes.h"

	SECTION_FAST
	ALIGN

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ 
@@@ �ѥ�åȤ��Ѵ�
@@@ 
@@@ �ѥ�åȤ��ɤ߽񤭤Ǥ���Τǡ��ɤ�Ȥ��ˤ��ʤ��ƥ��ԡ���
@@@ �ȤäƤ����ʤ���Фʤ�ʤ���
@@@ �����Ʊ����GBA�Υѥ�å�RAM�ˤ�񤭹��ࡣ
@@@ 

	SECTION_FAST
	ALIGN
bg_palette:
	.fill	0x16, 1, 0
spr_palette:	
	.fill	0x16, 1, 0
	
	ALIGN

@@@ 
@@@ $2007��ͳ�ǥѥ�åȤ��ɤ�
@@@ 
@@@ r1	=> VRAM���ɥ쥹 
@@@ r0	<= ���
	.globl	read_palette

read_palette:	
	and	r1, r1, #0x1F
	adr	r0, bg_palette
	ldrb	r0, [r0, r1]
	mov	pc, lr

@@@ 
@@@ $2007��ͳ�ǥѥ�åȤ˽�
@@@ 
@@@ r0	=> �񤯥Х���
@@@ r1	=> VRAM���ɥ쥹
@@@ 
@@@ GBA�Υѥ�åȤ�0500_0000�ˤ���
@@@ BG�Υѥ�åȤ�256����ȥ�
@@@ SPR�Υѥ�åȤ�256����ȥꤢ��
@@@ 
@@@ NES�Υѥ�åȤ�4*4��
@@@ GBA�Υѥ�åȤ�16*16
@@@ 
	.globl	write_palette

write_palette:	
	@@ �Ȥꤢ�������ԡ���Ȥ�
	and	r0, r0, #0x3F
	and	r1, r1, #0x1F
	adr	r2, bg_palette
	strb	r0, [r2, r1]
	@@ �ѥ�å�0�ϥߥ顼����Ƥ���
	tst	r1, #0xF
	eoreq	r1, r1, #0x10
	streqb	r0, [r2, r1]
	biceq	r1, r1, #0x10

	@@ �����Ѵ�����
	adr	r2, nes_palette
	ldr	r0, [r2, r0, lsl #2]

	@@ �ѥ�åȰ��֤��Ѵ�����
	adr	r2, palette_map
	ldr	r1, [r2, r1, lsl #2]
	strh	r0, [r1]

	mov	pc, lr

	ALIGN

palette_map:	
#define P(n)	0x05000000 + n
	.long	P(0x00),  P(0x02), P(0x04), P(0x06)
	.long	P(0x20),  P(0x22), P(0x24), P(0x26)
	.long	P(0x40),  P(0x42), P(0x44), P(0x46)
	.long	P(0x60),  P(0x62), P(0x64), P(0x66)
#undef P
#define P(n)	0x05000000 + n + 512
	.long	P(0x00),  P(0x02), P(0x04), P(0x06)
	.long	P(0x20),  P(0x22), P(0x24), P(0x26)
	.long	P(0x40),  P(0x42), P(0x44), P(0x46)
	.long	P(0x60),  P(0x62), P(0x64), P(0x66)
#undef P
	
	ALIGN

#include "palette.S"
