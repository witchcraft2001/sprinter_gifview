        INCLUDE "/Users/dmitry/dev/zx/sprinter/sprinter_ai_doc/manual/include/bios_equ.inc"
        INCLUDE "/Users/dmitry/dev/zx/sprinter/sprinter_ai_doc/manual/include/dss_equ.inc"
        INCLUDE "/Users/dmitry/dev/zx/sprinter/sprinter_ai_doc/manual/include/ports.inc"

; Subfunction bytes used by these recovered programs. The low-byte function
; constants come from the manual include files above; keep 16-bit DSS loads as
; #0100 * subfunction + Dss.Function.
Dss.MoveFp.FromStart     EQU #00
Dss.MoveFp.FromCurrent   EQU #01
Dss.MoveFp.FromEnd       EQU #02
Dss.Find.DosName         EQU #01
Dss.ExPath.GSwitch       EQU #07
Dss.Erase                EQU #0D ; historical DSS name, equivalent command alias before Dss.Delete

; BIOS/Mouse constants documented in manual chapters but not present in the
; compact include file.
Bios.SetPalette          EQU #0A4
Bios.Mouse_Rst           EQU #30
Bios.Mouse_Init          EQU #00
Bios.Mouse_HideCursor    EQU #02
Bios.Mouse_Read          EQU #03
