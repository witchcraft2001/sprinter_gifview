        INCLUDE "../include/exe_header.inc"
        INCLUDE "../include/bios_equ.inc"
        INCLUDE "../include/dss_equ.inc"
        INCLUDE "../include/ports.inc"

GIFVIEW_ORG EQU #8200
GIFVIEW_STACK EQU DSS_EXE_DEFAULT_STACK

FLAG_CENTER EQU #01
FLAG_INFO   EQU #02
FLAG_ONCE   EQU #04
FLAG_FAST   EQU #08

INPUT_FILENAME_MAX EQU 64
CACHE_RUNTIME_BASE EQU #0100
MAX_GIF_SIZE_HIGH EQU #0018
PAGE_SIZE EQU #4000
LOAD_WINDOW EQU #C000
WORK_WINDOW EQU #4000
CANVAS_WINDOW EQU LOAD_WINDOW
GIF_MAX_WIDTH EQU #0140
GIF_MAX_HEIGHT EQU #0100
MAX_FRAME_INDEX EQU #0100
FRAME_ENTRY_SIZE EQU 20
CANVAS_MEMORY_PAGES EQU #05
LZW_WORKSPACE_PAGES EQU #04
VIDEO_MODE_320_256 EQU #81
VIDEO_SCREEN_PAGES EQU #05
VIDEO_PAGE_A EQU VPAGE_TILES
VIDEO_PAGE_B EQU VPAGE_TILES + VIDEO_SCREEN_PAGES
LZW_PREFIX_BASE EQU #4000
LZW_SUFFIX_BASE EQU #6000
LZW_STACK_BASE EQU #7000

        ORG     GIFVIEW_ORG - DSS_EXE_HEADER_SIZE
        DSS_EXE_HEADER 1, #0000, GIFVIEW_ORG, GIFVIEW_ORG, GIFVIEW_STACK

        ORG     GIFVIEW_ORG

Entry:
        JP      Main

Main:
        LD      SP,GIFVIEW_STACK
        LD      (CommandLinePointerSlot),IX
        LD      HL,MsgBanner
        CALL    PrintString
        CALL    ParseCommandLine
        CALL    CopyCacheCode
        CALL    LoadGifFile
        CALL    PrintSelectedOptions
        LD      A,(OptionFlags)
        AND     FLAG_INFO
        JR      NZ,ExitSuccess
        CALL    AllocateWorkingMemory
        LD      HL,MsgDecoding
        CALL    PrintString
        XOR     A
        LD      (CurrentPlaybackFrame),A
        LD      (CurrentPlaybackFrame + 1),A
        CALL    DecodeCurrentFrameToCanvas
        CALL    RestorePage1
        CALL    RestorePage2
        CALL    RestorePage3
        LD      HL,MsgPressAnyKey
        CALL    PrintString
        CALL    InitPlaybackVideo
        CALL    BlitCanvasToVideo
        CALL    WaitForAnyKey
ExitSuccess:
        CALL    CleanupResources
        LD      BC,#0100 * #00 + Dss.Exit
        RST     Dss.Rst

ExitWithError:
        CALL    CleanupResources
        LD      BC,#0100 * #0FF + Dss.Exit
        RST     Dss.Rst

PrintString:
        LD      C,Dss.PChars
        RST     Dss.Rst
        RET

PrintCrLf:
        LD      HL,MsgCrLf
        JP      PrintString

PrintChar:
        LD      (CharBuffer),A
        LD      HL,CharBuffer
        JP      PrintString

PrintHexNibble:
        AND     #0F
        CP      #0A
        JR      C,.digit
        ADD     A,"A" - #0A
        JP      PrintChar
.digit:
        ADD     A,"0"
        JP      PrintChar

PrintHexByte:
        PUSH    AF
        RRCA
        RRCA
        RRCA
        RRCA
        CALL    PrintHexNibble
        POP     AF
        JP      PrintHexNibble

PrintHexWord:
        PUSH    HL
        LD      A,H
        CALL    PrintHexByte
        POP     HL
        LD      A,L
        JP      PrintHexByte

PrintHexFileSize:
        LD      HL,(FileSizeHigh)
        CALL    PrintHexWord
        LD      HL,(FileSizeLow)
        JP      PrintHexWord

ParseCommandLine:
CommandLinePointerSlot EQU ParseCommandLine + 1
        LD      HL,#0000
        XOR     A
        LD      (InputFileNameFlag),A
        LD      (InputFileName),A
        CALL    SkipProgramName
.loop:
        CALL    SkipSpaces
        LD      A,(HL)
        OR      A
        JR      Z,.done
        CP      "-"
        JR      Z,.option
        LD      A,(InputFileNameFlag)
        OR      A
        JP      NZ,DuplicateInputFile
        CALL    CopyFileName
        LD      A,#01
        LD      (InputFileNameFlag),A
        JR      .loop
.option:
        CALL    ParseOption
        JR      .loop
.done:
        LD      A,(InputFileNameFlag)
        OR      A
        JP      Z,ShowUsage
        RET

SkipProgramName:
        LD      A," "
.loop:
        INC     HL
        CP      (HL)
        JR      C,.loop
        RET

SkipSpaces:
        LD      A,(HL)
        CP      " "
        RET     NZ
        INC     HL
        JR      SkipSpaces

CopyFileName:
        LD      DE,InputFileName
        LD      B,INPUT_FILENAME_MAX - 1
.loop:
        LD      A,(HL)
        CP      #21
        JR      C,.done
        LD      (DE),A
        INC     HL
        INC     DE
        DJNZ    .loop
        LD      HL,MsgFileNameTooLong
        CALL    PrintString
        JP      ExitWithError
.done:
        XOR     A
        LD      (DE),A
        RET

ParseOption:
        LD      A,(HL)
        CP      "-"
        JP      NZ,UnknownOption
        INC     HL
        LD      A,(HL)
        OR      #20
        CP      "c"
        JR      Z,ParseCenterOption
        CP      "i"
        JR      Z,ParseInfoOption
        CP      "o"
        JR      Z,ParseOnceOption
        CP      "f"
        JR      Z,ParseFastOption
        JP      UnknownOption

ParseCenterOption:
        CALL    ExpectOptionCharC
        CALL    ExpectOptionCharE
        CALL    ExpectOptionCharN
        CALL    ExpectOptionCharT
        CALL    ExpectOptionCharE
        CALL    ExpectOptionCharR
        CALL    RequireOptionDelimiter
        LD      A,(OptionFlags)
        OR      FLAG_CENTER
        LD      (OptionFlags),A
        RET

ParseInfoOption:
        INC     HL
        CALL    RequireOptionDelimiter
        LD      A,(OptionFlags)
        OR      FLAG_INFO
        LD      (OptionFlags),A
        RET

ParseOnceOption:
        CALL    ExpectOptionCharO
        CALL    ExpectOptionCharN
        CALL    ExpectOptionCharC
        CALL    ExpectOptionCharE
        CALL    RequireOptionDelimiter
        LD      A,(OptionFlags)
        OR      FLAG_ONCE
        LD      (OptionFlags),A
        RET

ParseFastOption:
        CALL    ExpectOptionCharF
        CALL    ExpectOptionCharA
        CALL    ExpectOptionCharS
        CALL    ExpectOptionCharT
        CALL    RequireOptionDelimiter
        LD      A,(OptionFlags)
        OR      FLAG_FAST
        LD      (OptionFlags),A
        RET

ExpectOptionCharA:
        LD      E,"a"
        JR      ExpectOptionChar
ExpectOptionCharC:
        LD      E,"c"
        JR      ExpectOptionChar
ExpectOptionCharE:
        LD      E,"e"
        JR      ExpectOptionChar
ExpectOptionCharF:
        LD      E,"f"
        JR      ExpectOptionChar
ExpectOptionCharN:
        LD      E,"n"
        JR      ExpectOptionChar
ExpectOptionCharO:
        LD      E,"o"
        JR      ExpectOptionChar
ExpectOptionCharR:
        LD      E,"r"
        JR      ExpectOptionChar
ExpectOptionCharS:
        LD      E,"s"
        JR      ExpectOptionChar
ExpectOptionCharT:
        LD      E,"t"

