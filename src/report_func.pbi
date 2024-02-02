;------------------------------------------------------------------------
;- * proc_time_logger
;  * small tool to get the time of a running process
;  *
;- * include: report_func.pbi
;  *
;  * Copyright 2020 by Markus Mueller <markus.mueller.73@hotmail.de>
;  *
;  * For the license look in the main.pb file
;  *
;------------------------------------------------------------------------

;-******************** structures ********************
Structure _WND_REPORT_CERATOR
    id.i
    dte_from.i
    dte_to.i
    btn_create.i
    btn_cancel.i
EndStructure

;-******************** functions ********************
Procedure.i open_report_creator ( *w._WND_REPORT_CERATOR )
    
    Protected.l oldest_date = Date(), cur_date = Date()
    Protected.i h_json
    
    NewMap stats._STATISTICS()
    
    h_json = LoadJSON(#PB_Any, GetHomeDirectory() + #APP_STATS_FILE)
    If IsJSON(h_json)
        ExtractJSONMap(JSONValue(h_json), stats())
        FreeJSON(h_json)
        info("loaded JSON data with "+MapSize(stats())+" entries")
    Else
        err("Can't load statistics file. JSON error: " + JSONErrorMessage())
    EndIf
    
    ForEach stats()
        ForEach stats()\times()
            If stats()\times()\start_date <= oldest_date
                oldest_date = stats()\times()\start_date
            EndIf
        Next
    Next
    
    FreeMap(stats())
    
    With *w
        
        \id = OpenWindow(#PB_Any, #PB_Ignore, #PB_Ignore, 400, 160, #APP_NAME + " Report", #PB_Window_SystemMenu)
        If IsWindow(\id)
            
            SetWindowColor(\id, #Black)
            
            \dte_from = DateGadget(#PB_Any, 10, 20, 180, 30, "%dd.%mm.%yyyy", oldest_date)
            \dte_to   = DateGadget(#PB_Any, 210, 20, 180, 30, "%dd.%mm.%yyyy", 0)
            
            SetGadgetAttribute(\dte_from, #PB_Date_Minimum, oldest_date)
            SetGadgetAttribute(\dte_from, #PB_Date_Maximum, cur_date)
            SetGadgetAttribute(\dte_to  , #PB_Date_Minimum, oldest_date)
            SetGadgetAttribute(\dte_to  , #PB_Date_Maximum, cur_date)
            
            \btn_cancel = ButtonGadget(#PB_Any, 20, 100, 140, 30, "Cancel")
            \btn_create = ButtonGadget(#PB_Any, 240, 100, 140, 30, "Create")
            
            SetGadgetColor(\btn_cancel, #PB_Gadget_FrontColor, #Black)
            SetGadgetColor(\btn_cancel, #PB_Gadget_BackColor, #White)
            SetGadgetColor(\btn_create, #PB_Gadget_FrontColor, #White)
            SetGadgetColor(\btn_create, #PB_Gadget_BackColor, #Black)
            
        Else
            err("can't create report window")
            ProcedureReturn 0
        EndIf
        
    EndWith
    
    ProcedureReturn *w\id
    
EndProcedure

Procedure.l create_report ( date_min.l , date_max.l , report_file.s )
    
    Protected.i h_json, h_html, l = 1
    Protected.s cur_prg, date_mask = "%dd.%mm.%yy %hh:%ii:%ss", date_mask_diff = "%hh:%ii:%ss"
    
    NewMap stat_map._STATISTICS()
    NewList stat_lst._STATISTICS()
    
    h_json = LoadJSON(#PB_Any, GetHomeDirectory() + #APP_STATS_FILE)
    If IsJSON(h_json)
        ExtractJSONMap(JSONValue(h_json), stat_map())
        FreeJSON(h_json)
        info("loaded JSON data with "+MapSize(stat_map())+" entries")
    Else
        err("Can't load statistics file. JSON error: " + JSONErrorMessage())
    EndIf
    
    ForEach stat_map()
        AddElement(stat_lst())
        stat_lst()\exe_name = stat_map()\exe_name
        ForEach stat_map()\times()
            AddElement(stat_lst()\times())
            stat_lst()\times()\start_date = stat_map()\times()\start_date
            stat_lst()\times()\finish_date = stat_map()\times()\finish_date
        Next
    Next
    
    FreeMap(stat_map())
    
    SortStructuredList(stat_lst(), #PB_Sort_Ascending, OffsetOf(_STATISTICS\exe_name), #PB_String)
    ForEach stat_lst()
        SortStructuredList(stat_lst()\times(), #PB_Sort_Ascending, OffsetOf(_STAT_TIMES\start_date), #PB_Long)
    Next
    
    h_html = CreateFile(#PB_Any, report_file)
    If IsFile(h_html)
        
        WriteStringN(h_html, "<html>")
        WriteStringN(h_html, "<head>")
        WriteStringN(h_html, "<title>Application Monitoring</title>")
        WriteStringN(h_html, "<style>")
        WriteStringN(h_html, "table, th, td  {border: 1px solid black; border-spacing: 10px;}")
        WriteStringN(h_html, "th, td         {padding: 20px;}")
        WriteStringN(h_html, "</style>")
        WriteStringN(h_html, "</head>")
        WriteStringN(h_html, "<body>")
        WriteStringN(h_html, "<center><h1>Application Monitoring</h1></center>")
        WriteStringN(h_html, "<center><h2>from "+FormatDate(date_mask, date_min)+" 0:00:00 to "+FormatDate(date_mask, date_max)+" 23:59:59</h2></center>")
        WriteStringN(h_html, "<br>")
        
        ForEach stat_lst()
            
            WriteStringN(h_html, "<center><table>")
            WriteStringN(h_html, "<tr>")
            WriteStringN(h_html, "<th>Application</th><th>Date from</th><th>Date To</th><th>Duration</th>")
            WriteStringN(h_html, "</tr>")
            
            cur_prg = stat_lst()\exe_name
            
            ForEach stat_lst()\times()
                
                With stat_lst()\times()
                    
                    WriteStringN(h_html, "<tr>")
                    WriteStringN(h_html, "<td>"+cur_prg+"</td><td>"+FormatDate(date_mask, \start_date)+"</td><td>"+FormatDate(date_mask, \finish_date)+"</td><td>"+FormatDate(date_mask_diff, date_diff(\start_date, \finish_date))+"</td>")
                    WriteStringN(h_html, "</tr>")
                    
                EndWith
                
            Next
            
            WriteStringN(h_html, "</table></center>")
            WriteStringN(h_html, "<br>")
            
        Next
        
        WriteStringN(h_html, "<br><br>")
        WriteStringN(h_html, "</body>")
        WriteStringN(h_html, "</html>")
        
        CloseFile(h_html)
        
    Else
        err("loading creating file :: " + report_file)
        ProcedureReturn 0
    EndIf
    
    FreeList(stat_lst())
    
    ProcedureReturn 1
    
EndProcedure

; IDE Options = PureBasic 6.04 LTS (Windows - x64)
; CursorPosition = 114
; FirstLine = 80
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