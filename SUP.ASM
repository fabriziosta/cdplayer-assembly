;;; Name: SUPCDPLAYER                                                ;;;
;;; Description: play sounds from audio CDs using MSCDEX interrupts. ;;;
;;; Assembler: NBASM 00.24.95 NewBasic Assembler                     ;;;
;;; Author: Fabrizio Asta                                            ;;;
;;; ID: 210422                                                       ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.model tiny
.code
.386
start:     mov si,offset Welcome        ;print welcome message
           call Prtstring

           mov si,offset Keys           ;drawing TUI
           call Prtstring

           mov bx,offset Time           ; 1.start setting up
           mov dx,11                    ; 11 in dx and call for the first
           call Ioctl_i                 ; time cdrequest

           mov  bx,offset info1         ; 2.setting up for tracks info
           mov  dx,05h                  ; 5 in dx and again cdrequest
           call ioctl_i
           mov  si,offset info1
           add  si,03h                  ;let's select 4th element in info1
           call HSect                   ;call procedure
           mov  HSout,eax               ;write value in HSout

           mov  si,offset info1         ; point again to 1st element in info1
           xor  ah,ah                   ; clean ah bits using xor
           mov  al,[si+2]               ; Got here tot num of tracks!!
           mov  LastTrk,al              ; last track 
           mov  al,[si+1]               ;
           mov  FirstTrk,al             ; first track 

           mov  si,offset info1         ; write from info1 to info2 a value
           xor  ah,ah                   
           mov  al,[si+1]               ; find track len
           mov  si,offset info2         ; and put it in si+1(info2)
           mov  [si+1],al               

           mov  bx,offset info2           
           mov  dx,07h                  
           call ioctl_i
           mov  si,offset info2           
           inc  si                      ; increase si
           inc  si                      
           call HSect                  
           mov  Ssect,eax            
           mov  edx,HSout               ; Nsect = HSout-Ssect
           sub  edx,eax                 ; HSOUT - Ssect             
           mov  Nsect,edx               

           xor  al,al                   ; clean sec,min,hour
           mov  bx,offset Time
           mov  [bx+4],al               ; hour = 00
           mov  [bx+5],al               ; min = 00
           mov  [bx+6],al               ; sec = 00

GetKey:    mov  ah,01h
           int  16h                     ;check keyboard buffer
           jz   NoKey
           xor  ah,ah
           int  16h                     ;"escamotage" to avoid BIOS loop
           cmp  al,27
           je   ESC                     ;exit program, back to DOS
           cmp  al,'N'
           je   short keyN              ;previous track
           cmp  al,'M'
           je   short keyM              ;next track
           cmp  al,'O'
           je   short keyO              ;pause track
           cmp  al,'P'
           jne  NoKey                   ;not equal? jump to noKey!

           mov edx,Ssect                ;start playing track
           mov ebx,Nsect                
           call Play                    
           mov  byte LastChar,20h       
           jmp  NoKey                   ; go update time and track num

keyO:      mov  bx,offset PauseRequest  ; pause
           call cdrequest               ;
           mov  al,FirstTrk
           call Jumpnext                ; jump to track
           xor  al,al                   ; clean al using xor
           mov  bx,offset Time          ; point 1st time element in bx 
           mov  [bx+4],al               ; 5th bx element = 0 (hour)
           mov  [bx+5],al               ; 6th bx element = 0 (minute)
           mov  [bx+6],al               ; 7th bx element = 0 (second)
           mov  byte LastChar,'O'       ;
           jmp  short NoKey             ; go and update time and track num

keyM:      mov  al,CurrTrk               ; goto next track
           inc  al                      ;
           cmp  al,LastTrk              ;
           jbe  short B1
           mov  al,FirstTrk             ; go back to the first track!
B1:        call Jumpnext                ; jump to track
           mov  bx,offset PauseRequest  ; pause playing
           call cdrequest               ;
           mov  edx,Ssect               ; Play
           mov  ebx,Nsect               ;
           call Play                    ;
           mov  byte LastChar,20h       ;
           jmp  short NoKey             ; go and update time and track num

keyN:      mov  al,CurrTrk              ; Previous track
           dec  al                      ;
           cmp  al,FirstTrk             ;
           jae  short C1   
           mov  al,LastTrk              ;
