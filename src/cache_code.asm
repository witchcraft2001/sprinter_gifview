; Stored inside GIFVIEW.EXE and copied to CACHE_RUNTIME_BASE.
; Runtime labels in this file are assembled for the cache/Win0 address space.

        DISP    CACHE_RUNTIME_BASE

GifCacheEntry:
        RET

CacheLzwReadCode:
        LD      HL,#0000
        LD      DE,#0001
        LD      A,(LzwCodeSize)
        LD      B,A
.loop:
        CALL    CacheLzwReadBit
        JR      C,.end_of_stream
        OR      A
        JR      Z,.next_bit
        ADD     HL,DE
.next_bit:
        SLA     E
        RL      D
        DJNZ    .loop
        OR      A
        RET
.end_of_stream:
        SCF
        RET

CacheLzwReadBit:
        PUSH    HL
        PUSH    BC
        PUSH    DE
        LD      A,(LzwBitsRemaining)
        OR      A
        JR      NZ,.have_bits
        CALL    FrameStreamGetByte
        JR      C,.end_of_stream
        LD      (LzwCurrentByte),A
        LD      A,#08
        LD      (LzwBitsRemaining),A
.have_bits:
        LD      A,(LzwCurrentByte)
        SRL     A
        LD      (LzwCurrentByte),A
        LD      A,(LzwBitsRemaining)
        DEC     A
        LD      (LzwBitsRemaining),A
        LD      A,#00
        ADC     A,#00
        LD      (LzwReadBitValue),A
        POP     DE
        POP     BC
        POP     HL
        LD      A,(LzwReadBitValue)
        OR      A
        RET
.end_of_stream:
        POP     DE
        POP     BC
        POP     HL
        SCF
        RET

CacheCanvasPutPixel:
        LD      (CanvasOutputByte),A
        LD      A,(CanvasOutputDoneFlag)
        OR      A
        JR      Z,.not_done
        OR      A
        RET
.not_done:
        LD      A,(CanvasTransparentFlag)
        OR      A
        JR      Z,.write_pixel
        LD      A,(CanvasOutputByte)
        LD      HL,CanvasTransparentIndex
        CP      (HL)
        JR      Z,.advance_pixel
.write_pixel:
        CALL    CacheMapCanvasOutputPage
        LD      HL,(CanvasOutputPtr)
        LD      A,(CanvasOutputByte)
        LD      (HL),A
.advance_pixel:
        CALL    CacheCanvasAdvancePixel
        RET     C
        LD      A,(CanvasOutputByte)
        OR      A
        RET

CacheCanvasAdvancePixel:
        LD      DE,#0001
        CALL    CacheCanvasAdvanceOutputPtrByDE
        RET     C
        LD      HL,(CanvasFrameXRemaining)
        DEC     HL
        LD      (CanvasFrameXRemaining),HL
        LD      A,H
        OR      L
        RET     NZ
        LD      HL,(CanvasRowsRemaining)
        DEC     HL
        LD      (CanvasRowsRemaining),HL
        LD      A,H
        OR      L
        JR      NZ,.next_row
        LD      A,#01
        LD      (CanvasOutputDoneFlag),A
        OR      A
        RET
.next_row:
        LD      A,(CanvasInterlaceFlag)
        OR      A
        JP      NZ,CacheCanvasAdvanceInterlacedRow
        LD      A,(CanvasRowStartPage)
        LD      (CanvasOutputPage),A
        LD      HL,(CanvasRowStartPtr)
        LD      (CanvasOutputPtr),HL
        LD      DE,GIF_MAX_WIDTH
        CALL    CacheCanvasAdvanceOutputPtrByDE
        RET     C
        LD      A,(CanvasOutputPage)
        LD      (CanvasRowStartPage),A
        LD      HL,(CanvasOutputPtr)
        LD      (CanvasRowStartPtr),HL
        LD      HL,(CanvasFrameWidth)
        LD      (CanvasFrameXRemaining),HL
        OR      A
        RET

CacheCanvasAdvanceInterlacedRow:
        CALL    CacheCanvasNextInterlacedRow
        LD      HL,(CanvasCurrentRow)
        LD      DE,(CanvasFrameTop)
        ADD     HL,DE
        LD      (CanvasSeekTop),HL
        XOR     A
        LD      (CanvasOutputPage),A
        LD      HL,CANVAS_WINDOW
        LD      (CanvasOutputPtr),HL
        LD      HL,(CanvasSeekTop)
        LD      (CanvasFrameTop),HL
        CALL    CanvasSeekFrameStart
        LD      HL,(CanvasSeekTop)
        LD      DE,(CanvasCurrentRow)
        OR      A
        SBC     HL,DE
        LD      (CanvasFrameTop),HL
        LD      HL,(CanvasFrameWidth)
        LD      (CanvasFrameXRemaining),HL
        OR      A
        RET

