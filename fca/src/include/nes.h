#ifndef NES_H
#define NES_H

#define SECTION_FAST .section emu.fast, "awx"
#define SECTION_SLOW .section emu.slow, "awx"
#define SECTION_HEAD .section emu.head, "awx"

#define ALIGN .align 2

#define FOUR_SCREEN 3
#define VERTICAL_SCREEN 2
#define HORIZONTAL_SCREEN 1

/*
 * 6502 �Υ쥸����
 *
 * A �Ͼ�� 24 �ӥåȥ��եȤ��Ƥ���
 * P ��NZC�Τߡ��Ĥ��¾�ξ����֤�
 * P �� ARM �Υ��ơ������ӥåȤ�Ʊ���ե����ޥåȤˤ���
 *
 * S ��24�ӥåȥ��եȤ��Ƥ���
 * �����;�äƲ��ΥӥåȤ� P �λĤ���֤�(VBDI)
 * �����;�äƤ�Ȥ����ˤϳ����ߤ˴ؤ���ե饰���֤�
 *
 * PC ��ROM��Υ��ɥ쥹���Ѵ����Ƥ���
 * ���ξ��϶��������å��򤷤��ۤ��������Τ�������ñ�ǤϤʤ�
 * ������ PC �����뤿��ˤϸ��ߤΥХ󥯤���Ƭ���ɥ쥹������Ф褤
 */
#define REG_A  r4
#define REG_X  r5
#define REG_Y  r6
#define REG_PC r7
#define REG_S  r8
#define REG_P  r9
#define REG_P_REST REG_S

/*
 * REG_P �ǻȤ��ե饰
 */
#define ARM_N_FLAG 0x80000000
#define ARM_Z_FLAG 0x40000000
#define ARM_C_FLAG 0x20000000
#define ARM_V_FLAG 0x10000000

/*
 * REG_P_REST �ˤϳƼ�ե饰���֤�
 *
 * 0
 * FEDCBA98 76543210
 * |||||||| |||||||+---IRQ��ȯ��
 * |||||||| ||||||+---NMI��ȯ��
 * |||||||| |||||+---I �����ߵ���
 * |||||||| ||||+---D ���ʥ⡼��
 * |||||||| |||+---B
 * |||||||| ||+---����
 * |||||||| |+---V �����С��ե���
 * |||||||| +---$2005/$2006 �ȥ���ե饰
 * ||||||||
 * |||||||+---$2000[2] 32���󥯥����
 * ||||||+---$2000[3] ���ץ饤�ȥ��ɥ쥹����
 * |||||+---$2000[4] �Хå����饦��ɥ��ɥ쥹����
 * ||||+---$2000[5] ���ץ饤�ȥ�����
 * |||+---̤����
 * ||+---$2000[7] NMI����
 * |+---$2001[3] �Хå����饦��ɤ�����
 * +---$2001[4] ���ץ饤�Ȥ�����
 *
 * 1
 * FEDCBA9876543210
 * |||||||||||||||+---$2002[4] VRAM�˽񤭹��߲ġ�
 * ||||||||||||||+---$2002[5] ���ץ饤�Ȥ�¿����
 * |||||||||||||+---$2002[6] ���ץ饤�ȥҥå�(�����Ǥ���Τ���)
 * ||||||||||||+---$2002[7] VBL
 * ||||||||++++---̤����
 * ++++++++---S �����å��ݥ���
 *
 */


/*
 * REG_P_REST �ǻȤ��ե饰������Ū��P��Ʊ�����֤ˤ���
 */
#define P_REST_V_FLAG 0x40
#define P_REST_B_FLAG 0x10
#define P_REST_D_FLAG 0x08
#define P_REST_I_FLAG 0x04
#define P_REST_FLAGS  0x5C

/*
 * �����ߤ�ȯ������ȥ��åȤ����
 */
#define P_REST_INT_PENDING 0x01
#define P_REST_NMI_PENDING 0x02

#define ASSERT_NMI	orr	REG_P_REST, REG_P_REST, #P_REST_NMI_PENDING
#define ASSERT_INT	orr	REG_P_REST, REG_P_REST, #P_REST_INT_PENDING

/*
 * 2005/2006�Υȥ���
 */
#define P_REST_PPU_TOGGLE 0x80

/*
 * �쥸����$2000��P_REST[8-13]�ˤ���
 */
#define P_REST_PPU_32     0x0100
#define P_REST_SPR_ADR    0x0200
#define P_REST_BG_ADR     0x0400
#define P_REST_SPR_SZ     0x0800
#define P_REST_ENB_NMI    0x2000
#define P_REST_2000       0x3F00

/*
 * �쥸����$2001��P_REST[14-15]�˰ʲ��Τդ��Ĥ��֤�
 */
#define P_REST_DRAW_BG    0x4000
#define P_REST_DRAW_SPR   0x8000
#define P_REST_2001       0xC000

/*
 * �쥸����$2002��P_REST[16-19]�˰ʲ��򤪤�
 */
#define P_REST_VRAM_WR    0x10000
#define P_REST_SPR_COUNT  0x20000
#define P_REST_SPR_HIT    0x40000
#define P_REST_IN_VBL     0x80000
#define P_REST_2002       0xF0000

/*
 * 6502 �������Υե饰
 */
#define P_N_FLAG 0x80
#define P_V_FLAG 0x40
#define P_R_FLAG 0x20
#define P_B_FLAG 0x10
#define P_D_FLAG 0x08
#define P_I_FLAG 0x04
#define P_Z_FLAG 0x02
#define P_C_FLAG 0x01

#define NMI_VECTOR   6
#define RESET_VECTOR 4
#define IRQ_VECTOR   2

/*
 * �������줿���ɥ쥹
 */
#define REG_ADDR r10

/*
 * �Ĥꥵ������
 */
#define REG_CYCLE r11

/*
 * ̿��Υ����ץơ��֥�
 */
#define REG_OP_TABLE r12

#endif