ExpectOptionChar:
        LD      A,(HL)
        OR      #20
        CP      E
        JP      NZ,UnknownOption
        INC     HL
        RET

RequireOptionDelimiter:
        LD      A,(HL)
        CP      #21
        RET     C

UnknownOption:
        LD      HL,MsgUnknownOption
        CALL    PrintString
        JP      ExitWithError

DuplicateInputFile:
        LD      HL,MsgDuplicateInputFile
        CALL    PrintString
        JP      ExitWithError

ShowUsage:
        LD      HL,MsgUsage
        CALL    PrintString
        JP      ExitWithError

CopyCacheCode:
        LD      HL,GifCacheCodeStored
        LD      DE,CACHE_RUNTIME_BASE
        LD      BC,GifCacheCodeEnd - GifCacheCodeStored
        LDIR
        RET

LoadGifFile:
        LD      HL,InputFileName
        LD      A,FileMode.Read
        LD      C,Dss.Open
        RST     Dss.Rst
        JR      NC,.opened
        LD      HL,MsgOpenError
        CALL    PrintString
        JP      ExitWithError
.opened:
        LD      (FileHandle),A
        LD      A,#01
        LD      (FileOpenFlag),A
        CALL    ReadFileSize
        CALL    ValidateFileSize
        CALL    CalculatePagesNeeded
        CALL    AllocateGifMemory
        CALL    LoadFilePages
        LD      HL,MsgParsing
        CALL    PrintString
        CALL    ParseGifHeader
        CALL    PrepareGlobalPalette
        CALL    PrintFileInfo
        RET

ReadFileSize:
        LD      A,(FileHandle)
        LD      HL,#0000
        LD      IX,#0000
        LD      BC,#0100 * Dss.MoveFp.FromEnd + Dss.Move_FP
        RST     Dss.Rst
        JR      NC,.ok
        LD      HL,MsgSeekError
        CALL    PrintString
        JP      ExitWithError
.ok:
        LD      (FileSizeHigh),HL
        LD      (FileSizeLow),IX
        RET

ValidateFileSize:
        LD      HL,(FileSizeHigh)
        LD      DE,(FileSizeLow)
        LD      A,H
        OR      A
        JR      NZ,.too_large
        LD      A,L
        CP      LOW MAX_GIF_SIZE_HIGH + 1
        JR      NC,.too_large
        CP      LOW MAX_GIF_SIZE_HIGH
        JR      NZ,.not_at_limit
        LD      A,D
        OR      E
        JR      NZ,.too_large
.not_at_limit:
        LD      A,H
        OR      L
        OR      D
        OR      E
        JR      Z,.empty
        RET
.too_large:
        LD      HL,MsgTooLarge
        CALL    PrintString
        JP      ExitWithError
.empty:
        LD      HL,MsgEmptyFile
        CALL    PrintString
        JP      ExitWithError

CalculatePagesNeeded:
        LD      HL,(FileSizeLow)
        LD      D,H
        LD      E,L
        LD      A,D
        SRL     A
        SRL     A
        SRL     A
        SRL     A
        SRL     A
        SRL     A
        LD      C,A
        LD      A,D
        AND     #3F
        OR      E
        JR      Z,.low_pages_done
        INC     C
.low_pages_done:
        LD      HL,(FileSizeHigh)
        LD      A,L
        ADD     A,A
        ADD     A,A
        ADD     A,C
        LD      (PagesNeeded),A
        RET

AllocateGifMemory:
        LD      A,(PagesNeeded)
        LD      B,A
        LD      C,Dss.GetMem
        RST     Dss.Rst
        JR      NC,.ok
        LD      HL,MsgNoMemory
        CALL    PrintString
        JP      ExitWithError
.ok:
        LD      (MemoryBlockId),A
        LD      HL,GifPageTable
        CALL    DumpMemoryPageTable
        LD      A,#01
        LD      (MemoryAllocatedFlag),A
        RET

LoadFilePages:
        IN      A,(PAGE3)
        LD      (SavedPage3),A
        LD      A,(FileHandle)
        LD      HL,#0000
        LD      IX,#0000
        LD      BC,#0100 * Dss.MoveFp.FromStart + Dss.Move_FP
        RST     Dss.Rst
        JR      NC,.seek_ok
        LD      HL,MsgSeekError
        CALL    PrintString
        JP      ExitWithError
.seek_ok:
        LD      HL,MsgLoading
        CALL    PrintString
        XOR     A
        LD      (PageIndex),A
.loop:
        LD      A,(PageIndex)
        LD      C,A
        LD      A,(PagesNeeded)
        CP      C
        JR      Z,.done
        LD      A,C
        CALL    MapGifPageIndexToPage3
        LD      A,(FileHandle)
        LD      HL,LOAD_WINDOW
        LD      DE,PAGE_SIZE
        LD      C,Dss.Read
        RST     Dss.Rst
        JR      NC,.read_ok
        LD      HL,MsgReadError
        CALL    PrintString
        JP      ExitWithError
.read_ok:
        LD      A,"."
        CALL    PrintChar
        LD      HL,PageIndex
        INC     (HL)
        JR      .loop
.done:
        LD      A,(SavedPage3)
        OUT     (PAGE3),A
        LD      A,#FF
        LD      (SavedPage3),A
        XOR     A
        LD      (Page3Owner),A
        CALL    PrintCrLf
        CALL    CloseInputFile
        RET

MapGifPage0:
        IN      A,(PAGE3)
        LD      (SavedPage3),A
        XOR     A
        CALL    MapGifPageIndexToPage3
        LD      A,#01
        LD      (Page3Owner),A
        XOR     A
        LD      (Page3MappedPage),A
        RET

MapGifPageIndexToPage3:
        LD      HL,GifPageTable
        JR      MapPageTableIndexToPage3

MapCanvasPageIndexToPage3:
        LD      HL,CanvasPageTable
        JR      MapPageTableIndexToPage3

MapPageTableIndexToPage3:
        PUSH    DE
        LD      E,A
        LD      D,#00
        ADD     HL,DE
        LD      A,(HL)
        OUT     (PAGE3),A
        POP     DE
        OR      A
        RET

MapPageTableIndexToPage1:
        PUSH    DE
        LD      E,A
        LD      D,#00
        ADD     HL,DE
        LD      A,(HL)
        OUT     (PAGE1),A
        POP     DE
        OR      A
        RET

RestorePage3:
        LD      A,(SavedPage3)
        CP      #FF
        RET     Z
        OUT     (PAGE3),A
        LD      A,#FF
        LD      (SavedPage3),A
        XOR     A
        LD      (Page3Owner),A
        RET

ParseGifHeader:
        CALL    MapGifPage0
        LD      A,(LOAD_WINDOW + 0)
        CP      "G"
        JP      NZ,InvalidGifFile
        LD      A,(LOAD_WINDOW + 1)
        CP      "I"
        JP      NZ,InvalidGifFile
        LD      A,(LOAD_WINDOW + 2)
        CP      "F"
        JP      NZ,InvalidGifFile
        LD      A,(LOAD_WINDOW + 3)
        CP      "8"
        JP      NZ,InvalidGifFile
        LD      A,(LOAD_WINDOW + 4)
        CP      "7"
        JR      Z,.version_second_ok
        CP      "9"
        JP      NZ,InvalidGifFile
.version_second_ok:
        LD      A,(LOAD_WINDOW + 5)
        CP      "a"
        JP      NZ,InvalidGifFile
        LD      HL,LOAD_WINDOW
        LD      DE,GifVersion
        LD      BC,6
        LDIR
        XOR     A
        LD      (DE),A
        LD      A,(LOAD_WINDOW + 6)
        LD      L,A
        LD      A,(LOAD_WINDOW + 7)
        LD      H,A
        LD      (GifWidth),HL
        LD      A,(LOAD_WINDOW + 8)
        LD      L,A
        LD      A,(LOAD_WINDOW + 9)
        LD      H,A
        LD      (GifHeight),HL
        LD      A,(LOAD_WINDOW + 10)
        LD      (GifPacked),A
        CALL    CalculateGlobalColorTableSize
        CALL    RestorePage3
        CALL    ValidateGifDimensions
        CALL    ScanGifMetadata
        RET