CacheCanvasNextInterlacedRow:
        LD      A,(CanvasInterlacePass)
        CP      #01
        JR      Z,.pass1
        CP      #02
        JR      Z,.pass2
        CP      #03
        JR      Z,.pass3
.pass0:
        LD      DE,#0008
        CALL    CacheCanvasTryInterlaceStep
        RET     C
        LD      A,#01
        LD      (CanvasInterlacePass),A
        LD      HL,#0004
        JR      .test_row
.pass1:
        LD      DE,#0008
        CALL    CacheCanvasTryInterlaceStep
        RET     C
        LD      A,#02
        LD      (CanvasInterlacePass),A
        LD      HL,#0002
        JR      .test_row
.pass2:
        LD      DE,#0004
        CALL    CacheCanvasTryInterlaceStep
        RET     C
        LD      A,#03
        LD      (CanvasInterlacePass),A
        LD      HL,#0001
        JR      .test_row
.pass3:
        LD      DE,#0002
        CALL    CacheCanvasTryInterlaceStep
        RET
.test_row:
        CALL    CacheCanvasStoreInterlaceRowIfValid
        RET     C
        JR      CacheCanvasNextInterlacedRow

CacheCanvasTryInterlaceStep:
        LD      HL,(CanvasCurrentRow)
        ADD     HL,DE

CacheCanvasStoreInterlaceRowIfValid:
        LD      DE,(CanvasFrameHeight)
        CALL    CompareHLDE
        RET     NC
        LD      (CanvasCurrentRow),HL
        SCF
        RET

CacheCanvasAdvanceOutputPtrByDE:
        LD      HL,(CanvasOutputPtr)
        ADD     HL,DE
        JR      NC,.store_ptr
        PUSH    HL
        LD      A,(CanvasOutputPage)
        INC     A
        LD      (CanvasOutputPage),A
        CP      CANVAS_MEMORY_PAGES
        JR      C,.next_page
        POP     HL
        LD      A,#01
        LD      (CanvasOutputDoneFlag),A
        SCF
        RET
.next_page:
        POP     HL
        LD      DE,LOAD_WINDOW
        ADD     HL,DE
.store_ptr:
        LD      (CanvasOutputPtr),HL
        OR      A
        RET

CacheMapCanvasOutputPage:
        LD      A,(Page3Owner)
        CP      #02
        JR      NZ,.map_page
        LD      A,(Page3MappedPage)
        LD      B,A
        LD      A,(CanvasOutputPage)
        CP      B
        RET     Z
.map_page:
        LD      A,(CanvasOutputPage)
        CALL    MapCanvasPageIndexToPage3
        LD      A,#02
        LD      (Page3Owner),A
        LD      A,(CanvasOutputPage)
        LD      (Page3MappedPage),A
        RET

CacheBlitDirtyCanvasRowToVideo:
        LD      HL,WORK_WINDOW
        LD      DE,(BlitRectLeft)
        ADD     HL,DE
        EX      DE,HL
        LD      BC,(BlitRectWidth)
        LD      HL,(BlitSourcePtr)
        PUSH    HL
        ADD     HL,BC
        POP     HL
        JR      C,.byte_loop
        LD      A,B
        OR      A
        JR      NZ,.ldir_copy
        LD      A,C
        DI
        LD      D,D
        LD      (DE),A
        LD      B,B
        LD      L,L
        LD      A,(HL)
        LD      (DE),A
        LD      B,B
        LD      BC,(BlitRectWidth)
        ADD     HL,BC
        LD      (BlitSourcePtr),HL
        RET
.ldir_copy:
        LDIR
        LD      (BlitSourcePtr),HL
        RET
.byte_loop:
        LD      HL,(BlitSourcePtr)
        LD      A,(HL)
        LD      (DE),A
        INC     HL
        LD      A,H
        OR      A
        JR      NZ,.source_ok
        LD      HL,LOAD_WINDOW
        LD      (BlitSourcePtr),HL
        PUSH    BC
        PUSH    DE
        CALL    AdvanceBlitCanvasPage
        POP     DE
        POP     BC
        JR      .dest_next
.source_ok:
        LD      (BlitSourcePtr),HL
.dest_next:
        INC     DE
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,.byte_loop
        RET

        ENT
