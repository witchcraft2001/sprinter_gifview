; Stored inside GIFVIEW.EXE and copied to CACHE_RUNTIME_BASE.
; Runtime labels in this file are assembled for the cache/Win0 address space.

        DISP    CACHE_RUNTIME_BASE

GifCacheEntry:
        RET

CacheDecodeCurrentFrameToCanvas:
        CALL    CacheLzwInitCodeReader
        CALL    CacheBeginCanvasOutput
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
        LD      A,H
        CP      D
        JR      NZ,.not_clear_code
        LD      A,L
        CP      E
        JR      Z,.clear_code
.not_clear_code:
        LD      DE,(LzwEndCode)
        LD      A,H
        CP      D
        JR      NZ,.not_end_code
        LD      A,L
        CP      E
        RET     Z
.not_end_code:
        LD      (LzwInCode),HL
        LD      DE,(LzwNextCode)
        LD      A,H
        CP      D
        JR      NZ,.next_code_compared
        LD      A,L
        CP      E
.next_code_compared:
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
        CALL    CacheCanvasPutPixelTransparent
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

CacheLzwInitCodeReader:
        CALL    CacheMapLzwWorkspace
        CALL    CacheBeginFrameDataStream
        CALL    CacheGetCurrentFrameEntryPtr
        LD      DE,15
        ADD     HL,DE
        LD      A,(HL)
        CP      #02
        JP      C,CacheLzwUnsupportedCodeSize
        CP      #09
        JP      NC,CacheLzwUnsupportedCodeSize
        LD      (LzwMinCodeSize),A
        INC     A
        LD      (LzwCodeSize),A
        XOR     A
        LD      (LzwCurrentByte),A
        LD      (LzwBitsRemaining),A
        LD      (LzwBitCount),A
        LD      (LzwBitBuffer),A
        LD      (LzwBitBuffer + 1),A
        LD      (LzwBitBufferHigh),A
        LD      A,(LzwMinCodeSize)
        CALL    CacheLzwPowerOfTwo
        LD      (LzwClearCode),HL
        INC     HL
        LD      (LzwEndCode),HL
        INC     HL
        LD      (LzwNextCode),HL
        RET

CacheMapLzwWorkspace:
        IN      A,(PAGE1)
        LD      (SavedPage1),A
        XOR     A
        LD      HL,LzwPageTable
        JP      CacheMapPageTableIndexToPage1

CacheBeginFrameDataStream:
        IN      A,(PAGE3)
        LD      (SavedPage3),A
        CALL    CacheGetCurrentFrameEntryPtr
        LD      A,(HL)
        LD      (FrameStreamPage),A
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      (FrameStreamPtr),DE
        XOR     A
        LD      (FrameStreamSubBlockRemaining),A
        LD      (FrameStreamDoneFlag),A
        CALL    CacheFrameStreamMapCurrentPage
        RET

CacheLzwUnsupportedCodeSize:
        CALL    RestoreSystemWindow
        JP      LzwUnsupportedCodeSize

CacheLzwReadFirstDataCode:
        CALL    CacheLzwReadCode
        RET     C
        LD      DE,(LzwClearCode)
        LD      A,H
        CP      D
        JR      NZ,.not_clear_code
        LD      A,L
        CP      E
        JR      Z,CacheLzwReadFirstDataCode
.not_clear_code:
        LD      DE,(LzwEndCode)
        LD      A,H
        CP      D
        JR      NZ,.not_end_code
        LD      A,L
        CP      E
        JR      Z,.end_code
.not_end_code:
        LD      DE,(LzwClearCode)
        LD      A,H
        CP      D
        JR      NZ,.clear_code_compared
        LD      A,L
        CP      E
.clear_code_compared:
        JR      C,.valid_code
        JP      LzwInvalidStream
.valid_code:
        OR      A
        RET
.end_code:
        SCF
        RET

CacheLzwOutputCodeString:
        LD      IX,LZW_STACK_BASE
        CALL    CacheLzwExpandCodeToStack
        LD      (LzwFirstChar),A
        CALL    CacheCanvasPutPixelTransparent
        JP      C,LzwCanvasOverflow