InvalidGifFile:
        LD      HL,MsgNotGif
        CALL    PrintString
        JP      ExitWithError

CalculateGlobalColorTableSize:
        LD      A,(GifPacked)
        BIT     7,A
        JR      NZ,.present
        LD      HL,#0000
        LD      (GifGctEntries),HL
        LD      (GifGctBytes),HL
        XOR     A
        LD      (GifGctFlag),A
        RET
.present:
        LD      A,#01
        LD      (GifGctFlag),A
        LD      A,(GifPacked)
        AND     #07
        LD      B,A
        LD      HL,#0002
.loop:
        LD      A,B
        OR      A
        JR      Z,.done
        ADD     HL,HL
        DJNZ    .loop
.done:
        LD      (GifGctEntries),HL
        LD      D,H
        LD      E,L
        ADD     HL,HL
        ADD     HL,DE
        LD      (GifGctBytes),HL
        RET

ValidateGifDimensions:
        LD      HL,(GifWidth)
        LD      DE,GIF_MAX_WIDTH
        OR      A
        SBC     HL,DE
        JR      Z,.width_ok
        JR      C,.width_ok
        JR      GifSizeUnsupported
.width_ok:
        LD      HL,(GifHeight)
        LD      DE,GIF_MAX_HEIGHT
        OR      A
        SBC     HL,DE
        JR      Z,GifDimensionsOk
        JR      C,GifDimensionsOk
GifSizeUnsupported:
        LD      HL,MsgUnsupportedSize
        CALL    PrintString
        JP      ExitWithError
GifDimensionsOk:
        RET

ScanGifMetadata:
        CALL    MapGifPage0
        CALL    ResetGifMetadata
        LD      HL,LOAD_WINDOW + 13
        LD      DE,(GifGctBytes)
        ADD     HL,DE
        LD      (StreamPtr),HL
        XOR     A
        LD      (StreamPage),A
.loop:
        CALL    StreamGetByte
        CP      #3B
        JR      Z,.done
        CP      #2C
        JR      Z,.image
        CP      #21
        JR      Z,.extension
        OR      A
        JR      Z,.loop
        JP      InvalidGifBlock
.image:
        CALL    ParseImageBlock
        JR      .loop
.extension:
        CALL    ParseExtensionBlock
        JR      .loop
.done:
        CALL    RestorePage3
        RET

ResetGifMetadata:
        XOR     A
        LD      (GifFrameCount),A
        LD      (GifFrameCount + 1),A
        LD      (GifInterlaceFlag),A
        LD      (GifLocalColorTableFlag),A
        LD      (GifTransparencyFlag),A
        LD      (GifDisposal2Flag),A
        LD      (GifDisposal3Flag),A
        LD      (GifLoopFlag),A
        LD      (GifLoopCount),A
        LD      (GifLoopCount + 1),A
        LD      (FrameIndexCount),A
        LD      (FrameIndexCount + 1),A
        LD      (FrameIndexOverflow),A
        CALL    ResetCurrentGce
        RET

StreamGetByte:
        PUSH    HL
        PUSH    BC
        PUSH    DE
        LD      HL,(StreamPtr)
        LD      A,(HL)
        LD      (StreamByte),A
        INC     HL
        LD      A,H
        OR      A
        JR      NZ,.store_ptr
        LD      HL,LOAD_WINDOW
        LD      (StreamPtr),HL
        CALL    StreamMapNextPage
        JR      .done
.store_ptr:
        LD      (StreamPtr),HL
.done:
        POP     DE
        POP     BC
        POP     HL
        LD      A,(StreamByte)
        RET

StreamMapNextPage:
        LD      A,(StreamPage)
        INC     A
        LD      (StreamPage),A
        LD      C,A
        LD      A,(PagesNeeded)
        CP      C
        JP      C,InvalidGifBlock
        JP      Z,InvalidGifBlock
        LD      A,C
        CALL    MapGifPageIndexToPage3
        LD      A,#01
        LD      (Page3Owner),A
        LD      A,(StreamPage)
        LD      (Page3MappedPage),A
        RET

StreamSkipBC:
        LD      A,B
        OR      C
        RET     Z
.loop:
        CALL    StreamGetByte
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,.loop
        RET

SkipSubBlocks:
        CALL    StreamGetByte
        OR      A
        RET     Z
        LD      B,#00
        LD      C,A
        CALL    StreamSkipBC
        JR      SkipSubBlocks

ParseImageBlock:
        LD      HL,(GifFrameCount)
        INC     HL
        LD      (GifFrameCount),HL
        CALL    ReadStreamWord
        LD      (ImageLeft),HL
        CALL    ReadStreamWord
        LD      (ImageTop),HL
        CALL    ReadStreamWord
        LD      (ImageWidth),HL
        CALL    ReadStreamWord
        LD      (ImageHeight),HL
        CALL    StreamGetByte
        LD      (ImagePackedByte),A
        XOR     A
        LD      (FrameColorTablePage),A
        LD      HL,#0000
        LD      (FrameColorTablePtr),HL
        LD      A,(GifGctFlag)
        OR      A
        JR      Z,.color_table_selected
        XOR     A
        LD      (FrameColorTablePage),A
        LD      HL,LOAD_WINDOW + 13
        LD      (FrameColorTablePtr),HL
.color_table_selected:
        LD      A,(ImagePackedByte)
        BIT     6,A
        JR      Z,.no_interlace
        LD      A,#01
        LD      (GifInterlaceFlag),A
.no_interlace:
        LD      A,(ImagePackedByte)
        BIT     7,A
        JR      Z,.skip_image_data
        LD      A,#01
        LD      (GifLocalColorTableFlag),A
        LD      A,(StreamPage)
        LD      (FrameColorTablePage),A
        LD      HL,(StreamPtr)
        LD      (FrameColorTablePtr),HL
        LD      A,(ImagePackedByte)
        CALL    CalcColorTableBytesFromPacked
        LD      B,H
        LD      C,L
        CALL    StreamSkipBC
.skip_image_data:
        CALL    StreamGetByte
        LD      (FrameLzwMinCodeSize),A
        LD      A,(StreamPage)
        LD      (FrameDataPage),A
        LD      HL,(StreamPtr)
        LD      (FrameDataPtr),HL
        CALL    IndexCurrentFrame
        CALL    SkipSubBlocks
        CALL    ResetCurrentGce
        RET

ReadStreamWord:
        CALL    StreamGetByte
        LD      L,A
        CALL    StreamGetByte
        LD      H,A
        RET

ResetCurrentGce:
        XOR     A
        LD      (CurrentGcePacked),A
        LD      (CurrentDelay),A
        LD      (CurrentDelay + 1),A
        LD      (CurrentTransparentIndex),A
        RET

GetFrameEntryPtr:
        LD      A,(FrameIndexCount)
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

IndexCurrentFrame:
        LD      A,(FrameIndexCount + 1)
        OR      A
        JR      Z,.has_room
        LD      A,#01
        LD      (FrameIndexOverflow),A
        RET
.has_room:
        CALL    GetFrameEntryPtr
        LD      A,(FrameDataPage)
        LD      (HL),A
        INC     HL
        LD      DE,(FrameDataPtr)
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        LD      A,(FrameColorTablePage)
        LD      (HL),A
        INC     HL
        LD      DE,(FrameColorTablePtr)
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        LD      DE,(ImageLeft)
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        LD      DE,(ImageTop)
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        LD      DE,(ImageWidth)
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        LD      DE,(ImageHeight)
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        LD      A,(ImagePackedByte)
        LD      (HL),A
        INC     HL
        LD      A,(FrameLzwMinCodeSize)
        LD      (HL),A
        INC     HL
        LD      A,(CurrentGcePacked)
        LD      (HL),A
        INC     HL
        LD      A,(CurrentTransparentIndex)
        LD      (HL),A
        INC     HL
        LD      DE,(CurrentDelay)
        LD      (HL),E
        INC     HL
        LD      (HL),D
        LD      HL,(FrameIndexCount)
        INC     HL
        LD      (FrameIndexCount),HL
        RET

