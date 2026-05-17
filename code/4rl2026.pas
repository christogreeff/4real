Program The_4ReAL_Demo;
{$G+,N+,E-,R-}
Uses Crt;

Type
  Screens    = Array [0..63999] Of Byte;
  ScrPtr     = ^Screens;
  Letters    = Record No : Array [43..90,1..64] Of Byte End;
  LetPtr     = ^Letters;
  SinCosTbl  = Array [0..1080] Of Real;
  SinCosPtr  = ^SinCosTbl;
  OrigPal    = Array[0..255,0..2] Of Byte;
  OrigPtr    = ^OrigPal;
Var
  CosTbl, SinTbl : SinCosPtr;
  Pal            : OrigPtr;
Procedure Line(X, Y, X2, Y2 : Word; Color : Byte; Wt : ScrPtr); Assembler;
Asm
  mov ax,word[wt+2]
  mov es,ax
  mov bx,x
  mov ax,y
  mov cx,x2
  mov si,y2
  cmp ax,si
  jbe @NO_SWAP
  xchg bx,cx
  xchg ax,si
@NO_SWAP:
  sub si,ax
  sub cx,bx
  cld
  jns @H_ABS
  neg cx
  std
@H_ABS:
  mov di,320
  mul di
  mov di,ax
  add di,bx
  or si,si
  jnz @NOT_H
  cld
  mov al,color
  inc cx
  rep stosb
  jmp @EXIT
@NOT_H:
  or cx,cx
  jnz @NOT_V
  cld
  mov al,color
  mov cx,si
  inc cx
  mov bx,320-1
@VLINE_LOOP:
  stosb
  add di,bx
  loop @VLINE_LOOP
  jmp @EXIT
@NOT_V:
  cmp cx,si
  lahf
  ja @H_IND
  xchg cx,si
@H_IND:
  mov dx,si
  sub dx,cx
  shl dx,1
  shl si,1
  mov bx,si
  sub bx,cx
  inc cx
  mov al,color
  sahf
  jb @DIAG_V
  or bx,bx
@LH:
  stosb
  jns @SH
  add bx,si
  loop @LH
  jmp @EXIT
@SH:
  add di,320
  add bx,dx
  loop @LH
  jmp @EXIT
@DIAG_V:
  or bx,bx
@LV:
  mov es:[di],al
  jns @SV
  add di,320
  add bx,si
  loop @LV
  jmp @EXIT
@SV:
  scasb
  add di,320
  add bx,dx
  loop @LV
@EXIT:
End;

Function GetPixel(X, Y : Word; Where : ScrPtr) : Byte; Assembler;
Asm
  mov es,word[Where+2]
  mov ax,y
  mov bx,x
  add bh,al
  shl ax,6
  add bx,ax
  mov al,es:[bx]
End;

Procedure Clear(Source : ScrPtr); Assembler;
Asm
  mov ax, word[Source+2]
  mov es, ax
  xor di, di
  xor ax, ax
  mov cx, 32000
  rep stosw
End;

Procedure FlipMask(Source, Dest : Pointer; Mask : Byte); Assembler;
Asm
  push ds
  lds si,source
  les di,dest
  mov cx,64000
  cld
@loop:
  lodsb
  cmp mask,al
  je @nodraw
  mov es:[di],al
@nodraw:
  inc di
  loop @loop
  pop ds
End;

Procedure Flip(Source, Dest : ScrPtr); Assembler;
Asm
   push ds
   mov ds,word[source+2]
   mov es,word[dest+2]
   xor si,si
   xor di,di
   mov cx,16000
   rep
   db $66
   movsw
   pop ds
End;

Procedure RotateProjection(Var X, Y, Z : Real; Xa, Ya, Za : Word;{rotation part}
{projection part}          Var Nx, Ny : Integer; Xm, Ym : Integer; ZCam : LongInt);
Var
  NewX, NewY, NewZ                        : Real;
  Distance, CosAngle, SinAngle, TempCoord : Real;