.pop_loop:
        LD      A,IXH
        CP      HIGH LZW_STACK_BASE
        JR      NZ,.has_stack_data
        LD      A,IXL
        CP      LOW LZW_STACK_BASE
        RET     Z
.has_stack_data:
        DEC     IX
        LD      A,(IX + 0)
        CALL    CacheCanvasPutPixelTransparent
        JP      C,LzwCanvasOverflow
        JR      .pop_loop

CacheLzwExpandCodeToStack:
        LD      DE,(LzwClearCode)
        LD      A,H
        CP      D
        JR      NZ,.clear_code_compared
        LD      A,L
        CP      E
.clear_code_compared:
        JR      C,.literal
        PUSH    HL
        LD      DE,LZW_SUFFIX_BASE
        ADD     HL,DE
        LD      A,(HL)
        LD      C,A
        LD      A,IXH
        CP      HIGH #8000
        JP      NC,LzwInvalidStream
        LD      (IX + 0),C
        INC     IX
        POP     HL
        ADD     HL,HL
        LD      DE,LZW_PREFIX_BASE
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        JR      CacheLzwExpandCodeToStack
.literal:
        LD      A,L
        RET

CacheLzwAddDictionaryEntry:
        LD      HL,(LzwNextCode)
        LD      A,H
        CP      #10
        RET     NC
        LD      HL,(LzwNextCode)
        ADD     HL,HL
        LD      DE,LZW_PREFIX_BASE
        ADD     HL,DE
        LD      DE,(LzwOldCode)
        LD      (HL),E
        INC     HL
        LD      (HL),D
        LD      HL,(LzwNextCode)
        LD      DE,LZW_SUFFIX_BASE
        ADD     HL,DE
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
        LD      A,D
        CP      H
        RET     NZ
        LD      A,E
        CP      L
        RET     NZ
        LD      A,(LzwCodeSize)
        INC     A
        LD      (LzwCodeSize),A
        CALL    CacheLzwSetCodeMask
        RET

CacheLzwPowerOfTwo:
        ADD     A,A
        LD      E,A
        LD      D,#00
        LD      HL,CacheLzwPowerOfTwoTable
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        RET

CacheLzwPowerOfTwoTable:
        DW      #0001,#0002,#0004,#0008
        DW      #0010,#0020,#0040,#0080
        DW      #0100,#0200,#0400,#0800
        DW      #1000

CacheLzwSetCodeMask:
        ADD     A,A
        LD      E,A
        LD      D,#00
        LD      HL,CacheLzwCodeMaskTable
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        LD      (LzwCodeMask),HL
        RET

CacheLzwCodeMaskTable:
        DW      #0000,#0001,#0003,#0007
        DW      #000F,#001F,#003F,#007F
        DW      #00FF,#01FF,#03FF,#07FF
        DW      #0FFF

CacheIsCanvasComplete:
        LD      A,(CanvasOutputDoneFlag)
        OR      A
        RET

CacheBeginCanvasOutput:
        XOR     A
        LD      (CanvasOutputPage),A
        LD      (CanvasOutputDoneFlag),A
        LD      HL,CANVAS_WINDOW
        LD      (CanvasOutputPtr),HL
        CALL    CacheGetCurrentFrameEntryPtr
        LD      DE,6
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      (CanvasFrameLeft),DE
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      (CanvasFrameTop),DE
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      (CanvasFrameWidth),DE
        LD      (CanvasFrameXRemaining),DE
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      (CanvasFrameHeight),DE
        LD      (CanvasRowsRemaining),DE
        INC     HL
        LD      A,(HL)
        AND     #40
        LD      (CanvasInterlaceFlag),A
        XOR     A
        LD      (CanvasCurrentRow),A
        LD      (CanvasCurrentRow + 1),A
        LD      (CanvasInterlacePass),A
        INC     HL
        INC     HL
        LD      A,(HL)
        AND     #01
        LD      (CanvasTransparentFlag),A
        INC     HL
        LD      A,(HL)
        LD      (CanvasTransparentIndex),A
        CALL    CacheSelectCanvasPutPixel
        CALL    CacheCanvasSeekFrameStart
        JP      CacheMapCanvasOutputPage

