#ifndef GBA_REGS_H
#define GBA_REGS_H

/*
 * GBA �Υ쥸�����Υꥹ�Ȥȥ�ե����
 *
 */


/*
 * �쥸�����Υ١������ɥ쥹
 *
 */
#define GBA_REG_BASE	0x04000000


/*
 * �ǥ����ץ쥤������쥸����
 *
 * CR_MODE
 * Mode 0 Text Text Text Text
 * Mode 1 Text Text Rot   --
 * Mode 2  --   --  Rot  Rot
 * Mode 3  --   -- 15bit  --
 * Mode 4  --   --  8bit  --
 * Mode 5  --   -- 15bit  -- (160x128)
 *
 * CR_BLANK
 * ���̤��򤯤ʤ�
 *
 * ENB_BGn
 * BGn��ͭ���ˤ���
 *
 * ENB_SPR
 * ���ץ饤�Ȥ�ͭ���ˤ���
 *
 */
#define GBA_DISP_CR	0x000

#define GBA_DISP_CR_MODE(n)	(n)
#define GBA_DISP_CR_FB(n)	((n) << 4)
#define GBA_DISP_CR_1D_SPR	(1 << 6)
#define GBA_DISP_CR_BLANK	(1 << 7)

#define GBA_DISP_CR_ENB_BG0	(1 << 8)
#define GBA_DISP_CR_ENB_BG1	(1 << 9)
#define GBA_DISP_CR_ENB_BG2	(1 << 10)
#define GBA_DISP_CR_ENB_BG3	(1 << 11)

#define GBA_DISP_CR_ENB_SPR	(1 << 12)
#define GBA_DISP_CR_ENB_WIN0	(1 << 13)
#define GBA_DISP_CR_ENB_WIN1	(1 << 14)
#define GBA_DISP_CR_ENB_SPR_WIN	(1 << 15)


/*
 * �ǥ����ץ쥤�ξ��֥쥸����
 *
 */
#define GBA_DISP_SR	0x004

#define GBA_DISP_SR_IN_VBL	(1 << 0)
#define GBA_DISP_SR_IN_HBL	(1 << 1)
#define GBA_DISP_SR_Y_TRIGGERED	(1 << 2)
#define GBA_DISP_SR_ENB_VBL_IRQ	(1 << 3)
#define GBA_DISP_SR_ENB_HBL_IRQ	(1 << 4)
#define GBA_DISP_SR_ENB_Y_IRQ	(1 << 5)

#define GBA_DISP_SR_Y(y)	((y) << 8)

#define GBA_DISP_Y  0x006

/*
 * BG����쥸����
 * HBL�δ֤ˤ�񴹤�����褦��
 *
 * TILE_ADDR
 * 0: 0600 0000
 * 1: 0600 4000
 * 2: 0600 8000
 * 3: 0600 C000
 *
 * UNI_PALETTE
 * 256���ѥ�åȤ�Ȥ�
 *
 * MAP_ADDR
 * 00: 0600 0000
 * 01: 0600 0800
 * 02: 0600 1000
 *      :
 * 1F: 0600 F800
 */


#define GBA_BGn_CR(n)	(0x008 + (n) * 2)

#define GBA_BG_CR_PRIORITY(n)	(n)
#define GBA_BG_CR_TILE_ADDR(n)	((n) << 2)
#define GBA_BG_CR_MOSAIC	(1 << 6)
#define GBA_BG_CR_UNI_PALETTE	(1 << 7)

#define GBA_BG_CR_MAP_ADDR(n)	((n) << 8)
#define GBA_BG_CR_SIZE_256x256	(0 << 14)
#define GBA_BG_CR_SIZE_512x256	(1 << 14)
#define GBA_BG_CR_SIZE_256x512	(2 << 14)
#define GBA_BG_CR_SIZE_512x512	(3 << 14)


/*
 * BGnX, BGnY
 * BG��������쥸����
 * 
 * 0-511�ޤǥ�������Ǥ���
 * �Ȥʤꤢ�äƤ�Τ�X��Y��str��Ʊ��������Ǥ���
 */
#define GBA_BGn_X(n)	(0x010 + (n) * 4)
#define GBA_BGn_Y(n)	(0x012 + (n) * 4)


/*
 * DMA�쥸����
 *
 * SRC, DST���ɥ쥹��32�ӥåȽ񤭹��ߤ�����Ǥ���
 *
 * *_INCW: ���ɥ쥹�����ä����ɥ쥹�쥸�����˽񤭹��ޤ��
 * *_DECW: ���ɥ쥹�ϸ��������ɥ쥹�쥸�����˽񤭹��ޤ��
 * *_FIXED:���ɥ쥹�ϸ���
 * *_INC:  ���ɥ쥹�����ä��뤬�쥸�����ˤϽ񤭹��ޤ�ʤ�
 * 
 * REP
 * ̵���ˤ����ޤ�ư���ĤŤ���
 *
 * WORD
 * 4�Х��ȤŤ�ž��������ʤ�����2�Х���
 *
 * VBL��HBL
 * VBL��HBL����ž������
 *
 * IMM
 * ������ž������
 *
 * IRQ
 * ��λ�����������
 *
 * ENB
 * DMA��ͭ���ˤ���
 */
