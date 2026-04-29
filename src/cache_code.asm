; Stored inside GIFVIEW.EXE and copied to CACHE_RUNTIME_BASE.
; Runtime labels in this file are assembled for the cache/Win0 address space.

        DISP    CACHE_RUNTIME_BASE

GifCacheEntry:
        RET

CacheDecodeCurrentFrameToCanvas:
        CALL    LzwInitCodeReader
        CALL    BeginCanvasOutput
        CALL    CacheLzwResetDictionary
        CALL    CacheLzwReadFirstDataCode
        RET     C
        LD      (LzwOldCode),HL
        CALL    CacheLzwOutputCodeString
        CALL    CacheIsCanvasComplete
        RET     NZ
.loop:
        CALL    CacheLzwReadCode
        RET     C
        LD      DE,(LzwClearCode)
        CALL    CacheCompareHLDE
        JR      Z,.clear_code
        LD      DE,(LzwEndCode)
        CALL    CacheCompareHLDE
        RET     Z
        LD      (LzwInCode),HL
        LD      DE,(LzwNextCode)
        CALL    CacheCompareHLDE
        JR      C,.known_code
        JR      Z,.next_code
        JP      LzwInvalidStream
.known_code:
        CALL    CacheLzwOutputCodeString
        CALL    CacheIsCanvasComplete
        RET     NZ
        CALL    CacheLzwAddDictionaryEntry
        LD      HL,(LzwInCode)
        LD      (LzwOldCode),HL
        JR      .loop
.next_code:
        LD      HL,(LzwOldCode)
        CALL    CacheLzwOutputCodeString
        CALL    CacheIsCanvasComplete
        RET     NZ
        LD      A,(LzwFirstChar)
        CALL    CacheCanvasPutPixel
        JP      C,LzwCanvasOverflow
        CALL    CacheIsCanvasComplete
        RET     NZ
        CALL    CacheLzwAddDictionaryEntry
        LD      HL,(LzwInCode)
        LD      (LzwOldCode),HL
        JR      .loop
.clear_code:
        CALL    CacheLzwResetDictionary
        CALL    CacheLzwReadFirstDataCode
        RET     C
        LD      (LzwOldCode),HL
        CALL    CacheLzwOutputCodeString
        CALL    CacheIsCanvasComplete
        RET     NZ
        JR      .loop

CacheLzwResetDictionary:
        LD      HL,(LzwClearCode)
        LD      (LzwNextCode),HL
        LD      HL,(LzwNextCode)
        INC     HL
        INC     HL
        LD      (LzwNextCode),HL
        LD      A,(LzwMinCodeSize)
        INC     A
        LD      (LzwCodeSize),A
        CALL    CacheLzwSetCodeMask
        RET

CacheLzwReadFirstDataCode:
        CALL    CacheLzwReadCode
        RET     C
        LD      DE,(LzwClearCode)
        CALL    CacheCompareHLDE
        JR      Z,CacheLzwReadFirstDataCode
        LD      DE,(LzwEndCode)
        CALL    CacheCompareHLDE
        JR      Z,.end_code
        LD      DE,(LzwClearCode)
        CALL    CacheCompareHLDE
        JR      C,.valid_code
        JP      LzwInvalidStream
.valid_code:
        OR      A
        RET
.end_code:
        SCF
        RET

CacheLzwOutputCodeString:
        PUSH    HL
        CALL    CacheLzwResetStack
        POP     HL
        CALL    CacheLzwExpandCodeToStack
        LD      (LzwFirstChar),A
        CALL    CacheCanvasPutPixel
        JP      C,LzwCanvasOverflow
.pop_loop:
        CALL    CacheLzwPopStack
        RET     C
        CALL    CacheCanvasPutPixel
        JP      C,LzwCanvasOverflow
        JR      .pop_loop

CacheLzwExpandCodeToStack:
        LD      DE,(LzwClearCode)
        CALL    CacheCompareHLDE
        JR      C,.literal
        PUSH    HL
        CALL    CacheLzwGetSuffixPtr
        LD      A,(HL)
        CALL    CacheLzwPushStack
        POP     HL
        CALL    CacheLzwReadPrefix
        JR      CacheLzwExpandCodeToStack