CacheSelectCanvasPutPixel:
        LD      DE,CacheCanvasPutPixelOpaque
        LD      A,(CanvasTransparentFlag)
        OR      A
        JR      Z,.patch_calls
        LD      DE,CacheCanvasPutPixelTransparent
.patch_calls:
        LD      HL,CacheDecodeCurrentFrameToCanvas.next_code + 14
        LD      (HL),E
        INC     HL
        LD      (HL),D
        LD      HL,CacheLzwOutputCodeString + 11
        LD      (HL),E
        INC     HL
        LD      (HL),D
        LD      HL,CacheLzwOutputCodeString.pop_loop + 17
        LD      (HL),E
        INC     HL
        LD      (HL),D
        RET

CacheGetCurrentFrameEntryPtr:
        LD      HL,(CurrentPlaybackFrame)
        LD      DE,(FrameIndexCount)
        OR      A
        SBC     HL,DE
        JP      NC,CacheFrameIndexOutOfRange
        LD      A,(CurrentPlaybackFrame + 1)
        OR      A
        JP      NZ,CacheFrameIndexOutOfRange
        LD      A,(CurrentPlaybackFrame)
        LD      L,A
        LD      H,#00
        ADD     HL,HL
        ADD     HL,HL
        LD      D,H
        LD      E,L
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,DE
        LD      DE,FrameIndexTable
        ADD     HL,DE
        RET

CacheFrameIndexOutOfRange:
        CALL    RestoreSystemWindow
        JP      FrameIndexOutOfRange

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

CacheMapCanvasPageIndexToPage3:
        LD      HL,CanvasPageTable
        JP      CacheMapPageTableIndexToPage3

CacheMapPageTableIndexToPage1:
        PUSH    DE
        LD      E,A
        LD      D,#00
        ADD     HL,DE
        LD      A,(HL)
        OUT     (PAGE1),A
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

CacheCanvasPutPixelTransparent:
        LD      (CanvasOutputByte),A
        LD      A,(CanvasOutputDoneFlag)
        OR      A
        JR      Z,.not_done
        OR      A
        RET
.not_done:
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

CacheCanvasPutPixelOpaque:
        LD      (CanvasOutputByte),A
        LD      A,(CanvasOutputDoneFlag)
        OR      A
        JR      Z,.not_done
        OR      A
        RET
.not_done:
        CALL    CacheMapCanvasOutputPage
        LD      HL,(CanvasOutputPtr)
        LD      A,(CanvasOutputByte)
        LD      (HL),A
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
        CALL    CacheCanvasSeekFrameStart
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
        CALL    CacheCompareHLDE
        RET     NC
        LD      (CanvasCurrentRow),HL
        SCF
        RET

CacheCanvasSeekFrameStart:
        LD      HL,(CanvasFrameTop)
        LD      A,H
        OR      L
        JR      Z,.left_offset
.row_loop:
        PUSH    HL
        LD      DE,GIF_MAX_WIDTH
        CALL    CacheCanvasAdvanceOutputPtrByDE
        POP     HL
        RET     C
        DEC     HL
        LD      A,H
        OR      L
        JR      NZ,.row_loop
.left_offset:
        LD      DE,(CanvasFrameLeft)
        CALL    CacheCanvasAdvanceOutputPtrByDE
        RET     C
        LD      A,(CanvasOutputPage)
        LD      (CanvasRowStartPage),A
        LD      HL,(CanvasOutputPtr)
        LD      (CanvasRowStartPtr),HL
        OR      A
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
        CALL    CacheMapCanvasPageIndexToPage3
        LD      A,#02
        LD      (Page3Owner),A
        LD      A,(CanvasOutputPage)
        LD      (Page3MappedPage),A
        RET

CacheMapPrevCanvasOutputPage:
        LD      A,(PrevOutputPage)
        LD      HL,PrevCanvasPageTable
        JP      CacheMapPageTableIndexToPage1