BeginFrameDataStream:
        IN      A,(PAGE3)
        LD      (SavedPage3),A
        CALL    GetCurrentFrameEntryPtr
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
        CALL    FrameStreamMapCurrentPage
        RET

GetCurrentFrameEntryPtr:
        LD      HL,(CurrentPlaybackFrame)
        LD      DE,(FrameIndexCount)
        OR      A
        SBC     HL,DE
        JP      NC,FrameIndexOutOfRange
        LD      A,(CurrentPlaybackFrame + 1)
        OR      A
        JP      NZ,FrameIndexOutOfRange
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

FrameStreamGetByte:
        LD      A,(FrameStreamDoneFlag)
        OR      A
        JR      Z,.not_done
        SCF
        RET
.not_done:
        LD      A,(FrameStreamSubBlockRemaining)
        OR      A
        JR      NZ,.read_data
        CALL    FrameStreamRawGetByte
        JR      C,.done
        OR      A
        JR      Z,.done
        LD      (FrameStreamSubBlockRemaining),A
.read_data:
        CALL    FrameStreamRawGetByte
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

FrameStreamRawGetByte:
        PUSH    HL
        CALL    FrameStreamMapCurrentPage
        LD      HL,(FrameStreamPtr)
        LD      A,(HL)
        LD      (FrameStreamByte),A
        INC     HL
        LD      A,H
        OR      A
        JR      NZ,.store_ptr
        LD      HL,LOAD_WINDOW
        LD      (FrameStreamPtr),HL
        CALL    FrameStreamMapNextPage
        JR      .done
.store_ptr:
        LD      (FrameStreamPtr),HL
.done:
        POP     HL
        LD      A,(FrameStreamByte)
        OR      A
        RET

FrameStreamMapCurrentPage:
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
        CALL    MapGifPageIndexToPage3
        LD      A,#01
        LD      (Page3Owner),A
        LD      A,(FrameStreamPage)
        LD      (Page3MappedPage),A
        RET

FrameStreamMapNextPage:
        LD      A,(FrameStreamPage)
        INC     A
        LD      (FrameStreamPage),A
        LD      C,A
        LD      A,(PagesNeeded)
        CP      C
        JP      C,InvalidGifBlock
        JP      Z,InvalidGifBlock
        JP      FrameStreamMapCurrentPage

FrameIndexOutOfRange:
        LD      HL,MsgFrameIndexOutOfRange
        CALL    PrintString
        JP      ExitWithError

LzwInitCodeReader:
        CALL    MapLzwWorkspace
        CALL    BeginFrameDataStream
        CALL    GetCurrentFrameEntryPtr
        LD      DE,15
        ADD     HL,DE
        LD      A,(HL)
        CP      #02
        JP      C,LzwUnsupportedCodeSize
        CP      #09
        JP      NC,LzwUnsupportedCodeSize
        LD      (LzwMinCodeSize),A
        INC     A
        LD      (LzwCodeSize),A
        XOR     A
        LD      (LzwCurrentByte),A
        LD      (LzwBitsRemaining),A
        LD      A,(LzwMinCodeSize)
        CALL    LzwPowerOfTwo
        LD      (LzwClearCode),HL
        INC     HL
        LD      (LzwEndCode),HL
        INC     HL
        LD      (LzwNextCode),HL
        RET

MapLzwWorkspace:
        IN      A,(PAGE1)
        LD      (SavedPage1),A
        XOR     A
        LD      HL,LzwPageTable
        JP      MapPageTableIndexToPage1

RestorePage1:
        LD      A,(SavedPage1)
        CP      #FF
        RET     Z
        OUT     (PAGE1),A
        LD      A,#FF
        LD      (SavedPage1),A
        RET

LzwResetDictionary:
        LD      HL,(LzwClearCode)
        LD      (LzwNextCode),HL
        LD      HL,(LzwNextCode)
        INC     HL
        INC     HL
        LD      (LzwNextCode),HL
        LD      A,(LzwMinCodeSize)
        INC     A
        LD      (LzwCodeSize),A
        RET

LzwGetPrefixPtr:
        ADD     HL,HL
        LD      DE,LZW_PREFIX_BASE
        ADD     HL,DE
        RET

LzwGetSuffixPtr:
        LD      DE,LZW_SUFFIX_BASE
        ADD     HL,DE
        RET

LzwGetStackPtr:
        LD      DE,LZW_STACK_BASE
        ADD     HL,DE
        RET

DecodeCurrentFrameToCanvas:
        CALL    LzwInitCodeReader
        CALL    BeginCanvasOutput
        CALL    LzwResetDictionary
        CALL    LzwReadFirstDataCode
        RET     C
        LD      (LzwOldCode),HL
        CALL    LzwOutputCodeString
        CALL    IsCanvasComplete
        RET     NZ
.loop:
        CALL    LzwReadCode
        RET     C
        LD      DE,(LzwClearCode)
        CALL    CompareHLDE
        JR      Z,.clear_code
        LD      DE,(LzwEndCode)
        CALL    CompareHLDE
        RET     Z
        LD      (LzwInCode),HL
        LD      DE,(LzwNextCode)
        CALL    CompareHLDE
        JR      C,.known_code
        JR      Z,.next_code
        JP      LzwInvalidStream
.known_code:
        CALL    LzwOutputCodeString
        CALL    IsCanvasComplete
        RET     NZ
        CALL    LzwAddDictionaryEntry
        LD      HL,(LzwInCode)
        LD      (LzwOldCode),HL
        JR      .loop
.next_code:
        LD      HL,(LzwOldCode)
        CALL    LzwOutputCodeString
        CALL    IsCanvasComplete
        RET     NZ
        LD      A,(LzwFirstChar)
        CALL    CanvasPutPixel
        JP      C,LzwCanvasOverflow
        CALL    IsCanvasComplete
        RET     NZ
        CALL    LzwAddDictionaryEntry
        LD      HL,(LzwInCode)
        LD      (LzwOldCode),HL
        JR      .loop
.clear_code:
        CALL    LzwResetDictionary
        CALL    LzwReadFirstDataCode
        RET     C
        LD      (LzwOldCode),HL
        CALL    LzwOutputCodeString
        CALL    IsCanvasComplete
        RET     NZ
        JR      .loop

IsCanvasComplete:
        LD      A,(CanvasOutputDoneFlag)
        OR      A
        RET

LzwReadFirstDataCode:
        CALL    LzwReadCode
        RET     C
        LD      DE,(LzwClearCode)
        CALL    CompareHLDE
        JR      Z,LzwReadFirstDataCode
        LD      DE,(LzwEndCode)
        CALL    CompareHLDE
        JR      Z,.end_code
        LD      DE,(LzwClearCode)
        CALL    CompareHLDE
        JR      C,.valid_code
        JP      LzwInvalidStream
.valid_code:
        OR      A
        RET
.end_code:
        SCF
        RET

LzwOutputCodeString:
        PUSH    HL
        CALL    LzwResetStack
        POP     HL
        CALL    LzwExpandCodeToStack
        LD      (LzwFirstChar),A
        CALL    CanvasPutPixel
        JP      C,LzwCanvasOverflow
.pop_loop:
        CALL    LzwPopStack
        RET     C
        CALL    CanvasPutPixel
        JP      C,LzwCanvasOverflow
        JR      .pop_loop

LzwExpandCodeToStack:
        LD      DE,(LzwClearCode)
        CALL    CompareHLDE
        JR      C,.literal
        PUSH    HL
        CALL    LzwGetSuffixPtr
        LD      A,(HL)
        CALL    LzwPushStack
        POP     HL
        CALL    LzwReadPrefix
        JR      LzwExpandCodeToStack
.literal:
        LD      A,L
        RET

LzwReadPrefix:
        CALL    LzwGetPrefixPtr
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        RET