.literal:
        LD      A,L
        RET

CacheLzwAddDictionaryEntry:
        LD      HL,(LzwNextCode)
        LD      DE,#1000
        CALL    CacheCompareHLDE
        RET     NC
        LD      HL,(LzwNextCode)
        CALL    CacheLzwGetPrefixPtr
        LD      DE,(LzwOldCode)
        LD      (HL),E
        INC     HL
        LD      (HL),D
        LD      HL,(LzwNextCode)
        CALL    CacheLzwGetSuffixPtr
        LD      A,(LzwFirstChar)
        LD      (HL),A
        LD      HL,(LzwNextCode)
        INC     HL
        LD      (LzwNextCode),HL
        LD      A,(LzwCodeSize)
        CP      #0C
        RET     NC
        CALL    CacheLzwPowerOfTwo
        LD      DE,(LzwNextCode)
        EX      DE,HL
        CALL    CacheCompareHLDE
        RET     NZ
        LD      A,(LzwCodeSize)
        INC     A
        LD      (LzwCodeSize),A
        CALL    CacheLzwSetCodeMask
        RET

CacheLzwReadPrefix:
        CALL    CacheLzwGetPrefixPtr
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        RET

CacheLzwGetPrefixPtr:
        ADD     HL,HL
        LD      DE,LZW_PREFIX_BASE
        ADD     HL,DE
        RET

CacheLzwGetSuffixPtr:
        LD      DE,LZW_SUFFIX_BASE
        ADD     HL,DE
        RET

CacheLzwResetStack:
        LD      HL,LZW_STACK_BASE
        LD      (LzwStackPtr),HL
        RET

CacheLzwPushStack:
        LD      (LzwStackByte),A
        LD      HL,(LzwStackPtr)
        LD      A,H
        CP      HIGH #8000
        JP      NC,LzwInvalidStream
        LD      A,(LzwStackByte)
        LD      (HL),A
        INC     HL
        LD      (LzwStackPtr),HL
        RET

CacheLzwPopStack:
        LD      HL,(LzwStackPtr)
        LD      DE,LZW_STACK_BASE
        CALL    CacheCompareHLDE
        JR      NZ,.has_data
        SCF
        RET
.has_data:
        DEC     HL
        LD      (LzwStackPtr),HL
        LD      A,(HL)
        OR      A
        RET

CacheLzwPowerOfTwo:
        LD      B,A
        LD      HL,#0001
.loop:
        LD      A,B
        OR      A
        RET     Z
        ADD     HL,HL
        DJNZ    .loop
        RET

CacheLzwSetCodeMask:
        CALL    CacheLzwPowerOfTwo
        DEC     HL
        LD      (LzwCodeMask),HL
        RET

CacheIsCanvasComplete:
        LD      A,(CanvasOutputDoneFlag)
        OR      A
        RET

CacheCompareHLDE:
        PUSH    HL
        OR      A
        SBC     HL,DE
        POP     HL
        RET

CacheLzwReadCodeFast:
        LD      A,(LzwCodeSize)
        LD      C,A
.fill_loop:
        LD      A,(LzwBitCount)
        CP      C
        JR      NC,.have_bits
        CALL    CacheFrameStreamGetByte
        RET     C
        CALL    CacheLzwAppendByteToBitBuffer
        LD      HL,LzwBitCount
        LD      A,(HL)
        ADD     A,#08
        LD      (HL),A
        JR      .fill_loop
.have_bits:
        LD      HL,(LzwBitBuffer)
        LD      DE,(LzwCodeMask)
        LD      A,H
        AND     D
        LD      H,A
        LD      A,L
        AND     E
        LD      L,A
        LD      B,C
.shift_loop:
        LD      A,B
        OR      A
        JR      Z,.shift_done
        PUSH    HL
        LD      HL,LzwBitBufferHigh
        SRL     (HL)
        DEC     HL
        RR      (HL)
        DEC     HL
        RR      (HL)
        POP     HL
        DJNZ    .shift_loop