#define GBA_DMAn_SRC(n)		(0x0B0 + (n) * 0xC)
#define GBA_DMAn_DST(n)		(0x0B4 + (n) * 0xC)
#define GBA_DMAn_SIZE(n)	(0x0B8 + (n) * 0xC)
#define GBA_DMAn_CR(n)		(0x0BA + (n) * 0xC)

#define GBA_DMA_DST_INCW	(0 << 5)
#define GBA_DMA_DST_DECW	(1 << 5)
#define GBA_DMA_DST_FIXED	(2 << 5)
#define GBA_DMA_DST_INC		(3 << 5)

#define GBA_DMA_SRC_INCW	(0 << 7)
#define GBA_DMA_SRC_DECW	(1 << 7)
#define GBA_DMA_SRC_FIXED	(2 << 7)

#define GBA_DMA_REP		(1 << 9)
#define GBA_DMA_WORD		(1 << 10)
#define GBA_DMA_IMM		(0 << 12)
#define GBA_DMA_VBL		(1 << 12)
#define GBA_DMA_HBL		(2 << 12)
#define GBA_DMA_IRQ		(1 << 14)
#define GBA_DMA_ENB		(1 << 15)


/*
 * ������
 *
 * �����󥿤����ä���0�ˤʤä��Ȥ��˳�����
 *
 * TIMER_1:    16/1    MHz
 * TIMER_64:   16/64   MHz
 * TIMER_256:  16/256  MHz
 * TIMER_1024: 16/1024 MHz
 *
 */
#define GBA_TIMERn_DATA(n)	(0x100 + (n) * 4)
#define GBA_TIMERn_CR(n)	(0x102 + (n) * 4)

#define GBA_TIMER_1		0
#define GBA_TIMER_64		1
#define GBA_TIMER_256		2
#define GBA_TIMER_1024		3

#define GBA_TIMER_CASCADE	(1 << 2)
#define GBA_TIMER_IRQ		(1 << 6)
#define GBA_TIMER_ENB		(1 << 7)


/*
 * �ѥå�
 *
 * �������б�����ӥåȤ����ꥢ�����
 */
#define GBA_KEY		0x130

#define GBA_KEY_A	(1 << 0)
#define GBA_KEY_B	(1 << 1)
#define GBA_KEY_SEL	(1 << 2)
#define GBA_KEY_STA	(1 << 3)
#define GBA_KEY_RIGHT	(1 << 4)
#define GBA_KEY_LEFT	(1 << 5)
#define GBA_KEY_UP	(1 << 6)
#define GBA_KEY_DOWN	(1 << 7)
#define GBA_KEY_R	(1 << 8)
#define GBA_KEY_L	(1 << 9)
/* �ɤ��Ȥ������ */
#define GBA_KEY_ALL	(1 << 10)

/*
 * IE
 * �Ƴ����ߤε���
 * IF
 * �����ߥե饰
 * IME
 * ���Ƥγ����ߤε��ġ��ػ�
 */
#define GBA_IE	0x200
#define GBA_IF	0x202
#define GBA_IME	0x208

#define GBA_IRQ_VBL	(1 << 0)
#define GBA_IRQ_HBL	(1 << 1)
#define GBA_IRQ_Y	(1 << 2)
#define GBA_IRQ_TIMERn(n) (1 << (3 + n))
#define GBA_IRQ_COM	(1 << 7)
#define GBA_IRQ_DMAn(n)	(1 << (8 + n))
#define GBA_IRQ_KEY	(1 << 12)
#define GBA_IRQ_CART	(1 << 13)

/*
 * �������
 *
 */
#define GBA_SG10	0x60
#define GBA_SG11	0x64

#define GBA_SG20	0x68
#define GBA_SG21	0x6C

#define GBA_SG30	0x70
#define GBA_SG31	0x74

#define GBA_SG40	0x78
#define GBA_SG41	0x7C

#define GBA_SGCNT0	0x80
#define GBA_SGCNT1	0x84

#define GBA_SGWR	0x90


#ifndef __ASSEMBLY__

extern inline int readb(int reg)
{
  return *(volatile unsigned char *)(GBA_REG_BASE + reg);
}

extern inline int readh(int reg)
{
  return *(volatile unsigned short *)(GBA_REG_BASE + reg);
}

extern inline int readw(int reg)
{
  return *(volatile unsigned int *)(GBA_REG_BASE + reg);
}

extern inline void writeb(int reg, int value)
{
  *(volatile unsigned char *)(GBA_REG_BASE + reg) = value;
}

extern inline void writeh(int reg, int value)
{
  *(volatile unsigned short *)(GBA_REG_BASE + reg) = value;
}

extern inline void writew(int reg, int value)
{
  *(volatile unsigned int *)(GBA_REG_BASE + reg) = value;
}

#endif


#endif
