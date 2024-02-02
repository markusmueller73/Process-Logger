;------------------------------------------------------------------------
;- * proc_time_logger
;  * small tool to get the time of a running process
;  *
;- * include: header.pbi
;  *
;  * Copyright 2020 by Markus Mueller <markus.mueller.73@hotmail.de>
;  *
;  * For the license look in the main.pb file
;  *
;------------------------------------------------------------------------

;-******************** constants ********************
#APP_NAME = "ProcTimeLogger"
#APP_SHORT = "proc_timer"
#APP_MAJOR = 0
#APP_MINOR = 4
#APP_MICRO = #PB_Editor_BuildCount

#APP_SAVE_PATH      = #APP_NAME + #PS$
#APP_CONFIG_FILE    = #APP_SAVE_PATH + #APP_SHORT + ".ini"
#APP_LOG_FILE       = #APP_SAVE_PATH + #APP_SHORT + ".log"
#APP_STATS_FILE     = #APP_SAVE_PATH + #APP_SHORT + ".dat"

#APP_AUTOSAVE_INTERVAL = 60; in seconds

#MAX_LPCLASSNAME = 256

Enumeration APP_FUNCTION
    #APP_FUNC_DEFAULT
    #APP_FUNC_REPORT
    #APP_FUNC_CONFIG
    #APP_FUNC_SELECT
    #APP_FUNC_HELP
EndEnumeration

Enumeration #PB_Event_FirstCustomValue
    #EVENT_SYSTEM_QUERIES_EXIT
    #EVENT_SYSTEM_EXITS
EndEnumeration

;-******************** structures ********************
; Structure _MONITOR_APPS
;     user_name.s
;     exe_name.s
;     date_from.l
;     date_to.l
;     running.l
; EndStructure
; 
; Structure _MONITOR_APPS_PTR
;     loop_delay.l
;     List ma._MONITOR_APPS()
; EndStructure

;-******************** global vars ********************
Global.i data_saved, sync_mutex = CreateMutex()
Global.i monitor_thread_id
;Global   *ma_ptr._MONITOR_APPS_PTR

;-******************** global macros ********************
Macro void : : EndMacro

;-******************** global functions ********************
Procedure.l date_diff( start_date.l , end_date.l = -1 )
    
    If end_date = -1 : end_date = Date() : EndIf
    ProcedureReturn end_date - start_date
    
EndProcedure

Procedure.i get_data_icon ( *mem_addr )
    
    Protected.a d
    Protected.w w, h, x, y
    Protected.l c
    Protected.i img
    
    Restore SYSTRAYICON
    
    Read.w w : Read.w h : Read.a d
    
    img = CreateImage(#PB_Any, w, h, d)
    
    If IsImage(img)
        
        StartDrawing(ImageOutput(img))
        
        DrawingMode(#PB_2DDrawing_AllChannels)
        
        For y = 0 To h-1
            For x = 0 To w-1
                Read.l c : Plot(x,y,c)
            Next
        Next
        
        StopDrawing()
        
    Else
        ProcedureReturn -1
    EndIf
    
    ProcedureReturn img
    
EndProcedure

;-******************** declarations ********************
XIncludeFile "logging.pbi"
XIncludeFile "settings.pbi"
XIncludeFile "select_exes.pbi"
XIncludeFile "statsdb.pbi"
XIncludeFile "monitoring.pbi"
XIncludeFile "report_func.pbi"

;-******************** data section ********************
DataSection
    SYSTRAYICON:
    Data.w 16, 16
    Data.a 32
    Data.l $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000
    Data.l $00000000, $00000000, $00000000, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $00000000
    Data.l $00000000, $00000000, $FF4C4C4C, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FF4C4C4C, $00000000
    Data.l $00000000, $FF4C4C4C, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FF4C4C4C, $00000000
    Data.l $00000000, $FF4C4C4C, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FF4C4C4C, $00000000
    Data.l $00000000, $FF4C4C4C, $FFFFFFFF, $FF000000, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FF000000, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FF000000, $FF000000, $FFFFFFFF, $FF4C4C4C, $00000000
    Data.l $00000000, $FF4C4C4C, $FFFFFFFF, $FF000000, $FFFFFFFF, $FFFFFFFF, $FF000000, $FFFFFFFF, $FF000000, $FFFFFFFF, $FF000000, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FF4C4C4C, $00000000
    Data.l $00000000, $FF4C4C4C, $FFFFFFFF, $FF000000, $FFFFFFFF, $FFFFFFFF, $FF000000, $FFFFFFFF, $FF000000, $FFFFFFFF, $FF000000, $FF000000, $FF000000, $FFFFFFFF, $FF4C4C4C, $00000000
    Data.l $00000000, $FF4C4C4C, $FFFFFFFF, $FF000000, $FFFFFFFF, $FFFFFFFF, $FF000000, $FFFFFFFF, $FF000000, $FFFFFFFF, $FF000000, $FFFFFFFF, $FF000000, $FFFFFFFF, $FF4C4C4C, $00000000
    Data.l $00000000, $FF4C4C4C, $FFFFFFFF, $FF000000, $FFFFFFFF, $FFFFFFFF, $FF000000, $FFFFFFFF, $FF000000, $FFFFFFFF, $FF000000, $FFFFFFFF, $FF000000, $FFFFFFFF, $FF4C4C4C, $00000000
    Data.l $00000000, $FF4C4C4C, $FFFFFFFF, $FF000000, $FF000000, $FFFFFFFF, $FFFFFFFF, $FF000000, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FF000000, $FFFFFFFF, $FFFFFFFF, $FF4C4C4C, $00000000
    Data.l $00000000, $FF4C4C4C, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FF4C4C4C, $00000000
    Data.l $00000000, $FF4C4C4C, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FF4C4C4C, $00000000
    Data.l $00000000, $FF4C4C4C, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FF4C4C4C, $00000000
    Data.l $00000000, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $FF4C4C4C, $00000000
    Data.l $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000
EndDataSection

; IDE Options = PureBasic 6.04 LTS (Windows - x64)
; CursorPosition = 88
; FirstLine = 56
; Folding = -
; Optimizer
; EnableXP
; EnableUser
; DPIAware
; UseMainFile = main.pb
; EnablePurifier
; EnableCompileCount = 0
; EnableBuildCount = 0
; EnableExeConstant