C1:        call Jumpnext                ; jump to track
           mov  bx,offset PauseRequest  ; pause playing
           call cdrequest               ;
           mov  edx,Ssect               ; Play
           mov  ebx,Nsect               ;
           call Play                    ;
           mov  byte LastChar,20h       ;
           jmp  short NoKey             ; go and update time and track num

ESC:       mov  bx,offset PauseRequest  ; stop playing
           call cdrequest               
                       
           mov si,offset goodbye        ; show a message before exiting
           call prtstring
           mov  ah,4Ch                  ; and exit to DOS
           int  21h

NoKey:     cmp  byte LastChar,'O'       ; compare lastchar with pause char
           je   short pause             ; if equal, jump to pause
           mov  bx,offset Time          ; if not, update time
           mov  dx,11                   ;
           call Ioctl_i                 ; return status in ax
pause:     mov  si,offset TrackNum      ; print every loop "Track:"
           call prtstring               ;
           xor  ah,ah                   ; clean ah with xor
           mov  dl,[bx+2]               ; 3rd time element!
           mov  al,dl                   ; ---> start searching currtrack 
           and  dl,0Fh                  ;
           and  al,0F0h                 ;
           mov  cl,04h                  ;
           shr  al,cl                   ;
           mov  cl,10                   ;
           mul  cl                      ;
           add  dl,al                   ;
           mov  al,dl                   ; <--- Al receives current track!
           xor  ah,ah                   ;
           call prtdec                  ; print current track
           mov  CurrTrk,al              ; updating my variable
           mov  si,offset CurrTime      ;
           call prtstring               ; print every loop "Elapsed Time:"
           mov  al,[bx+4]               ; 5th time element! hours
           cmp  al,10                   ; -->
           jae  short S1                ; if above or equal...
           push ax                      ; 
           mov  ah,02h                  ; print "0" in stdout
           mov  dl,48                   ;
           int  21h                     ;
           pop  ax                      ; <--
S1:        call prtdec                  ; print value
           mov  ah,02                   ;
           mov  dl,':'                  ;
           int  21h                     ; print ":" character in stdout
           xor  ah,ah                   ; clean ah with xor
           mov  al,[bx+5]               ; 6th time element! minutes
           cmp  al,10                   ; -->
           jae  short S2                ; if above or equal...
           push ax                      ; 
           mov  ah,02h                  ; print "0" in stdout
           mov  dl,48                   ;
           int  21h                     ;
           pop  ax                      ; <--
S2:        call prtdec                  ; print minutes
           mov  ah,02                   ;
           mov  dl,':'                  ; print ":" char in stdout
           int  21h                     ;
           xor  ah,ah                   ; clean ah with xor
           mov  al,[bx+6]               ; 7th time element! seconds
           cmp  al,10                   ; -->
           jae  short S3                ; if above or equal...
           push ax                      ; 
           mov  ah,02h                  ; print "0" in stdout
           mov  dl,48                   ;
           int  21h                     ;
           pop  ax                      ; <--
S3:        call prtdec                  ; print seconds in stdout
           mov  ah,02                   ; every loop print a space!
           mov  dl,20h                  ;
           int  21h                     ;
           mov  ah,02                   ; every loop use a carriage return!
           mov  dl,13                   ;
           int  21h                     ; After updating time and track,
           jmp  GetKey                  ; go back to the top.

Ioctl_i PROC near uses si bx dx         ;populate "in" array buffer
           mov  si,offset in
           xor  eax,eax                 ;
           mov  [si+13],al              ; 
           mov  [si+20],al              ; 
           mov  [si+22],eax             ; 
           mov  al,13
           mov  [si],al                 ; 
           mov  al,03
           mov  [si+2],al               ; 
           xor  ax,ax                     
           mov  [si+3],ax               ; status
           mov  [si+14],bx              ; 
           mov  ax,ds                   ;
           mov  [si+16],ax              ; data seg
           mov  [si+18],dx              ; 
           mov  bx,offset in
           call cdrequest
           mov  ax,[si+3]               ; status
           RET
Ioctl_i ENDP

cdrequest PROC near uses si bx          ;main MSCDEX interrupt
           push ds
           pop  es
           mov  cx,06h                  ;change here! 3=C:,4=D:,5=E:,6=G:.. 
           mov  ax,1510h
           int  2Fh
           RET
cdrequest ENDP