LzwAddDictionaryEntry:
        LD      HL,(LzwNextCode)
        LD      DE,#1000
        CALL    CompareHLDE
        RET     NC
        LD      HL,(LzwNextCode)
        CALL    LzwGetPrefixPtr
        LD      DE,(LzwOldCode)
        LD      (HL),E
        INC     HL
        LD      (HL),D
        LD      HL,(LzwNextCode)
        CALL    LzwGetSuffixPtr
        LD      A,(LzwFirstChar)
        LD      (HL),A
        LD      HL,(LzwNextCode)
        INC     HL
        LD      (LzwNextCode),HL
        LD      A,(LzwCodeSize)
        CP      #0C
        RET     NC
        CALL    LzwPowerOfTwo
        LD      DE,(LzwNextCode)
        EX      DE,HL
        CALL    CompareHLDE
        RET     NZ
        LD      A,(LzwCodeSize)
        INC     A
        LD      (LzwCodeSize),A
        RET

LzwResetStack:
        LD      HL,LZW_STACK_BASE
        LD      (LzwStackPtr),HL
        RET

LzwPushStack:
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

LzwPopStack:
        LD      HL,(LzwStackPtr)
        LD      DE,LZW_STACK_BASE
        CALL    CompareHLDE
        JR      NZ,.has_data
        SCF
        RET
.has_data:
        DEC     HL
        LD      (LzwStackPtr),HL
        LD      A,(HL)
        OR      A
        RET

CompareHLDE:
        PUSH    HL
        OR      A
        SBC     HL,DE
        POP     HL
        RET

LzwInvalidStream:
        LD      HL,MsgInvalidLzwStream
        CALL    PrintString
        JP      ExitWithError

LzwCanvasOverflow:
        LD      HL,MsgCanvasOverflow
        CALL    PrintString
        JP      ExitWithError

BeginCanvasOutput:
        XOR     A
        LD      (CanvasOutputPage),A
        LD      (CanvasOutputDoneFlag),A
        LD      HL,CANVAS_WINDOW
        LD      (CanvasOutputPtr),HL
        CALL    GetCurrentFrameEntryPtr
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
        LD      (CanvasRowsRemaining),DE
        INC     HL
        INC     HL
        INC     HL
        LD      A,(HL)
        AND     #01
        LD      (CanvasTransparentFlag),A
        INC     HL
        LD      A,(HL)
        LD      (CanvasTransparentIndex),A
        CALL    CanvasSeekFrameStart
        JP      MapCanvasOutputPage

CanvasPutPixel:
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
        CALL    MapCanvasOutputPage
        LD      HL,(CanvasOutputPtr)
        LD      A,(CanvasOutputByte)
        LD      (HL),A
.advance_pixel:
        CALL    CanvasAdvancePixel
        RET     C
        LD      A,(CanvasOutputByte)
        OR      A
        RET

CanvasSeekFrameStart:
        LD      HL,(CanvasFrameTop)
        LD      A,H
        OR      L
        JR      Z,.left_offset
.row_loop:
        PUSH    HL
        LD      DE,GIF_MAX_WIDTH
        CALL    CanvasAdvanceOutputPtrByDE
        POP     HL
        RET     C
        DEC     HL
        LD      A,H
        OR      L
        JR      NZ,.row_loop
.left_offset:
        LD      DE,(CanvasFrameLeft)
        CALL    CanvasAdvanceOutputPtrByDE
        RET     C
        LD      A,(CanvasOutputPage)
        LD      (CanvasRowStartPage),A
        LD      HL,(CanvasOutputPtr)
        LD      (CanvasRowStartPtr),HL
        OR      A
        RET

CanvasAdvancePixel:
        LD      DE,#0001
        CALL    CanvasAdvanceOutputPtrByDE
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
        LD      A,(CanvasRowStartPage)
        LD      (CanvasOutputPage),A
        LD      HL,(CanvasRowStartPtr)
        LD      (CanvasOutputPtr),HL
        LD      DE,GIF_MAX_WIDTH
        CALL    CanvasAdvanceOutputPtrByDE
        RET     C
        LD      A,(CanvasOutputPage)
        LD      (CanvasRowStartPage),A
        LD      HL,(CanvasOutputPtr)
        LD      (CanvasRowStartPtr),HL
        LD      HL,(CanvasFrameWidth)
        LD      (CanvasFrameXRemaining),HL
        OR      A
        RET

CanvasAdvanceOutputPtrByDE:
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
.ok:
        OR      A
        RET

MapCanvasOutputPage:
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

RestorePage2:
        LD      A,(SavedPage2)
        CP      #FF
        RET     Z
        OUT     (PAGE2),A
        LD      A,#FF
        LD      (SavedPage2),A
        RET

LzwPowerOfTwo:
        LD      B,A
        LD      HL,#0001
.loop:
        LD      A,B
        OR      A
        RET     Z
        ADD     HL,HL
        DJNZ    .loop
        RET

LzwReadCode:
        LD      HL,#0000
        LD      DE,#0001
        LD      A,(LzwCodeSize)
        LD      B,A
.loop:
        CALL    LzwReadBit
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

LzwReadBit:
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

LzwUnsupportedCodeSize:
        LD      HL,MsgUnsupportedLzwCodeSize
        CALL    PrintString
        JP      ExitWithError

CalcColorTableBytesFromPacked:
        AND     #07
        LD      B,A
        LD      HL,#0002
.loop:
        LD      A,B
        OR      A
        JR      Z,.entries_ready
        ADD     HL,HL
        DJNZ    .loop
.entries_ready:
        LD      D,H
        LD      E,L
        ADD     HL,HL
        ADD     HL,DE
        RET

ParseExtensionBlock:
        CALL    StreamGetByte
        CP      #F9
        JR      Z,ParseGraphicControlExtension
        CP      #FF
        JR      Z,ParseApplicationExtension
        CALL    SkipSubBlocks
        RET

ParseGraphicControlExtension:
        CALL    StreamGetByte
        CP      #04
        JR      NZ,.skip_unexpected
        CALL    StreamGetByte
        LD      (GcePackedByte),A
        LD      (CurrentGcePacked),A
        BIT     0,A
        JR      Z,.no_transparency
        LD      A,#01
        LD      (GifTransparencyFlag),A
.no_transparency:
        LD      A,(GcePackedByte)
        AND     #1C
        CP      #08
        JR      NZ,.not_disposal2
        LD      A,#01
        LD      (GifDisposal2Flag),A
.not_disposal2:
        LD      A,(GcePackedByte)
        AND     #1C
        CP      #0C
        JR      NZ,.not_disposal3
        LD      A,#01
        LD      (GifDisposal3Flag),A
.not_disposal3:
        CALL    StreamGetByte
        LD      (CurrentDelay),A
        CALL    StreamGetByte
        LD      (CurrentDelay + 1),A
        CALL    StreamGetByte
        LD      (CurrentTransparentIndex),A
        CALL    StreamGetByte
        RET
.skip_unexpected:
        LD      B,#00
        LD      C,A
        CALL    StreamSkipBC
        CALL    SkipSubBlocks
        RET

ParseApplicationExtension:
        CALL    StreamGetByte
        CP      #0B
        JR      NZ,.skip_unexpected
        LD      HL,AppIdBuffer
        LD      B,#0B
.read_id:
        CALL    StreamGetByte
        LD      (HL),A
        INC     HL
        DJNZ    .read_id
        CALL    IsNetscapeAppId
        JP      NZ,SkipSubBlocks
        CALL    StreamGetByte
        CP      #03
        JR      NZ,.skip_after_size
        CALL    StreamGetByte
        CALL    StreamGetByte
        LD      L,A
        CALL    StreamGetByte
        LD      H,A
        LD      (GifLoopCount),HL
        LD      A,#01
        LD      (GifLoopFlag),A
        CALL    StreamGetByte
        RET
.skip_after_size:
        LD      B,#00
        LD      C,A
        CALL    StreamSkipBC
        CALL    SkipSubBlocks
        RET
.skip_unexpected:
        LD      B,#00
        LD      C,A
        CALL    StreamSkipBC
        CALL    SkipSubBlocks
        RET

IsNetscapeAppId:
        LD      HL,AppIdBuffer
        LD      DE,AppIdNetscape
        LD      B,#0B
.loop:
        LD      A,(DE)
        CP      (HL)
        RET     NZ
        INC     HL
        INC     DE
        DJNZ    .loop
        XOR     A
        RET

InvalidGifBlock:
        LD      HL,MsgInvalidGifBlock
        CALL    PrintString
        JP      ExitWithError