Begin
  CosAngle := CosTbl^[Za];                     { z-ax }
  SinAngle := SinTbl^[Za];
  NewX := X*CosAngle - Y*SinAngle;
  NewY := X*SinAngle + Y*CosAngle;
  CosAngle := CosTbl^[Xa];                     { x-ax }
  SinAngle := SinTbl^[Xa];
  NewZ := NewY*SinAngle + Z*CosAngle;
  Y :=    NewY*CosAngle - Z*SinAngle;
  CosAngle := CosTbl^[Ya];                     { y-ax }
  SinAngle := SinTbl^[Ya];
  X := NewX*CosAngle - NewZ*SinAngle;
  Z := NewX*SinAngle + NewZ*CosAngle;
  Distance := ZCam-Z;                          {projection part}
  If Distance = 0 Then
    Begin
      Nx := Round(Xm+X);
      Ny := Round(Ym+Y);
    End
  Else
    Begin
      Nx := Round(Xm+(X*256) / Distance);
      Ny := Round(Ym+(Y*256) / Distance);
    End;
End;

Procedure Retrace; Assembler;
Asm
  mov dx,3dah;
@vert1:
  in al,dx
  test al,8
  jz @vert1
@vert2:
  in al,dx
  test al,8
  jnz @vert2
End;

Procedure Palette(Col, R, G, B : Byte; Del : Integer; Ret : Boolean);
Begin
  Asm
    mov dx,3C8H
    mov al,[COL]
    out dx,al
    inc dx
    mov al,[R]
    out dx,al
    mov al,[G]
    out dx,al
    mov al,[B]
    out dx,al
  End;
  Delay(Del);
  If Ret Then Retrace;
End;

Procedure OldPal;
Var
  I : Integer;
Begin
  For I := 0 to 255 do Palette(I,Pal^[I,0],Pal^[I,1],Pal^[I,2],0,False);
End;

Procedure LoadFont(S : String; Var L : LetPtr);
Var
   F : File Of Letters;
Begin
   New(L);
   Assign(F,S);
   Reset(F);
   Read(F,L^);
   Close(F);
End;

Procedure WriteText(X, Y : Integer; S : String; Zoom, C : Byte; Wt : ScrPtr; L : LetPtr);
Var
   I, Cx2, Cy, Xp, Yp : Integer;
Begin
  For I := 1 to Length(S) do
    For Xp := 0 to 7 do
      For Yp := 0 to 7 do
        If L^.No[Ord(UpCase(S[I])),(Xp+1)+(Yp*8)] <> 0 Then
          Begin
            Cx2 := X+Zoom*(((I-1)*9)+Xp);
            Cy := Y+Zoom*Yp;
            If ((Cx2 >= 0) And (Cx2 <= 319) And
                (Cy >= 0) And (Cy <= 199) And
                (UpCase(S[I]) <> ' ')) Then
                  Asm
                    mov es,word[wt+2]
                    mov ax,cy
                    mov bx,cx2
                    add bh,al
                    shl ax,6
                    add bx,ax
                    mov al,c
                    mov es:[bx],al
                  End;
          End;
End;

Procedure Flash(L : LetPtr);
Var
  Teller, I    : Integer;
  Direct, Temp : ScrPtr;
  C, Y, T      : Word;
Begin
  New(Temp);
  Direct := Ptr($A000,$0000);
  Clear(Temp);
  Clear(Direct);
  I := 0;
  For Teller := 0 to 4 do
    Begin
      Palette(0,I,I,I,Random(5)*15,True);
      If I = 63 Then I := 0 else I := 63;
      WriteText(110,90,'4ReAL',2,Random(16)+15,Direct,L);
    End;
  Palette(0,63,63,63,0,True);
  WriteText(110,90,'4ReAL',2,31,Direct,L);
  For I := 63 downto 0 do
    Palette(0,I,I,I,3,True);
  C := 0;
  T := 0;
  Repeat
    Inc(T);
    If T = 360 Then T := 0;
    WriteText(110,90,'4ReAL',2,31,Temp,L);
    Retrace;
    Flip(Temp,Direct);
    Clear(Temp);
    Inc(C);
  Until C = 200;
  For I := 63 downto 0 do
    Begin
      Palette(31,I,I,I,3,True);
    End;
  Dispose(Temp);
  OldPal;
End;

Procedure TextBegin;
Var
  I : Byte;
Begin
  For I := 0 to 63 do Palette(0,I,I,I,0,True);
End;

Procedure Init(Var L : LetPtr);
Var
  A : Word;
