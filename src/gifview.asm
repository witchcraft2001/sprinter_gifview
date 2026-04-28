        INCLUDE "../include/exe_header.inc"
        INCLUDE "../include/sprinter_manual.inc"

GIFVIEW_ORG EQU #8200
GIFVIEW_STACK EQU DSS_EXE_DEFAULT_STACK

FLAG_CENTER EQU #01
FLAG_INFO   EQU #02
FLAG_ONCE   EQU #04
FLAG_FAST   EQU #08

INPUT_FILENAME_MAX EQU 64
CACHE_RUNTIME_BASE EQU #0100

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
        CALL    PrintStartupInfo
        LD      BC,#0100 * #00 + Dss.Exit
        RST     Dss.Rst

ExitWithError:
        LD      BC,#0100 * #0FF + Dss.Exit
        RST     Dss.Rst

PrintString:
        LD      C,Dss.PChars
        RST     Dss.Rst
        RET

PrintCrLf:
        LD      HL,MsgCrLf
        JP      PrintString

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

PrintStartupInfo:
        LD      HL,MsgSelectedFile
        CALL    PrintString
        LD      HL,InputFileName
        CALL    PrintString
        CALL    PrintCrLf
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
        LD      HL,MsgNotImplemented
        JP      PrintString

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
InputFileName:
        DS      INPUT_FILENAME_MAX,#00

MsgBanner:
        DB      #0D,#0A,"GIFVIEW for Sprinter DSS",#0D,#0A,#00
MsgUsage:
        DB      "Usage: GIFVIEW.EXE <filename.gif> [-center] [-i] [-once] [-fast]",#0D,#0A,#00
MsgSelectedFile:
        DB      "File: ",#00
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
MsgCrLf:
        DB      #0D,#0A,#00