PrepareGlobalPalette:
        CALL    ClearGlobalPaletteBuffer
        LD      A,(GifGctFlag)
        OR      A
        RET     Z
        CALL    MapGifPage0
        LD      HL,LOAD_WINDOW + 13
        LD      DE,GlobalPaletteBuffer
        LD      A,(GifGctEntries)
        LD      B,A
.loop:
        LD      A,(HL)
        INC     HL
        CALL    ConvertRgb8ToRgb6
        LD      (DE),A
        INC     DE
        LD      A,(HL)
        INC     HL
        CALL    ConvertRgb8ToRgb6
        LD      (DE),A
        INC     DE
        LD      A,(HL)
        INC     HL
        CALL    ConvertRgb8ToRgb6
        LD      (DE),A
        INC     DE
        DJNZ    .loop
        CALL    RestorePage3
        RET

ConvertRgb8ToRgb6:
        RET

ClearGlobalPaletteBuffer:
        LD      HL,GlobalPaletteBuffer
        LD      DE,GlobalPaletteBuffer + 1
        LD      BC,#02FF
        XOR     A
        LD      (HL),A
        LDIR
        RET

LoadPreparedGlobalPalette:
        IN      A,(PAGE1)
        LD      (SavedPage1),A
        LD      A,VIDEO_PAGE_A
        OUT     (PAGE1),A
        LD      HL,GlobalPaletteBuffer
        LD      (PaletteLoadPtr),HL
        XOR     A
        LD      (PaletteLoadIndex),A
.loop:
        LD      A,(PaletteLoadIndex)
        OUT     (PORT_Y),A
        LD      DE,#43E0
        LD      HL,(PaletteLoadPtr)
        LD      A,(HL)
        INC     HL
        LD      (DE),A
        INC     E
        LD      A,(HL)
        INC     HL
        LD      (DE),A
        INC     E
        LD      A,(HL)
        INC     HL
        LD      (DE),A
        LD      (PaletteLoadPtr),HL
        LD      HL,PaletteLoadIndex
        INC     (HL)
        JR      NZ,.loop
        LD      A,#C0
        OUT     (PORT_Y),A
        JP      RestorePage1

PrintFileInfo:
        LD      HL,MsgSelectedFile
        CALL    PrintString
        LD      HL,InputFileName
        CALL    PrintString
        CALL    PrintCrLf
        LD      HL,MsgFileSize
        CALL    PrintString
        CALL    PrintHexFileSize
        CALL    PrintCrLf
        LD      HL,MsgPages
        CALL    PrintString
        LD      A,(PagesNeeded)
        CALL    PrintHexByte
        CALL    PrintCrLf
        LD      HL,MsgGifVersion
        CALL    PrintString
        LD      HL,GifVersion
        CALL    PrintString
        CALL    PrintCrLf
        LD      HL,MsgGifWidth
        CALL    PrintString
        LD      HL,(GifWidth)
        CALL    PrintHexWord
        CALL    PrintCrLf
        LD      HL,MsgGifHeight
        CALL    PrintString
        LD      HL,(GifHeight)
        CALL    PrintHexWord
        CALL    PrintCrLf
        LD      HL,MsgGifPacked
        CALL    PrintString
        LD      A,(GifPacked)
        CALL    PrintHexByte
        CALL    PrintCrLf
        LD      HL,MsgGifGctPresent
        CALL    PrintString
        LD      A,(GifGctFlag)
        CALL    PrintHexByte
        CALL    PrintCrLf
        LD      HL,MsgGifGctEntries
        CALL    PrintString
        LD      HL,(GifGctEntries)
        CALL    PrintHexWord
        CALL    PrintCrLf
        LD      HL,MsgGifGctBytes
        CALL    PrintString
        LD      HL,(GifGctBytes)
        CALL    PrintHexWord
        CALL    PrintCrLf
        LD      HL,MsgGifPreparedPalette
        CALL    PrintString
        LD      HL,(GifGctEntries)
        CALL    PrintHexWord
        CALL    PrintCrLf
        LD      HL,MsgGifFrames
        CALL    PrintString
        LD      HL,(GifFrameCount)
        CALL    PrintHexWord
        CALL    PrintCrLf
        LD      HL,MsgGifFrameIndex
        CALL    PrintString
        LD      HL,(FrameIndexCount)
        CALL    PrintHexWord
        CALL    PrintCrLf
        LD      HL,MsgGifFrameIndexOverflow
        CALL    PrintString
        LD      A,(FrameIndexOverflow)
        CALL    PrintHexByte
        CALL    PrintCrLf
        LD      HL,MsgGifInterlace
        CALL    PrintString
        LD      A,(GifInterlaceFlag)
        CALL    PrintHexByte
        CALL    PrintCrLf
        LD      HL,MsgGifLocalColorTable
        CALL    PrintString
        LD      A,(GifLocalColorTableFlag)
        CALL    PrintHexByte
        CALL    PrintCrLf
        LD      HL,MsgGifTransparency
        CALL    PrintString
        LD      A,(GifTransparencyFlag)
        CALL    PrintHexByte
        CALL    PrintCrLf
        LD      HL,MsgGifDisposal2
        CALL    PrintString
        LD      A,(GifDisposal2Flag)
        CALL    PrintHexByte
        CALL    PrintCrLf
        LD      HL,MsgGifDisposal3
        CALL    PrintString
        LD      A,(GifDisposal3Flag)
        CALL    PrintHexByte
        CALL    PrintCrLf
        LD      HL,MsgGifLoop
        CALL    PrintString
        LD      A,(GifLoopFlag)
        CALL    PrintHexByte
        CALL    PrintCrLf
        LD      HL,MsgGifLoopCount
        CALL    PrintString
        LD      HL,(GifLoopCount)
        CALL    PrintHexWord
        CALL    PrintCrLf
        RET

AllocateWorkingMemory:
        CALL    AllocateCanvasMemory
        CALL    AllocateLzwWorkspaceMemory
        CALL    ClearWorkingMemory
        RET

AllocateCanvasMemory:
        LD      B,CANVAS_MEMORY_PAGES
        LD      C,Dss.GetMem
        RST     Dss.Rst
        JR      NC,.ok
        LD      HL,MsgNoMemory
        CALL    PrintString
        JP      ExitWithError
.ok:
        LD      (CanvasMemoryBlockId),A
        LD      HL,CanvasPageTable
        CALL    DumpMemoryPageTable
        LD      A,#01
        LD      (CanvasMemoryAllocatedFlag),A
        RET

AllocateLzwWorkspaceMemory:
        LD      B,LZW_WORKSPACE_PAGES
        LD      C,Dss.GetMem
        RST     Dss.Rst
        JR      NC,.ok
        LD      HL,MsgNoMemory
        CALL    PrintString
        JP      ExitWithError
.ok:
        LD      (LzwMemoryBlockId),A
        LD      HL,LzwPageTable
        CALL    DumpMemoryPageTable
        LD      A,#01
        LD      (LzwMemoryAllocatedFlag),A
        RET

DumpMemoryPageTable:
        LD      C,Bios.Emm_Fn5
        RST     Bios.Rst
        RET     NC
        LD      HL,MsgMemoryMapError
        CALL    PrintString
        JP      ExitWithError

ClearWorkingMemory:
        IN      A,(PAGE3)
        LD      (SavedPage3),A
        LD      A,(CanvasMemoryBlockId)
        LD      C,CANVAS_MEMORY_PAGES
        CALL    ClearMemoryBlock
        LD      A,(LzwMemoryBlockId)
        LD      C,LZW_WORKSPACE_PAGES
        CALL    ClearMemoryBlock
        CALL    RestorePage3
        RET

ClearMemoryBlock:
        LD      (ClearBlockId),A
        XOR     A
        LD      (ClearPageIndex),A
.loop:
        LD      A,(ClearPageIndex)
        CP      C
        RET     Z
        LD      B,A
        LD      A,(ClearBlockId)
        PUSH    BC
        LD      C,Dss.SetWin3
        RST     Dss.Rst
        POP     BC
        JR      NC,.mapped
        LD      HL,MsgMemoryMapError
        CALL    PrintString
        JP      ExitWithError