Begin
  New(SinTbl);
  New(CosTbl);
  New(Pal);
  For A := 0 To 1080 Do
    Begin
      SinTbl^[A] := Sin(A*Pi/540);
      CosTbl^[A] := Cos(A*Pi/540);
    End;
  Asm
    mov ax,$13
    int 10h
  End;
  Retrace;
  For A := 0 to 255 do
    Begin
      Port[$3C7] := A;
      Pal^[A,0] := Port[$3C9];
      Pal^[A,1] := Port[$3C9];
      Pal^[A,2] := Port[$3C9];
    End;
  New(L);
  LoadFont('4real.FNT',L);
End;

Procedure TheEnd(L : LetPtr);
Begin
  Dispose(Pal);
  Dispose(SinTbl);
  Dispose(CosTbl);
  Dispose(L);
  Asm
    mov ax,$03
    int 10h
  End;
End;

Procedure Plasma;
Var
  Teller       : Integer;
  C, C2        : Byte;
  Temp, Direct : ScrPtr;
Begin
  New(Temp);
  Clear(Temp);
  Direct := Ptr($A000,$0000);
  Clear(Direct);
  For C := 0 to 255 do
    Palette(C,0,0,0,0,False);
  C := 0;
  C2 := 0;
  Teller := 0;
  Repeat
    C := C+15;
    C := C and $FF;
    If (C2 < 255) Then
      Begin
        Palette(C2,C2 shr 2,0,C2 shr 2,0,False);
        Inc(C2);
      End;
    Asm
      mov ax,0
      mov bx,0
      mov dx,integer[c]
    @nextpixel:
      push ax
      push bx
      push dx
      mov dl,al
      mov es,word[temp+2]
      add bh,al
      shl ax,6
      add bx,ax
      pop dx

      add dl,bl               { Calc The Colors }
      add dl,ah
      sub dl,bh
      mov al,dl

      mov es:[bx],al          { Write To Screen }
      pop bx
      pop ax
      add bx,2
      cmp bx,320
      je @nextline
      jmp @nextpixel
    @nextline:                { The Next Y Line }
      add dx,10
      mov bx,0
      add ax,2
      cmp ax,200
      je @end
      jmp @nextpixel
    @end:
    End;
    Retrace;
    Flip(Temp,Direct);
    Inc(Teller);
  Until Teller = 800;
  For C := 255 downto 0 do Palette(C,0,0,0,0,True);
  Dispose(Temp);
  Clear(Direct);
  OldPal;
  Retrace;
End;


Procedure Greets(L : LetPtr);
Const
  MaxS = 600;
  Greets : Array[1..6] Of String = ('Greetings To:','RawHed','Eclipse','Skuzzy','Alien Invader','John');
Type
  P = Array[1..530,1..3] Of Real;
  PPtr = ^P;
  Stars  = Array[1..MaxS,1..3] Of Real;
  StrPtr = ^Stars;
Var
  Pts : PPtr;
  PF : File Of P;
  Ss : StrPtr;
  Zp : Real;
  I, Xp, Yp, Ty, G : Integer;
  Col : Byte;
  Temp, Direct : ScrPtr;
  Xc, Yc, Zo : Integer;
  Xd, Yd : ShortInt;
