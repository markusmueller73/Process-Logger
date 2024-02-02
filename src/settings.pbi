;------------------------------------------------------------------------
;- * proc_time_logger
;  * small tool to get the time of a running process
;  *
;- * include: settings.pbi
;  *
;  * Copyright 2020 by Markus Mueller <markus.mueller.73@hotmail.de>
;  *
;  * For the license look in the main.pb file
;  *
;------------------------------------------------------------------------

;-******************** constants ********************
#APP_CONFIG_KEY_DELAY   = "LoopDelay"
#APP_CONFIG_KEY_WINDOW  = "Window"

;-******************** structures ********************
Structure _PROGRAM_SETTINGS
    start_report_creator.l
    loop_delay.l
    List app_names.s()
EndStructure

;-******************** global vars ********************
Global settings._PROGRAM_SETTINGS

;-******************** functions ********************
Procedure.l save_settings ( *s._PROGRAM_SETTINGS )
    
    If FileSize(GetHomeDirectory() + #APP_SAVE_PATH) = -1
        CreateDirectory(GetHomeDirectory() + #APP_SAVE_PATH)
    EndIf
    
    Protected.i h_file = CreateFile(#PB_Any, GetHomeDirectory() + #APP_CONFIG_FILE)
    
    If IsFile(h_file)
        
        WriteStringN(h_file, "# " + #APP_NAME + " v" + Str(#APP_MAJOR) + "." + Str(#APP_MINOR) + "." + Str(#APP_MICRO) + " config file")
        WriteStringN(h_file, "# do NOT edit or modify this file")
        WriteStringN(h_file, "# " + #APP_NAME + " is free software, use it on your own risk")
        WriteStringN(h_file, "")
        WriteStringN(h_file, "# the loop delay setting set how often the program scans the processes (time in seconds)")
        WriteStringN(h_file, "# dont't set the interval time too short, a minute is a good interval time, five minutes are better")
        If *s = #Null
            WriteStringN(h_file, #APP_CONFIG_KEY_DELAY + "=60")
        Else
            WriteStringN(h_file, #APP_CONFIG_KEY_DELAY + "=" + Str(*s\loop_delay / 1000))
        EndIf
        WriteStringN(h_file, "")
        WriteStringN(h_file, "# from here is the list of executeables to monitor, the format looks like this:")
        WriteStringN(h_file, "# Window1=explorer.exe")
        WriteStringN(h_file, "# Window2=notepad.exe")
        WriteStringN(h_file, "# ... and so on, spaces between key or value and equal sign are possible")
        WriteStringN(h_file, "# without any 'Window' the program leaves immediatly")
        If *s <> #Null
            Protected.l n = 1
            ForEach *s\app_names()
                WriteStringN(h_file, #APP_CONFIG_KEY_WINDOW + Str(n) + "=" + *s\app_names())
                n+1
            Next
        EndIf
        WriteStringN(h_file, "")
        WriteStringN(h_file, "# eof")
        If *s = #Null
            MessageRequester(#APP_NAME, "Created a fresh config file:" + #CRLF$ + GetHomeDirectory() + #APP_CONFIG_FILE, #PB_MessageRequester_Info)
        EndIf
        
        CloseFile(h_file)
        
    EndIf
    
EndProcedure

Procedure.l load_settings ( *s._PROGRAM_SETTINGS )
    
    Protected.i line_pos, h_file
    Protected.s text_line, key, value
    
    If ListSize(*s\app_names()) > 0
        ClearList(*s\app_names())
    EndIf
    
    h_file = ReadFile(#PB_Any, GetHomeDirectory() + #APP_CONFIG_FILE)
    If IsFile(h_file)
        
        While Eof(h_file) = 0
            
            text_line = ReadString(h_file)
            
            If Len(text_line) < 2
                Continue
            EndIf
            
            If Left(text_line, 1) = ";" Or Left(text_line, 1) = "#"
                Continue
            EndIf
            
            key = Trim(StringField(text_line, 1, "="))
            value = Trim(StringField(text_line, 2, "="))
            
            text_line = #Null$
            
            If FindString(key, #APP_CONFIG_KEY_DELAY)
                *s\loop_delay = Val(value) * 1000
                Continue
            EndIf
            
            If FindString(key, #APP_CONFIG_KEY_WINDOW)
                AddElement(*s\app_names())
                *s\app_names() = RemoveString(value, Chr(34), #PB_String_NoCase, 1)
                Continue
            EndIf
            
        Wend
        
        CloseFile(h_file)
        
    Else
        
        *s\loop_delay = 3600
        
    EndIf
    
    If *s\loop_delay = 0
        *s\loop_delay = 3600
    EndIf
    
    ProcedureReturn 1
    
EndProcedure


; IDE Options = PureBasic 6.04 LTS (Windows - x64)
; CursorPosition = 31
; FirstLine = 10
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