CacheMarkCurrentFrameDirty:
        CALL    CacheGetCurrentFrameEntryPtr
        LD      DE,6
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      (DirtyInputLeft),DE
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      (DirtyInputTop),DE
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        PUSH    HL
        LD      HL,(DirtyInputLeft)
        ADD     HL,DE
        LD      (DirtyInputRight),HL
        POP     HL
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      HL,(DirtyInputTop)
        ADD     HL,DE
        LD      (DirtyInputBottom),HL
        JP      CacheMarkDirtyRectFromInput

CacheMarkDirtyRectFromInput:
        LD      A,(DirtyFlag)
        OR      A
        JR      NZ,.merge
        LD      A,#01
        LD      (DirtyFlag),A
        LD      HL,(DirtyInputLeft)
        LD      (DirtyLeft),HL
        LD      HL,(DirtyInputTop)
        LD      (DirtyTop),HL
        LD      HL,(DirtyInputRight)
        LD      (DirtyRight),HL
        LD      HL,(DirtyInputBottom)
        LD      (DirtyBottom),HL
        RET
.merge:
        LD      HL,(DirtyInputLeft)
        LD      DE,(DirtyLeft)
        CALL    CacheCompareHLDE
        JR      NC,.top
        LD      (DirtyLeft),HL
.top:
        LD      HL,(DirtyInputTop)
        LD      DE,(DirtyTop)
        CALL    CacheCompareHLDE
        JR      NC,.right
        LD      (DirtyTop),HL
.right:
        LD      HL,(DirtyRight)
        LD      DE,(DirtyInputRight)
        CALL    CacheCompareHLDE
        JR      NC,.bottom
        LD      HL,(DirtyInputRight)
        LD      (DirtyRight),HL
.bottom:
        LD      HL,(DirtyBottom)
        LD      DE,(DirtyInputBottom)
        CALL    CacheCompareHLDE
        RET     NC
        LD      HL,(DirtyInputBottom)
        LD      (DirtyBottom),HL
        RET

CacheApplyCurrentFrameDisposal:
        CALL    CacheGetCurrentFrameEntryPtr
        LD      DE,16
        ADD     HL,DE
        LD      A,(HL)
        AND     #1C
        CP      #08
        JP      Z,CacheClearCurrentFrameRectToBackground
        CP      #0C
        RET     NZ
        JP      CacheRestoreCurrentFrameBackupForDisposal3

CacheSaveCurrentFrameBackupForDisposal3:
        LD      A,(PrevCanvasMemoryAllocatedFlag)
        OR      A
        RET     Z
        CALL    CacheGetCurrentFrameEntryPtr
        LD      DE,16
        ADD     HL,DE
        LD      A,(HL)
        AND     #1C
        CP      #0C
        RET     NZ
        CALL    CachePrepareCurrentFrameRectCopy
        RET     Z
        IN      A,(PAGE1)
        LD      (PrevSavedPage1),A
        CALL    CacheCopyCanvasRectToPrev
        LD      A,(PrevSavedPage1)
        OUT     (PAGE1),A
        RET

CacheRestoreCurrentFrameBackupForDisposal3:
        LD      A,(PrevCanvasMemoryAllocatedFlag)
        OR      A
        RET     Z
        CALL    CachePrepareCurrentFrameRectCopy
        RET     Z
        IN      A,(PAGE1)
        LD      (PrevSavedPage1),A
        CALL    CacheCopyPrevRectToCanvas
        LD      A,(PrevSavedPage1)
        OUT     (PAGE1),A
        JP      CacheMarkCurrentFrameDirty