Begin
  New(Pts);
  New(Temp);
  Direct := Ptr($A000,$0000);
  New(Ss);
  Assign(PF,'OBJ.3d');
  Reset(PF);
  Read(PF,Pts^);
  Close(PF);
  Xc := 0;
  Yc := -50;
  Xd := 1;
  Yd := 1;
  Zo := 1000;
  For I := 1 to MaxS Do
    Begin
      Ss^[I,1] := -160+Random(320);
      Ss^[I,2] := -100+Random(200);
      Ss^[I,3] := Random(500)+200;
    End;
  Ty := 200;
  G := 1;
  Repeat
    For I := 1 to MaxS Do
      Begin
        Ss^[I,3] := Ss^[I,3]-10;
        If (Ss^[I,3] <= 0) Then
          Begin
            Ss^[I,1] := -160+Random(320);
            Ss^[I,2] := -100+Random(200);
            Ss^[I,3] := Random(500)+200;
          End;
        Zp := 0;
        RotateProjection(Ss^[I,1],Ss^[I,2],Zp,0,0,3,Xp,Yp,160,100,Round(Ss^[I,3]));
        Col := 31-(Round((Ss^[I,3])/44));
        Asm
          mov ax,yp
          mov bx,xp

          cmp ax,0
          jl @ende
          cmp ax,199
          jg @ende
          cmp bx,0
          jl @ende
          cmp bx,319
          jg @ende

          mov es,word[temp+2]
          add bh,al
          shl ax,6
          add bx,ax
          mov al,col
          mov es:[bx],al
        @ende:
        End;
      End;
    Dec(Ty);
    If Ty < -13 Then
      Begin
        Ty := 200;
        Inc(G);
      End;
    WriteText(160-Length(Greets[G])*8,Ty,Greets[G],2,32,Temp,L);

    If Zo > 350 Then Dec(Zo);
    Inc(Xc,Xd);
    Inc(Yc,Yd);
    If Xc = 0   Then Xd := 1;
    If Xc = 319 Then Xd := -1;
    If Yc = 0   Then Yd := 1;
    If Yc = 199 Then Yd := -1;
    For I := 1 to 530 do
      Begin
        RotateProjection(Pts^[I,1],Pts^[I,2],Pts^[I,3],8,8,8,Xp,Yp,Xc,Yc,Zo);
        Col := 23+Round((Pts^[I,3] / 10));
        If Zo > 0 Then
        Asm
          mov ax,yp
          mov bx,xp

          cmp ax,0
          jl @ende
          cmp ax,199
          jg @ende
          cmp bx,0
          jl @ende
          cmp bx,319
          jg @ende

          mov es,word[temp+2]
          add bh,al
          shl ax,6
          add bx,ax
          mov al,col
          mov es:[bx],al
        @ende:
        End;
      End;
    Retrace;
    Flip(Temp,Direct);
    Clear(Temp);
  Until G = 7;
  Dispose(Ss);
  Dispose(Temp);
  Dispose(Pts);
  Clear(Direct);
  OldPal;
End;

Procedure PicStuff;
Type
  Img = Record
    Pic : Array[1..260,1..160] Of Byte;
    Pl  : Array[0..255,0..2] Of Byte;
  End;
  ImgPtr = ^Img;
  SinX = Array[0..24,30..289] Of Integer;
  SinY = Array[0..24,20..179] Of Integer;
  SxP  = ^SinX;
  SyP  = ^SinY;
Var
  Xp, Yp, SrcX, SrcY : Integer;
  I, I2, E, Teller : Byte;
  Xi, Yi : ShortInt;
  Sx : SxP;
  Sy : SyP;
  Mx, My : Integer;
  Pic : ImgPtr;
  PicF : File Of Img;
  Temp, Work, Direct : ScrPtr;

Procedure Aspect(Violent,Aspect : Real);
Var
  Xp, Yp, I : Integer;
Begin
  For I := 0 to 24 do
    Begin
      For Xp := 30 to 289 do                                 { internal proc }
        Sx^[I,Xp] := Round(Violent*Sin(I+Xp*Aspect));
      For Yp := 20 to 179 do
        Sy^[I,Yp] := Round(Violent*Sin(I+Yp*Aspect));
    End;
End;