HSect PROC near uses bx ecx edx         ;populate info1 and info2 arrays
           xor  eax,eax
           xor  edx,edx
           xor  bh,bh
           mov  dl,[si]                 ; frame
           mov  bl,[si+1]               ; sec
           mov  al,[si+2]               ; min
           mov  cx,60
           mul  cx
           add  ax,bx
           mov  ecx,75
           mul  ecx
           add  eax,edx
           sub  eax,150          
           RET
HSect ENDP

Play PROC near                          ;populate play array buffer
           xor  al,al
           mov  si,offset PlayRequest
           mov  [si+13],al
           mov  [si+14],edx
           mov  [si+18],ebx
           mov  al,13
           mov  [si],al
           mov  al,132
           mov  [si+2],al
           xor  ax,ax
           mov  [si+3],ax
           mov  bx,offset PlayRequest
           call cdrequest
           mov  dx,[si+3]               ; status
           RET
Play ENDP

JumpNext PROC near                      ; procedure to jump back and forward 
           mov  si,offset info2         ; and put it in trk #
           mov  [si+1],al               ;
           mov  bx,offset info2
           mov  dx,07h
           call ioctl_i
           mov  si,offset info2
           inc  si
           inc  si
           call HSect                   ;update info2

           mov  Ssect,eax
           mov  edx,HSout               ; Nsect = HSout-Ssect
           sub  edx,eax                 
           mov  Nsect,edx               
           RET
JumpNext ENDP

Prtstring PROC near uses ax             ; macro to print strings in asm
P1:        mov  dl,[si]                 ; Get character
           inc  si                      ; Go to next one
           or   dl,dl                   ; End of str?
           jz   short P2                ; Yes? exit
           mov  ah,02h                  ; Print char
           int  21h
           jmp  short P1                ; No? Loop
P2:        RET
Prtstring ENDP

PrtDec PROC near uses ax cx dx          ; macro to print values in asm
           mov  cx,0FFFFh               ; Ending flag
           push cx
           mov  cx,10
Q1:        xor  dx,dx
           div  cx                      ; Divide by 10
           add  dl,30h                  ; Convert to ASCII
           push dx                      ; Save dx in the stack
           or   ax,ax                   ; Are we done?
           jnz  short Q1                ; No, continue
Q2:        pop  dx                      ; retrieve dx
           cmp  dx,0FFFFh               ; ending flag?
           je   short Q3                ; Yes, continue
           mov  ah,02h                  ; Print a char
           int  21h                     ; interrupt
           jmp  short Q2                ; Loop
Q3:        RET
PrtDec ENDP

Welcome       db  13,10,'Welcome to SUPINFO CD player!'
              db  13,10,'Description: Play sounds from Audio CD'
              db  13,10,'Assembled with NBASM 16-bit ver 00.24.95'
              db  13,10,'Author: Fabrizio Asta',13,10,10,0
Goodbye       db  13,10,'Goodbye and have a nice day',0
TrackNum      db  'Track: ',0
CurrTime      db  '  Time: ',0
Keys          db  'User keys:',13,10
              db  '      <P> to "Play"',13,10
              db  '      <O> to "Pause"',13,10
              db  '      <M> to "Go to Next Track"',13,10
              db  '      <N> to "Go to Previous Track"',13,10
              db  '      <ESC> to Stop and Exit.',13,10,13,10,0

HSout         dd  0000h
Ssect         dd  0000h
Nsect         dd  0000h
CurrTrk       db  00h
LastTrk       db  00h
FirstTrk      db  01h
LastChar      db  'Z'

PauseRequest  db 13,0,133             
              dw  00h                  ; status
              db  0,0,0,0,0,0,0,0      ; reserved
in            db  0,0,0                
              dw  00h                  ; status
              db  0,0,0,0,0,0,0,0      ; reserved
              db  00h                  
              dd  0000h                
              dw  00h,00h              
              dd  0000h
Time          db  12,00h,00h,00h       
              db  00h,00h,00h,00h      ; min,sec,frame,zero
              db  00h,00h,00h                  
info1         db  10,0,0,0,0,0,0        
info2         db  11,0,0,0,0,0,0       
PlayRequest   db  0,0,0                
              dw  00h                  ; status
              db  0,0,0,0,0,0,0,0      ; reserved
              db  00h                  
              dd  0000h,0000h          ; Strsect,Nsect
.end