.mapped:
        PUSH    BC
        CALL    ClearLoadWindow
        POP     BC
        LD      A,(ClearPageIndex)
        INC     A
        LD      (ClearPageIndex),A
        JR      .loop

ClearLoadWindow:
        LD      HL,LOAD_WINDOW
        LD      DE,LOAD_WINDOW + 1
        LD      BC,PAGE_SIZE - 1
        XOR     A
        LD      (HL),A
        LDIR
        RET

ClearWorkWindow:
        LD      HL,WORK_WINDOW
        LD      DE,WORK_WINDOW + 1
        LD      BC,PAGE_SIZE - 1
        XOR     A
        LD      (HL),A
        LDIR
        RET

InitPlaybackVideo:
        IN      A,(RGMOD)
        LD      (SavedRGMOD),A
        LD      C,Dss.GetVMod
        RST     Dss.Rst
        LD      (SavedVideoMode),A
        LD      A,B
        LD      (SavedVideoBank),A
        LD      BC,#0100 * #00 + Dss.SetVMod
        LD      A,VIDEO_MODE_320_256
        RST     Dss.Rst
        JR      NC,.mode_ok
        LD      HL,MsgVideoModeError
        CALL    PrintString
        JP      ExitWithError
.mode_ok:
        LD      A,#01
        LD      (VideoInitializedFlag),A
        CALL    ClearVideoBuffers
        CALL    LoadPreparedGlobalPalette
        RET

RestorePlaybackVideo:
        LD      A,(VideoInitializedFlag)
        OR      A
        RET     Z
        XOR     A
        LD      (VideoInitializedFlag),A
        LD      A,(SavedVideoBank)
        LD      B,A
        LD      A,(SavedVideoMode)
        LD      C,Dss.SetVMod
        RST     Dss.Rst
        LD      A,(SavedRGMOD)
        OUT     (RGMOD),A
        RET

ClearVideoBuffers:
        IN      A,(PAGE1)
        LD      (SavedPage1),A
        LD      A,VIDEO_PAGE_A
        OUT     (PAGE1),A
        CALL    ClearVisibleScreenRows
        XOR     A
        OUT     (RGMOD),A
        LD      A,#C0
        OUT     (PORT_Y),A
        CALL    RestorePage1
        RET

ClearVisibleScreenRows:
        XOR     A
        LD      (VideoRowIndex),A
.loop:
        LD      A,(VideoRowIndex)
        OUT     (PORT_Y),A
        CALL    ClearVideoRowA
        LD      HL,VideoRowIndex
        INC     (HL)
        LD      A,(HL)
        OR      A
        JR      NZ,.loop
        RET     Z

ClearVideoRowA:
        LD      HL,WORK_WINDOW
        LD      DE,WORK_WINDOW + 1
        LD      BC,GIF_MAX_WIDTH - 1
        XOR     A
        LD      (HL),A
        LDIR
        RET

BlitCanvasToVideo:
        IN      A,(PAGE3)
        LD      (SavedPage3),A
        IN      A,(PAGE1)
        LD      (SavedPage1),A
        LD      A,VIDEO_PAGE_A
        OUT     (PAGE1),A
        XOR     A
        LD      (BlitSourcePage),A
        LD      (VideoRowIndex),A
        LD      HL,LOAD_WINDOW
        LD      (BlitSourcePtr),HL
        CALL    MapBlitCanvasPage
.row_loop:
        LD      A,(VideoRowIndex)
        OUT     (PORT_Y),A
        CALL    BlitCanvasRowToVideo
        LD      HL,VideoRowIndex
        INC     (HL)
        LD      A,(HL)
        OR      A
        JR      NZ,.row_loop
        XOR     A
        OUT     (RGMOD),A
        LD      A,#C0
        OUT     (PORT_Y),A
        CALL    RestorePage3
        CALL    RestorePage1
        RET

BlitCanvasRowToVideo:
        LD      DE,WORK_WINDOW
        LD      BC,GIF_MAX_WIDTH
.loop:
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
        JR      NZ,.loop
        RET

AdvanceBlitCanvasPage:
        LD      A,(BlitSourcePage)
        INC     A
        LD      (BlitSourcePage),A
        CP      CANVAS_MEMORY_PAGES
        RET     NC
        JP      MapBlitCanvasPage

MapBlitCanvasPage:
        LD      A,(BlitSourcePage)
        JP      MapCanvasPageIndexToPage3

PrintSelectedOptions:
        LD      A,(OptionFlags)
        AND     FLAG_CENTER
        CALL    NZ,PrintCenterEnabled
        LD      A,(OptionFlags)
        AND     FLAG_INFO
        CALL    NZ,PrintInfoEnabled
        LD      A,(OptionFlags)
        AND     FLAG_ONCE
        CALL    NZ,PrintOnceEnabled
        LD      A,(OptionFlags)
        AND     FLAG_FAST
        CALL    NZ,PrintFastEnabled
        RET

CloseInputFile:
        LD      A,(FileOpenFlag)
        OR      A
        RET     Z
        XOR     A
        LD      (FileOpenFlag),A
        LD      A,(FileHandle)
        LD      C,Dss.Close
        RST     Dss.Rst
        RET

CleanupResources:
        CALL    RestorePage1
        CALL    RestorePage2
        LD      A,(SavedPage3)
        CP      #FF
        JR      Z,.page_restored
        OUT     (PAGE3),A
        LD      A,#FF
        LD      (SavedPage3),A
.page_restored:
        CALL    RestorePlaybackVideo
        CALL    CloseInputFile
        CALL    FreeLzwWorkspaceMemory
        CALL    FreeCanvasMemory
        LD      A,(MemoryAllocatedFlag)
        OR      A
        RET     Z
        XOR     A
        LD      (MemoryAllocatedFlag),A
        LD      A,(MemoryBlockId)
        LD      C,Dss.FreeMem
        RST     Dss.Rst
        RET

FreeCanvasMemory:
        LD      A,(CanvasMemoryAllocatedFlag)
        OR      A
        RET     Z
        XOR     A
        LD      (CanvasMemoryAllocatedFlag),A
        LD      A,(CanvasMemoryBlockId)
        LD      C,Dss.FreeMem
        RST     Dss.Rst
        RET

FreeLzwWorkspaceMemory:
        LD      A,(LzwMemoryAllocatedFlag)
        OR      A
        RET     Z
        XOR     A
        LD      (LzwMemoryAllocatedFlag),A
        LD      A,(LzwMemoryBlockId)
        LD      C,Dss.FreeMem
        RST     Dss.Rst
        RET

PrintCenterEnabled:
        LD      HL,MsgOptCenter
        JP      PrintString

PrintInfoEnabled:
        LD      HL,MsgOptInfo
        JP      PrintString

PrintOnceEnabled:
        LD      HL,MsgOptOnce
        JP      PrintString

PrintFastEnabled:
        LD      HL,MsgOptFast
        JP      PrintString

WaitForAnyKey:
        LD      C,Dss.WaitKey
        RST     Dss.Rst
        RET

GifCacheCodeStored:
        INCLUDE "cache_code.asm"
GifCacheCodeEnd:

OptionFlags:
        DB      #00
FileHandle:
        DB      #00
FileOpenFlag:
        DB      #00
MemoryBlockId:
        DB      #00
MemoryAllocatedFlag:
        DB      #00
CanvasMemoryBlockId:
        DB      #00
CanvasMemoryAllocatedFlag:
        DB      #00
LzwMemoryBlockId:
        DB      #00
LzwMemoryAllocatedFlag:
        DB      #00
ClearBlockId:
        DB      #00
ClearPageIndex:
        DB      #00
VideoInitializedFlag:
        DB      #00
SavedVideoMode:
        DB      #00
SavedVideoBank:
        DB      #00
SavedRGMOD:
        DB      #00
ClearVideoPageValue:
        DB      #00
ClearVideoPageCount:
        DB      #00
BlitPageIndex:
        DB      #00
BlitSourcePage:
        DB      #00
BlitSourcePtr:
        DW      #0000
VideoRowIndex:
        DB      #00
SavedPage1:
        DB      #FF
SavedPage2:
        DB      #FF
SavedPage3:
        DB      #FF
Page3Owner:
        DB      #00
Page3MappedPage:
        DB      #00
