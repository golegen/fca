#ifndef WINDOW_H
#define WINDOW_H

#include <stdarg.h>

struct window {
  struct window *next;
  char x, y;
  char w, h;

  void (*draw)(struct window *wn);

  int ev;
};

struct message_window {
  struct window wn;
  char msg[256];
};

struct menu_window {
  struct window wn;
  int n;
  int n_vis;
  int top;
  int sel;
  void (*draw_item)(struct menu_window *menu, int n, int x, int y);
};

#define EV_QUIT      0
#define EV_NONE      1
#define EV_DRAW      2
#define EV_KEY_PRESS 3
#define EV_CURSOR    4

#define EV_NEXT_MSG  5

void push_window(struct window *wn, char x, char y, char w, char h);
void pop_window();
int  run_window(struct window *wn, int *param);

void quit_window(struct window *wn);

void push_message_window(struct message_window *mwn);
int run_message_window(struct message_window *mwn, int *param);
void set_message_widow(struct message_window *mwn, char *msg);
void set_message(struct message_window *mwn, char *fmt, ...);
void set_vmessage(struct message_window *mwn, char *fmt, va_list va);

int yes_or_no();
int no_or_yes();
int yes_or_no_message(char *fmt, ...);
int no_or_yes_message(char *fmt, ...);

void push_menu_window(struct menu_window *menu, int x, int y,
		      int w, int n, int n_vis);

int run_menu_window(struct menu_window *menu, int *param);

struct file;
int select_file(char *msg, int width, void *(get_file)(int n, struct file *f));

void warn(char *fmt, ...);

#define WARN  "    *** けいこく ***\n\n"
#define ERROR "    *** エラー ***\n\n"

#endif
