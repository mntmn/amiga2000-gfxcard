/*
  macros.h

  (C) 2018 Henryk Richter <henryk.richter@gmx.net>

  useful macros

*/
#ifndef _INC_MACROS_H
#define _INC_MACROS_H

#define GetHead(l)       (void *)(((struct List *)l)->lh_Head->ln_Succ \
                                ? ((struct List *)l)->lh_Head \
                                : (struct Node *)0)
#define GetTail(l)       (void *)(((struct List *)l)->lh_TailPred->ln_Pred \
                                ? ((struct List *)l)->lh_TailPred \
                                : (struct Node *)0)
#define GetSucc(n)       (void *)(((struct Node *)n)->ln_Succ->ln_Succ \
                                ? ((struct Node *)n)->ln_Succ \
                                : (struct Node *)0)
#define GetPred(n)       (void *)(((struct Node *)n)->ln_Pred->ln_Pred \
                                ? ((struct Node *)n)->ln_Pred \
                                : (struct Node *)0)

#define REMOVE(n)        ((void)(\
        ((struct Node *)n)->ln_Pred->ln_Succ = ((struct Node *)n)->ln_Succ,\
        ((struct Node *)n)->ln_Succ->ln_Pred = ((struct Node *)n)->ln_Pred ))

#define ADDHEAD(l,n)     ((void)(\
        ((struct Node *)n)->ln_Succ          = ((struct List *)l)->lh_Head, \
        ((struct Node *)n)->ln_Pred          = (struct Node *)&((struct List *)l)->lh_Head, \
        ((struct List *)l)->lh_Head->ln_Pred = ((struct Node *)n), \
        ((struct List *)l)->lh_Head          = ((struct Node *)n)))

#define ADDTAIL(l,n)     ((void)(\
        ((struct Node *)n)->ln_Succ              = (struct Node *)&((struct List *)l)->lh_Tail, \
        ((struct Node *)n)->ln_Pred              = ((struct List *)l)->lh_TailPred, \
        ((struct List *)l)->lh_TailPred->ln_Succ = ((struct Node *)n), \
        ((struct List *)l)->lh_TailPred          = ((struct Node *)n) ))

#define NEWLIST(l) (((struct List *)l)->lh_TailPred = (struct Node *)(l), \
                    ((struct List *)l)->lh_Tail = 0, \
	            ((struct List *)l)->lh_Head = (struct Node *)&(((struct List *)l)->lh_Tail))


#define min(_a_,_b_) ( (_a_) > (_b_) ) ? _b_ : _a_
#define max(_a_,_b_) ( (_a_) < (_b_) ) ? _b_ : _a_
#define BOUNDS(_val_,_min_,_max_) ( (_val_) < (_min_) ) ? _min_ : ( (_val_) > (_max_) ) ? _max_ : _val_


#endif /* _INC_MACROS_H */