CachePrepareCurrentFrameRectCopy:
        XOR     A
        LD      (CanvasOutputPage),A
        LD      (CanvasOutputDoneFlag),A
        LD      (CanvasTransparentFlag),A
        LD      HL,CANVAS_WINDOW
        LD      (CanvasOutputPtr),HL
        CALL    CacheGetCurrentFrameEntryPtr
        LD      DE,6
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      (CanvasFrameLeft),DE
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      (CanvasFrameTop),DE
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      (CanvasFrameWidth),DE
        LD      A,D
        OR      E
        RET     Z
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      (BlitRectRows),DE
        LD      A,D
        OR      E
        RET     Z
        CALL    CacheCanvasSeekFrameStart
        RET     C
        LD      A,(CanvasOutputPage)
        LD      (PrevOutputPage),A
        LD      HL,(CanvasOutputPtr)
        LD      A,H
        SUB     HIGH (LOAD_WINDOW - WORK_WINDOW)
        LD      H,A
        LD      (PrevOutputPtr),HL
        LD      HL,GIF_MAX_WIDTH
        LD      DE,(CanvasFrameWidth)
        OR      A
        SBC     HL,DE
        LD      (BlitRowSkip),HL
        LD      A,#01
        OR      A
        RET

CacheCopyCanvasRectToPrev:
        XOR     A
        LD      (CacheCopyDirection),A
        JP      CacheCopyCanvasPrevRows

CacheCopyPrevRectToCanvas:
        LD      A,#01
        LD      (CacheCopyDirection),A
        JP      CacheCopyCanvasPrevRows

CacheCopyCanvasPrevRows:
.row_loop:
        LD      HL,(CanvasFrameWidth)
        LD      (FillRectRemaining),HL
.segment_loop:
        LD      HL,(FillRectRemaining)
        LD      A,H
        OR      L
        JR      Z,.row_done
        LD      B,H
        LD      C,L
        CALL    CacheGetCanvasFillSegmentLength
        PUSH    DE
        CALL    CacheMapCanvasOutputPage
        CALL    CacheMapPrevCanvasOutputPage
        LD      A,(CacheCopyDirection)
        OR      A
        JR      NZ,.prev_to_canvas
.canvas_to_prev:
        LD      HL,(CanvasOutputPtr)
        LD      DE,(PrevOutputPtr)
        JR      .copy_segment
.prev_to_canvas:
        LD      HL,(PrevOutputPtr)
        LD      DE,(CanvasOutputPtr)
.copy_segment:
        POP     BC
        PUSH    BC
        CALL    CacheAccCopyMemorySegmentNoEi
        POP     DE
        PUSH    DE
        CALL    CacheCanvasAdvanceOutputPtrByDE
        POP     DE
        RET     C
        PUSH    DE
        CALL    CachePrevAdvanceOutputPtrByDE
        POP     DE
        LD      HL,(FillRectRemaining)
        OR      A
        SBC     HL,DE
        LD      (FillRectRemaining),HL
        JR      .segment_loop
.row_done:
        LD      DE,(BlitRowSkip)
        PUSH    DE
        CALL    CacheCanvasAdvanceOutputPtrByDE
        POP     DE
        RET     C
        CALL    CachePrevAdvanceOutputPtrByDE
        LD      HL,(BlitRectRows)
        DEC     HL
        LD      (BlitRectRows),HL
        LD      A,H
        OR      L
        JR      NZ,.row_loop
        RET

CachePrevAdvanceOutputPtrByDE:
        LD      HL,(PrevOutputPtr)
        ADD     HL,DE
        JR      NC,.store_ptr
        PUSH    HL
        LD      A,(PrevOutputPage)
        INC     A
        LD      (PrevOutputPage),A
        CP      PREV_CANVAS_MEMORY_PAGES
        JR      C,.next_page
        POP     HL
        SCF
        RET
.next_page:
        POP     HL
        LD      DE,WORK_WINDOW
        ADD     HL,DE
.store_ptr:
        LD      (PrevOutputPtr),HL
        OR      A
        RET

CacheCopyDirection:
        DB      #00

CacheClearCurrentFrameRectToBackground:
        XOR     A
        LD      (CanvasOutputPage),A
        LD      (CanvasOutputDoneFlag),A
        LD      (CanvasTransparentFlag),A
        LD      HL,CANVAS_WINDOW
        LD      (CanvasOutputPtr),HL
        CALL    CacheGetCurrentFrameEntryPtr
        LD      DE,6
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      (CanvasFrameLeft),DE
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      (CanvasFrameTop),DE
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      (CanvasFrameWidth),DE
        LD      (CanvasFrameXRemaining),DE
        LD      A,D
        OR      E
        RET     Z
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      (CanvasRowsRemaining),DE
        LD      (BlitRectRows),DE
        LD      A,D
        OR      E
        RET     Z
        CALL    CacheCanvasSeekFrameStart
        CALL    CacheMapCanvasOutputPage
        LD      HL,GIF_MAX_WIDTH
        LD      DE,(CanvasFrameWidth)
        OR      A
        SBC     HL,DE
        LD      (BlitRowSkip),HL
