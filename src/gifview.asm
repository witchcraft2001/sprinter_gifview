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
        LD      HL,MsgNotImplemented
        CALL    PrintString
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
        LD      A,H
        CALL    PrintHexByte
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
        CALL    SkipProgramName
        CALL    SkipSpaces
        LD      A,(HL)
        OR      A
        JP      Z,ShowUsage
        CALL    CopyFileName
        CALL    ParseOptions
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

ParseOptions:
        CALL    SkipSpaces
        LD      A,(HL)
        OR      A
        RET     Z
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
        JP      ParseOptions

ParseInfoOption:
        INC     HL
        CALL    RequireOptionDelimiter
        LD      A,(OptionFlags)
        OR      FLAG_INFO
        LD      (OptionFlags),A
        JP      ParseOptions

ParseOnceOption:
        CALL    ExpectOptionCharO
        CALL    ExpectOptionCharN
        CALL    ExpectOptionCharC
        CALL    ExpectOptionCharE
        CALL    RequireOptionDelimiter
        LD      A,(OptionFlags)
        OR      FLAG_ONCE
        LD      (OptionFlags),A
        JP      ParseOptions

ParseFastOption:
        CALL    ExpectOptionCharF
        CALL    ExpectOptionCharA
        CALL    ExpectOptionCharS
        CALL    ExpectOptionCharT
        CALL    RequireOptionDelimiter
        LD      A,(OptionFlags)
        OR      FLAG_FAST
        LD      (OptionFlags),A
        JP      ParseOptions

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
        LD      B,C
        LD      A,(MemoryBlockId)
        LD      C,Dss.SetWin3
        RST     Dss.Rst
        JR      NC,.mapped
        LD      HL,MsgMemoryMapError
        CALL    PrintString
        JP      ExitWithError
.mapped:
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
        CALL    PrintCrLf
        CALL    CloseInputFile
        CALL    PrintFileInfo
        RET

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
        RET

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
        LD      A,(SavedPage3)
        CP      #FF
        JR      Z,.page_restored
        OUT     (PAGE3),A
        LD      A,#FF
        LD      (SavedPage3),A
.page_restored:
        CALL    CloseInputFile
        LD      A,(MemoryAllocatedFlag)
        OR      A
        RET     Z
        XOR     A
        LD      (MemoryAllocatedFlag),A
        LD      A,(MemoryBlockId)
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
SavedPage3:
        DB      #FF
PagesNeeded:
        DB      #00
PageIndex:
        DB      #00
FileSizeHigh:
        DW      #0000
FileSizeLow:
        DW      #0000
CharBuffer:
        DB      #00,#00
InputFileName:
        DS      INPUT_FILENAME_MAX,#00

MsgBanner:
        DB      #0D,#0A,"GIFVIEW for Sprinter DSS",#0D,#0A,#00
MsgUsage:
        DB      "Usage: GIFVIEW.EXE <filename.gif> [-center] [-i] [-once] [-fast]",#0D,#0A,#00
MsgSelectedFile:
        DB      "File: ",#00
MsgFileSize:
        DB      "Size: $",#00
MsgPages:
        DB      "Pages: $",#00
MsgLoading:
        DB      "Loading",#00
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
MsgCrLf:
        DB      #0D,#0A,#00
