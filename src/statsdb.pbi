;------------------------------------------------------------------------
;- * proc_time_logger
;  * small tool to get the time of a running process
;  *
;- * include: statsdb.pbi
;  *
;  * Copyright 2020 by Markus Mueller <markus.mueller.73@hotmail.de>
;  *
;  * For the license look in the main.pb file
;  *
;------------------------------------------------------------------------

;-******************** structures ********************
Structure _STAT_TIMES
    start_date.l
    finish_date.l
EndStructure

Structure _STATISTICS
    exe_name.s
    List times._STAT_TIMES()
EndStructure

Structure _STATISTICS_PTR
    List stats._STATISTICS()
EndStructure

;-******************** global vars ********************
Global NewMap STATISTIC._STATISTICS()

;-******************** functions ********************
Procedure.l save_statistics ( void ) ; uses global > STATISTIC._STATISTICS()
    
    Protected.l cur_date = Date()
    Protected.i h_file, h_json
    Protected   tmp$
    
    NewMap old_stats._STATISTICS()
    NewMap new_stats._STATISTICS()
    
    ;LockMutex(sync_mutex)
    CopyMap(STATISTIC(), new_stats())
    ;UnlockMutex(sync_mutex)
    
    
    If FileSize(GetHomeDirectory() + #APP_STATS_FILE) < 0
        h_file = CreateFile(#PB_Any, GetHomeDirectory() + #APP_STATS_FILE)
        If IsFile(h_file)
            info("empty stats file created")
            WriteStringN(h_file, "{}")
            CloseFile(h_file)
        Else
            err("Can't create file: " + GetHomeDirectory() + #APP_STATS_FILE)
        EndIf
    EndIf
    
    h_json = LoadJSON(#PB_Any, GetHomeDirectory() + #APP_STATS_FILE)
    If IsJSON(h_json)
        ExtractJSONMap(JSONValue(h_json), old_stats())
        FreeJSON(h_json)
        info("loaded JSON data with "+MapSize(old_stats())+" entries")
    Else
        err("Can't load statistics file. JSON error: " + JSONErrorMessage())
    EndIf
    
    ForEach new_stats()
        tmp$ = new_stats()\exe_name
        If Not FindMapElement(old_stats(), tmp$)
            AddMapElement(old_stats(), tmp$)
            old_stats(tmp$)\exe_name = tmp$
            info("found new entry: " + tmp$)
        EndIf
        AddElement(old_stats(tmp$)\times())
        old_stats(tmp$)\times()\start_date = new_stats()\times()\start_date
        If new_stats()\times()\finish_date = 0
            new_stats()\times()\finish_date = cur_date
        EndIf
        old_stats(tmp$)\times()\finish_date = new_stats()\times()\finish_date
        tmp$ = #Null$
        info("added data: " + new_stats()\exe_name)
    Next
    
    h_json = CreateJSON(#PB_Any)
    If IsJSON(h_json)
        InsertJSONMap(JSONValue(h_json), old_stats())
        info("added data to JSON, "+MapSize(old_stats())+" entries")
    Else
        err("Can't create JSON structure <h_json>.")
    EndIf
    
    If SaveJSON(h_json, GetHomeDirectory() + #APP_STATS_FILE, #PB_JSON_PrettyPrint)
        info("updated stats file")
    Else
        err("Can't save statistics file: " + GetHomeDirectory() + #APP_STATS_FILE)
    EndIf
    
    FreeJSON(h_json)
    FreeMap(old_stats())
    FreeMap(new_stats())
    
    ProcedureReturn 1
    
EndProcedure

; IDE Options = PureBasic 6.04 LTS (Windows - x64)
; CursorPosition = 70
; FirstLine = 43
; Folding = -
; Optimizer
; EnableThread
; EnableXP
; EnableUser
; DPIAware
; UseMainFile = main.pb
; EnablePurifier
; EnableCompileCount = 0
; EnableBuildCount = 0
; EnableExeConstant