.shift_done:
        LD      A,(LzwBitCount)
        SUB     C
        LD      (LzwBitCount),A
        OR      A
        RET

CacheLzwAppendByteToBitBuffer:
        LD      HL,LzwShiftBuffer
        LD      (HL),A
        INC     HL
        LD      (HL),#00
        INC     HL
        LD      (HL),#00
        LD      A,(LzwBitCount)
        LD      B,A
.shift_new_byte:
        LD      A,B
        OR      A
        JR      Z,.merge
        LD      HL,LzwShiftBuffer
        SLA     (HL)
        INC     HL
        RL      (HL)
        INC     HL
        RL      (HL)
        DJNZ    .shift_new_byte
.merge:
        LD      HL,LzwShiftBuffer
        LD      DE,LzwBitBuffer
        LD      A,(DE)
        OR      (HL)
        LD      (DE),A
        INC     HL
        INC     DE
        LD      A,(DE)
        OR      (HL)
        LD      (DE),A
        INC     HL
        LD      DE,LzwBitBufferHigh
        LD      A,(DE)
        OR      (HL)
        LD      (DE),A
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
        CALL    CacheFrameStreamGetByte
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

CacheFrameStreamGetByte:
        LD      A,(FrameStreamDoneFlag)
        OR      A
        JR      Z,.not_done
        SCF
        RET
.not_done:
        LD      A,(FrameStreamSubBlockRemaining)
        OR      A
        JR      NZ,.read_data
        CALL    CacheFrameStreamRawGetByte
        JR      C,.done
        OR      A
        JR      Z,.done
        LD      (FrameStreamSubBlockRemaining),A
.read_data:
        CALL    CacheFrameStreamRawGetByte
        RET     C
        LD      (FrameStreamByte),A
        LD      HL,FrameStreamSubBlockRemaining
        DEC     (HL)
        LD      A,(FrameStreamByte)
        OR      A
        RET
.done:
        LD      A,#01
        LD      (FrameStreamDoneFlag),A
        SCF
        RET

CacheFrameStreamRawGetByte:
        PUSH    HL
        CALL    CacheFrameStreamMapCurrentPage
        LD      HL,(FrameStreamPtr)
        LD      A,(HL)
        LD      (FrameStreamByte),A
        INC     HL
        LD      A,H
        OR      A
        JR      NZ,.store_ptr
        LD      HL,LOAD_WINDOW
        LD      (FrameStreamPtr),HL
        CALL    CacheFrameStreamMapNextPage
        JR      .done
.store_ptr:
        LD      (FrameStreamPtr),HL
.done:
        POP     HL
        LD      A,(FrameStreamByte)
        OR      A
        RET

CacheFrameStreamMapCurrentPage:
        LD      A,(Page3Owner)
        CP      #01
        JR      NZ,.map_page
        LD      A,(Page3MappedPage)
        LD      B,A
        LD      A,(FrameStreamPage)
        CP      B
        RET     Z
.map_page:
        LD      A,(FrameStreamPage)
        LD      HL,GifPageTable
        CALL    CacheMapPageTableIndexToPage3
        LD      A,#01
        LD      (Page3Owner),A
        LD      A,(FrameStreamPage)
        LD      (Page3MappedPage),A
        RET

CacheFrameStreamMapNextPage:
        LD      A,(FrameStreamPage)
        INC     A
        LD      (FrameStreamPage),A
        LD      C,A
        LD      A,(PagesNeeded)
        CP      C
        JP      C,CacheInvalidGifBlock
        JP      Z,CacheInvalidGifBlock
        JP      CacheFrameStreamMapCurrentPage

CacheMapPageTableIndexToPage3:
        PUSH    DE
        LD      E,A
        LD      D,#00
        ADD     HL,DE
        LD      A,(HL)
        OUT     (PAGE3),A
        POP     DE
        OR      A
        RET

CacheInvalidGifBlock:
        CALL    RestoreSystemWindow
        JP      InvalidGifBlock

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