Begin
  New(Work);
  New(Temp);
  Direct := Ptr($A000,$0000);
  Clear(Temp);
  Clear(Direct);
  Clear(Work);
  New(Pic);
  Assign(PicF,'Golf.4ri');
  Reset(PicF);
  Read(PicF,Pic^);
  Close(PicF);
  For I := 0 to 255 do Palette(I,Pic^.Pl[I,0],Pic^.Pl[I,1],Pic^.Pl[I,2],0,False);
  For Xp := 30 to 289 do
    For Yp := 20 to 179 do
      Work^[Xp+Yp*320] := Pic^.Pic[Xp-29,Yp-19];
  Mx := 0;
  My := 0;
  Xi := 3;
  Yi := 3;
  I := 0;
  I2 := 0;
  E := 0;
  Teller := 0;
  New(Sx);
  New(Sy);
  Aspect(0,0);
  Repeat
    Clear(Temp);
    Inc(I);
    If I = 25 Then I := 0;
    Inc(I2);
    If I2 = 100 Then
      Begin
        I2 := 0;
        Inc(Teller);
        For Xp := 0 to 255 do
          Palette(Xp,255,255,255,0,False);
        Case E Of
          0 : Aspect(2,1);
          1 : Aspect(4,0.03);
          2 : Aspect(2,0.2);
          3 : Aspect(3,6);
          4 : Aspect(10,0.05);
        End;
        For Xp := 0 to 255 do
          Palette(Xp,Pic^.Pl[Xp,0],Pic^.Pl[Xp,1],Pic^.Pl[Xp,2],0,False);
        Inc(E);
        If E = 5 Then E := 0;
      End;
    For Xp := 30 to 289 do
      For Yp := 20 to 179 do
        Begin
          SrcX := Xp - Sy^[I,Yp];
          SrcY := Yp - Sx^[I,Xp];
          If SrcX < 30  Then SrcX := 30;
          If SrcX > 289 Then SrcX := 289;
          If SrcY < 20  Then SrcY := 20;
          If SrcY > 179 Then SrcY := 179;
          Temp^[Xp+Yp*320] := Work^[SrcX+SrcY*320];
        End;
    Line(Mx,My,Mx+80,My,170,Temp);
    Line(Mx,My,Mx,My+60,170,Temp);
    Line(Mx,My+60,Mx+80,My+60,170,Temp);
    Line(Mx+80,My,Mx+80,My+60,170,Temp);
    For Xp := Mx+1 to Mx+79 do
      For Yp := My+1 to My+59 do
        Temp^[Xp+Yp*320] := Work^[Xp+Yp*320];
    Retrace;
    Flip(Temp,Direct);
    Inc(Mx,Xi); If Mx = 0 Then Xi := 3; If Mx+80 = 314 Then Xi := -3;
    Inc(My,Yi); If My = 0 Then Yi := 3; If My+60 = 195 Then Yi := -3;
  Until Teller = 11;
  Dispose(Pic);
  Dispose(Sx);
  Dispose(Sy);
  For Yp := 0 to 99 do
    Begin
      For Xp := 0 to 319 do
        Line(Xp,0,Xp,Yp*2,GetPixel(Xp,Yp*2,Direct),Temp);
      Retrace;
      Flip(Temp,Direct);
    End;
  Dispose(Work);
  Dispose(Temp);
  Clear(Direct);
  OldPal;
End;

Procedure Fire(L : LetPtr);
Const A : Array[1..12] Of String = ('THIS','DEMO','IS','ONLY','THE','SECOND','DEMO','EVER','WRITTEN','BY','4REAL','       ');
Var
  Temp, Direct : ScrPtr;
  Yc, Xp, Yp : Integer;
  Col : Byte;
  I, I2 : Integer;
  Aa : Boolean;
Begin
  Aa := False;
  New(Temp);
  Direct := Ptr($A000,$0000);
  Clear(Temp);
  Clear(Direct);
  For Xp := 0 to 255 do Palette(Xp,Xp*63 shr 8,Xp*22 shr 8,0,0,False);
  I := 1;
  I2 := 0;
  Repeat
    Inc(I2);
    If I2 = 30 Then Begin Inc(I); I2 := 0; End;
    If I = 13 Then
      Begin
        I := 1;
        Aa := True;
      End;
    WriteText(160-Length(A[I])*4,180,A[I],1,255-Random(105),Temp,L);
    For Xp := 0 to 159 do
      For Yp := 188 downto 90 do
        Begin
          Yc := (Yp+1)*320;
          Col := (Temp^[Xp*2+Yc-1]+Temp^[Xp*2+Yc]+Temp^[Xp*2+Yc+2]) div 3;
          If Col > 0 Then Dec(Col);
          Line(Xp*2,Yp,Xp*2+1,Yp,Col,Temp);
        End;
    WriteText(160-Length(A[I])*4,180,A[I],1,200+Random(55),Temp,L);
    Retrace;
    Flip(Temp,Direct);
  Until Aa;
  Dispose(Temp);
  Clear(Direct);
  OldPal;
End;
Var
  Letter : LetPtr;
Begin
  Randomize;
  TextBegin;
  Init(Letter);
  Flash(Letter);
  Plasma;
  Greets(Letter);
  PicStuff;
  Fire(Letter);
  TheEnd(Letter);
End.