GifPageTable:
        DS      #100,#00
CanvasPageTable:
        DS      CANVAS_MEMORY_PAGES,#00
LzwPageTable:
        DS      LZW_WORKSPACE_PAGES,#00
PagesNeeded:
        DB      #00
PageIndex:
        DB      #00
FileSizeHigh:
        DW      #0000
FileSizeLow:
        DW      #0000
GifWidth:
        DW      #0000
GifHeight:
        DW      #0000
GifGctEntries:
        DW      #0000
GifGctBytes:
        DW      #0000
GifPacked:
        DB      #00
GifGctFlag:
        DB      #00
StreamPtr:
        DW      #0000
StreamPage:
        DB      #00
StreamByte:
        DB      #00
GifFrameCount:
        DW      #0000
GifInterlaceFlag:
        DB      #00
GifLocalColorTableFlag:
        DB      #00
GifTransparencyFlag:
        DB      #00
GifDisposal2Flag:
        DB      #00
GifDisposal3Flag:
        DB      #00
GifLoopFlag:
        DB      #00
GifLoopCount:
        DW      #0000
ImagePackedByte:
        DB      #00
ImageLeft:
        DW      #0000
ImageTop:
        DW      #0000
ImageWidth:
        DW      #0000
ImageHeight:
        DW      #0000
GcePackedByte:
        DB      #00
CurrentGcePacked:
        DB      #00
CurrentDelay:
        DW      #0000
CurrentTransparentIndex:
        DB      #00
FrameDataPage:
        DB      #00
FrameDataPtr:
        DW      #0000
FrameColorTablePage:
        DB      #00
FrameColorTablePtr:
        DW      #0000
FrameLzwMinCodeSize:
        DB      #00
FrameIndexCount:
        DW      #0000
FrameIndexOverflow:
        DB      #00
CurrentPlaybackFrame:
        DW      #0000
FrameStreamPage:
        DB      #00
FrameStreamPtr:
        DW      #0000
FrameStreamByte:
        DB      #00
FrameStreamSubBlockRemaining:
        DB      #00
FrameStreamDoneFlag:
        DB      #00
LzwMinCodeSize:
        DB      #00
LzwCodeSize:
        DB      #00
LzwCurrentByte:
        DB      #00
LzwBitsRemaining:
        DB      #00
LzwReadBitValue:
        DB      #00
LzwClearCode:
        DW      #0000
LzwEndCode:
        DW      #0000
LzwNextCode:
        DW      #0000
LzwOldCode:
        DW      #0000
LzwInCode:
        DW      #0000
LzwFirstChar:
        DB      #00
LzwStackPtr:
        DW      #0000
LzwStackByte:
        DB      #00
CanvasOutputPage:
        DB      #00
CanvasOutputPtr:
        DW      #0000
CanvasOutputByte:
        DB      #00
CanvasOutputDoneFlag:
        DB      #00
CanvasFrameLeft:
        DW      #0000
CanvasFrameTop:
        DW      #0000
CanvasFrameWidth:
        DW      #0000
CanvasFrameXRemaining:
        DW      #0000
CanvasRowsRemaining:
        DW      #0000
CanvasRowStartPage:
        DB      #00
CanvasRowStartPtr:
        DW      #0000
CanvasTransparentFlag:
        DB      #00
CanvasTransparentIndex:
        DB      #00
PaletteLoadPtr:
        DW      #0000
PaletteLoadIndex:
        DB      #00
AppIdBuffer:
        DS      11,#00
AppIdNetscape:
        DB      "NETSCAPE2.0"
GifVersion:
        DS      7,#00
GlobalPaletteBuffer:
        DS      #0300,#00
FrameIndexTable:
        DS      FRAME_ENTRY_SIZE * MAX_FRAME_INDEX,#00
CharBuffer:
        DB      #00,#00
InputFileNameFlag:
        DB      #00
InputFileName:
        DS      INPUT_FILENAME_MAX,#00

MsgBanner:
        DB      #0D,#0A,"GIFVIEW for Sprinter DSS",#0D,#0A,#00
MsgUsage:
        DB      "Usage: GIFVIEW.EXE <filename.gif> [-center] [-i] [-once] [-fast]",#0D,#0A,#00
MsgSelectedFile:
        DB      "File: ",#00
MsgFileSize:
        DB      "Size: #",#00
MsgPages:
        DB      "Pages: #",#00
MsgGifVersion:
        DB      "GIF version: ",#00
MsgGifWidth:
        DB      "Width: #",#00
MsgGifHeight:
        DB      "Height: #",#00
MsgGifPacked:
        DB      "Packed: #",#00
MsgGifGctPresent:
        DB      "Global color table: #",#00
MsgGifGctEntries:
        DB      "Global color table entries: #",#00
MsgGifGctBytes:
        DB      "Global color table bytes: #",#00
MsgGifPreparedPalette:
        DB      "Prepared global palette entries: #",#00
MsgGifFrames:
        DB      "Frames: #",#00
MsgGifFrameIndex:
        DB      "Frame index entries: #",#00
MsgGifFrameIndexOverflow:
        DB      "Frame index overflow: #",#00
MsgGifInterlace:
        DB      "Interlace: #",#00
MsgGifLocalColorTable:
        DB      "Local color table: #",#00
MsgGifTransparency:
        DB      "Transparency: #",#00
MsgGifDisposal2:
        DB      "Disposal restore background: #",#00
MsgGifDisposal3:
        DB      "Disposal restore previous: #",#00
MsgGifLoop:
        DB      "Loop extension: #",#00
MsgGifLoopCount:
        DB      "Loop count: #",#00
MsgLoading:
        DB      "Loading",#00
MsgParsing:
        DB      "OK. Parsing...",#0D,#0A,#00
MsgDecoding:
        DB      "Decoding first frame...",#0D,#0A,#00
MsgPressAnyKey:
        DB      "Press any key to exit.",#0D,#0A,#00
MsgOptCenter:
        DB      "Option: center",#0D,#0A,#00
MsgOptInfo:
        DB      "Option: info only",#0D,#0A,#00
MsgOptOnce:
        DB      "Option: play once",#0D,#0A,#00
MsgOptFast:
        DB      "Option: fast playback",#0D,#0A,#00
MsgNotImplemented:
        DB      "GIF parser/renderer implementation stage is next.",#0D,#0A,#00
MsgUnknownOption:
        DB      "Error: unknown option.",#0D,#0A,#00
MsgDuplicateInputFile:
        DB      "Error: multiple input files.",#0D,#0A,#00
MsgFileNameTooLong:
        DB      "Error: file name is too long.",#0D,#0A,#00
MsgOpenError:
        DB      "Error: cannot open file.",#0D,#0A,#00
MsgSeekError:
        DB      "Error: cannot seek file.",#0D,#0A,#00
MsgReadError:
        DB      "Error: cannot read file.",#0D,#0A,#00
MsgTooLarge:
        DB      "Error: GIF file is larger than 1.5 MB.",#0D,#0A,#00
MsgEmptyFile:
        DB      "Error: empty file.",#0D,#0A,#00
MsgNoMemory:
        DB      "Error: not enough memory.",#0D,#0A,#00
MsgMemoryMapError:
        DB      "Error: cannot map memory page.",#0D,#0A,#00
MsgVideoModeError:
        DB      "Error: cannot initialize video mode.",#0D,#0A,#00
MsgNotGif:
        DB      "Error: not a GIF file.",#0D,#0A,#00
MsgUnsupportedSize:
        DB      "Error: unsupported GIF canvas size.",#0D,#0A,#00
MsgInvalidGifBlock:
        DB      "Error: invalid GIF block stream.",#0D,#0A,#00
MsgFrameIndexOutOfRange:
        DB      "Error: frame index out of range.",#0D,#0A,#00
MsgUnsupportedLzwCodeSize:
        DB      "Error: unsupported GIF LZW code size.",#0D,#0A,#00
MsgInvalidLzwStream:
        DB      "Error: invalid GIF LZW stream.",#0D,#0A,#00
MsgCanvasOverflow:
        DB      "Error: decoded frame exceeds canvas buffer.",#0D,#0A,#00
MsgCrLf:
        DB      #0D,#0A,#00
