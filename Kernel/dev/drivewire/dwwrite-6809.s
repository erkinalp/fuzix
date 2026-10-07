;*****************************************************
;
; Copied from HDB-DOS from toolshed.sf.net
; The original code is public domain
;
; DWWrite
;    Send a packet to the DriveWire server.
;    Serial data format:  1-8-N-1
;    4/12/2009 by Darren Atkinson
;    28Jul2106 by Neal Crook for Multicomp UART
;
; Entry:
;    X  = starting address of data to send
;    Y  = number of bytes to send
;
; Exit:
;    X  = address of last byte sent + 1
;    Y  = 0
;    All others preserved
;

#ifdef MULTICOMP

;******************************************************
; 57600 (115200) bps using 6809 code and hw UART
;******************************************************

	.export DWWrite
DWWrite:  pshs      cc,a				; preserve registers
#ifndef NOINTMASK
          orcc      #IntMasks				; mask interrupts
#endif

WrBiz:    lda		UARTSTA2
          bita		#2
          beq		WrBiz				; busy

          lda		,x+				; get byte to transmit
          sta		UARTDAT2			; send byte

          leay		,-y				; decrement byte counter
          bne		WrBiz				; loop if more to send

          puls		cc,a,pc				; restore registers and return
#endif

#ifdef ARDUNIO

	.export DWWrite
DWWrite:  pshs      a                  ; preserve registers
txByte
          lda       ,x+                ; get byte from buffer
          sta       0xFF52              ; put it to PIA
loop_ar:  tst       0xFF53              ; check status register
          bpl       loop_ar            ; until CB1 is set by Arduino, continue looping
          tst       0xFF52              ; clear CB1 in status register
          leay      -1,y               ; decrement byte counter
          bne       txByte             ; loop if more to send

          puls      a,pc               ; restore registers and return

#endif

#ifdef JMCPBCK

	.export DWWrite
DWWrite:  pshs      d,cc              ; preserve registers
#ifndef NOINTMASK
          orcc      #IntMasks           ; mask interrupts
#endif
txByte:
          lda       ,x+
          sta       0xFF44
          leay      -1,y                ; decrement byte counter
          bne       txByte              ; loop if more to send

          puls      cc,d,pc           ; restore registers and return
#endif

#ifdef BECKER
	.export DWWrite
DWWrite:   pshs      d,cc              ; preserve registers
#ifndef NOINTMASK
          orcc      #IntMasks           ; mask interrupts
#endif
;          ldu       #BBOUT              ; point U to bit banger out register
;          lda       3,u                 ; read PIA 1-B control register
;          anda      #0xf7                ; clear sound enable bit
;          sta       3,u                 ; disable sound output
;          fcb       0x8c                 ; skip next instruction

txByte:
          lda       ,x+
          sta       BCKPORT
          leay      -1,y                ; decrement byte counter
          bne       txByte              ; loop if more to send

          puls      cc,d,pc           ; restore registers and return
#endif

#ifdef BAUD38400
;******************************************************
; 38400 bps using 6809 code and timimg
;******************************************************

	.export DWWrite
DWWrite:  pshs      u,d,cc              ; preserve registers
#ifndef NOINTMASK
          orcc      #IntMasks           ; mask interrupts
#endif
          ldu       #BBOUT              ; point U to bit banger out register
          lda       3,u                 ; read PIA 1-B control register
          anda      #0xf7                ; clear sound enable bit
          sta       3,u                 ; disable sound output
          fcb       0x8c                 ; skip next instruction

txByte:   stb       ,--u                ; send stop bit
          leau      ,u+
          lda       #8                  ; counter for start bit and 7 data bits
          ldb       ,x+                 ; get a byte to transmit
          lslb                          ; left rotate the byte two positions..
          rolb                          ; ..placing a zero (start bit) in bit 1
tx0010:   stb       ,u++                ; send bit
          tst       ,--u
          rorb                          ; move next bit into position
          deca                          ; decrement loop counter
          bne       tx0010              ; loop until 7th data bit has been sent
          leau      ,u
          stb       ,u                  ; send bit 7
          lda       ,u++
          ldb       #0x02                ; value for stop bit (MARK)
          leay      -1,y                ; decrement byte counter
          bne       txByte              ; loop if more to send

          stb       ,--u                ; leave bit banger output at MARK
          puls      cc,d,u,pc           ; restore registers and return
#endif

#ifdef H6309
;******************************************************
; 57600 (115200) bps using 6309 native mode
;******************************************************

	.export DWWrite
DWWrite:   pshs      u,d,cc              ; preserve registers
#ifndef NOINTMASK
          orcc      #IntMasks           ; mask interrupts
#endif
;         ldmd      #1                  ; requires 6309 native mode
          ldu       #BBOUT+1            ; point U to bit banger out register +1
          aim       #0xf7,2,u            ; disable sound output
          lda       #8                  ; counter for start bit and 7 data bits
          fcb       0x8c                 ; skip next instruction

txByte:   stb       -1,u                ; send stop bit
tx0010:   ldb       ,x+                 ; get a byte to transmit
          lslb                          ; left rotate the byte two positions..
          rolb                          ; ..placing a zero (start bit) in bit 1
          bra       tx0030

tx0020:   bita      #1                  ; even or odd bit number ?
          beq       tx0040              ; branch if even (15 cycles)
tx0030:   nop                           ; extra (16th) cycle
tx0040:   stb       -1,u                ; send bit
          rorb                          ; move next bit into position
          deca                          ; decrement loop counter
          bne       tx0020              ; loop until 7th data bit has been sent
          leau      ,u+
          stb       -1,u                ; send bit 7
          ldd       #0x0802              ; A = loop counter, B = MARK value
          leay      -1,y                ; decrement byte counter
          bne       txByte              ; loop if more to send

          stb       -1,u                ; final stop bit
          puls      cc,d,u,pc           ; restore registers and return

#endif

;******************************************************
; 57600 (115200) bps using 6809 code and timimg
;******************************************************

#ifdef BAUD57600

	.export DWWrite
DWWrite:   pshs      dp,d,cc             ; preserve registers
#ifndef NOINTMASK
          orcc      #IntMasks           ; mask interrupts
#endif
          ldd       #0x04ff             ; A = loop counter, B = $ff
          tfr       b,dp                ; set direct page to $FFxx
          ;setdp     0xff
          ldb       @0x23               ; read PIA 1-B control register
          andb      #0xf7               ; clear sound enable bit
          stb       @0x23               ; disable sound output
          fcb       0x8c                ; skip next instruction

txByte:   stb       @BBOUT              ; send stop bit
          ldb       ,x+                 ; get a byte to transmit
          nop
          lslb                          ; left rotate the byte two positions..
          rolb                          ; ..placing a zero (start bit) in bit 1
tx0020:   stb       @BBOUT              ; send bit (start bit, d1, d3, d5)
          rorb                          ; move next bit into position
          exg       a,a
          nop
          stb       @BBOUT              ; send bit (d0, d2, d4, d6)
          rorb                          ; move next bit into position
          leau      ,u
          deca                          ; decrement loop counter
          bne       tx0020              ; loop until 7th data bit has been sent

          stb       @BBOUT              ; send bit 7
          ldd       #0x0402             ; A = loop counter, B = MARK value
          leay      ,-y                 ; decrement byte counter
          bne       txByte              ; loop if more to send

          stb       @BBOUT              ; leave bit banger output at MARK
          puls      cc,d,dp,pc          ; restore registers and return

#endif