.row_loop:
        CALL    CacheFillCanvasRowWithBackgroundAcc
        JP      C,LzwCanvasOverflow
        LD      DE,(BlitRowSkip)
        CALL    CacheCanvasAdvanceOutputPtrByDE
        JP      C,LzwCanvasOverflow
        LD      HL,(BlitRectRows)
        DEC     HL
        LD      (BlitRectRows),HL
        LD      A,H
        OR      L
        JR      NZ,.row_loop
        JP      CacheMarkCurrentFrameDirty

CacheFillCanvasRowWithBackgroundAcc:
        LD      HL,(CanvasFrameWidth)
        LD      (FillRectRemaining),HL
.segment_loop:
        LD      HL,(FillRectRemaining)
        LD      A,H
        OR      L
        RET     Z
        LD      B,H
        LD      C,L
        CALL    CacheGetCanvasFillSegmentLength
        PUSH    DE
        CALL    CacheMapCanvasOutputPage
        LD      HL,(CanvasOutputPtr)
        LD      A,(GifBackgroundColor)
        CALL    CacheAccFillMemorySegmentNoEi
        POP     DE
        PUSH    DE
        CALL    CacheCanvasAdvanceOutputPtrByDE
        POP     DE
        RET     C
        LD      HL,(FillRectRemaining)
        OR      A
        SBC     HL,DE
        LD      (FillRectRemaining),HL
        JR      .segment_loop

CacheGetCanvasFillSegmentLength:
        LD      A,B
        OR      A
        JR      NZ,.max_len
        LD      A,C
        CP      #00
        JR      NZ,.base_len
.max_len:
        LD      A,#FF
.base_len:
        LD      E,A
        LD      HL,(CanvasOutputPtr)
        LD      A,H
        CP      #FF
        JR      NZ,.done
        LD      A,L
        OR      A
        JR      Z,.done
        CPL
        INC     A
        CP      E
        JR      NC,.done
        LD      E,A
.done:
        LD      D,#00
        RET

CacheAccFillMemorySegmentNoEi:
        LD      C,A
        LD      A,E
        LD      (.length + 1),A
        DI
        LD      D,D
.length:
        LD      A,#00
        LD      C,C
        LD      (HL),C
        LD      B,B
        RET

CacheAccCopyMemorySegmentNoEi:
        LD      A,C
        DI
        LD      D,D
        LD      (DE),A
        LD      B,B
        LD      L,L
        LD      A,(HL)
        LD      (DE),A
        LD      B,B
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
        CALL    CacheAccCopyMemorySegmentNoEi
        LD      BC,(BlitRectWidth)
        ADD     HL,BC
        LD      (BlitSourcePtr),HL
        RET
.ldir_copy:
        LD      A,C
        PUSH    AF
        LD      C,#FF
        CALL    CacheAccCopyMemorySegmentNoEi
        LD      BC,#00FF
        ADD     HL,BC
        EX      DE,HL
        ADD     HL,BC
        EX      DE,HL
        POP     AF
        INC     A
        LD      C,A
        CALL    CacheAccCopyMemorySegmentNoEi
        LD      B,#00
        ADD     HL,BC
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
        CALL    CacheAdvanceBlitCanvasPage
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

CacheAdvanceBlitCanvasPage:
        LD      A,(BlitSourcePage)
        INC     A
        LD      (BlitSourcePage),A
        CP      CANVAS_MEMORY_PAGES
        RET     NC
        JP      CacheMapBlitCanvasPage

CacheMapBlitCanvasPage:
        LD      A,(BlitSourcePage)
        JP      CacheMapCanvasPageIndexToPage3

        ENT
