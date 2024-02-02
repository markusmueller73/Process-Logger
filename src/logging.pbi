;------------------------------------------------------------------------
;- * proc_time_logger
;  * small tool to get the time of a running process
;  *
;- * include: logging.pbi
;  *
;  * Copyright 2020 by Markus Mueller <markus.mueller.73@hotmail.de>
;  *
;  * For the license look in the main.pb file
;  *
;------------------------------------------------------------------------

;-******************** constants ********************
Enumeration 1
    #LOG_MSG_ERROR
    #LOG_MSG_SYSTEM
    #LOG_MSG_APP
    #LOG_MSG_DEBUG
EndEnumeration

;-******************** function ********************
Procedure.b write_log_msg( type.l , text.s , line.s = "" , func.s = "" )
    
    Static.b init
    
    Protected.i h_file, last_error
    Protected.s log_type, last_error_msg
    
    If init = 0
        
        If FileSize(GetHomeDirectory() + #APP_SAVE_PATH) = -1
            CreateDirectory(GetHomeDirectory() + #APP_SAVE_PATH)
        EndIf
        
        If FileSize(GetHomeDirectory() + #APP_LOG_FILE) <= 0
            h_file = CreateFile(#PB_Any, GetHomeDirectory() + #APP_LOG_FILE)
            If IsFile(h_file)
                WriteStringN(h_file, #APP_NAME + " v" + Str(#APP_MAJOR) + "." + Str(#APP_MINOR) + "." + Str(#APP_MICRO) + " logfile, created: " + FormatDate("%hh:%ii:%ss %dd.%mm.%yyyy", Date()))
                WriteStringN(h_file, "")
                CloseFile(h_file)
            Else
                MessageRequester(#APP_NAME, "Error - can't create log file.", #PB_MessageRequester_Error)
                End 1
            EndIf
        EndIf
        
        init = 1
        
    EndIf
    
    Select type
        Case #LOG_MSG_DEBUG     : log_type = "[DEBUG]"
        Case #LOG_MSG_ERROR     : log_type = "[ERROR]"
        Case #LOG_MSG_SYSTEM    : log_type = "[SYSTEM]"
        Default                 : log_type = "[INFO]"
    EndSelect
    
    If func = #Null$ : func = "main" : EndIf
    CompilerIf #PB_Compiler_Debugger
        Debug "<" + func + "> :: "  + log_type + " :: " + text
    CompilerElse
        If type = #LOG_MSG_DEBUG : ProcedureReturn 0 : EndIf
    CompilerEndIf
    
;     last_error = GetLastError_()
;     If last_error > 0
;         last_error_msg = ""
;     EndIf
    
    h_file = OpenFile(#PB_Any, GetHomeDirectory() + #APP_LOG_FILE, #PB_File_Append|#PB_File_SharedRead|#PB_File_NoBuffering)
    
    If IsFile(h_file)
        WriteStringN(h_file, FormatDate("[%hh:%ii:%ss]", Date()) + " :: <" + func + "> :: "  + log_type + " :: " + text)
        CloseFile(h_file)
    Else
        MessageRequester(#APP_NAME, "Error - can't open log file.", #PB_MessageRequester_Error)
        End -1
    EndIf
    
    If type = #LOG_MSG_ERROR
        MessageRequester(#APP_NAME, "Error in function " + func + "() near line " + line + #CRLF$ + #CRLF$ + text, #PB_MessageRequester_Error)
        End -1
    EndIf
    
    ProcedureReturn 1
    
EndProcedure

;-******************** macros ********************
Macro log_msg ( type , text , line = -1 )
    If #PB_Compiler_Procedure <> ""
        write_log_msg(type, text, Str(line), #PB_Compiler_Procedure)
    Else
        write_log_msg(type, text, Str(line))
    EndIf
EndMacro
Macro dbg( text ) : log_msg(#LOG_MSG_DEBUG, text, #PB_Compiler_Line) : EndMacro
Macro err( text ) : log_msg(#LOG_MSG_ERROR, text, #PB_Compiler_Line) : EndMacro
Macro sys( text ) : log_msg(#LOG_MSG_SYSTEM, text) : EndMacro
Macro info( text ) : log_msg(#LOG_MSG_APP, text) : EndMacro


; IDE Options = PureBasic 6.04 LTS (Windows - x64)
; CursorPosition = 50
; FirstLine = 35
; Folding = --
; Optimizer
; EnableXP
; EnableUser
; DPIAware
; UseMainFile = main.pb
; EnablePurifier
; EnableCompileCount = 0
; EnableBuildCount = 0
; EnableExeConstant