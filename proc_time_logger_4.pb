;------------------------------------------------------------------------
;- proc_time_logger
;- small tool to gett the time a process is running
;- main file
;- Copyright 2023 by Markus Mueller <markus.mueller.73 at hotmail dot de>
;- This program is free software
;------------------------------------------------------------------------

EnableExplicit

;-******************** constants ********************
#APP_NAME = "ProcTimeLogger"
#APP_MAJOR = 0
#APP_MINOR = 2
#APP_MICRO = #PB_Editor_BuildCount

#APP_CONFIG_FILE    = #APP_NAME + ".ini"
#APP_LOG_FILE       = #APP_NAME + ".log"
#APP_STATS_FILE     = #APP_NAME + ".dat"

#APP_CONFIG_KEY_DELAY   = "LoopDelay"
#APP_CONFIG_KEY_WINDOW  = "Window"

#APP_AUTOSAVE_INTERVAL = 3600; * 5

#MAX_LPCLASSNAME = 256

Enumeration 1
    #LOG_MSG_ERROR
    #LOG_MSG_SYSTEM
    #LOG_MSG_APP
    #LOG_MSG_DEBUG
EndEnumeration

Enumeration #PB_Event_FirstCustomValue
    #EVENT_SYSTEM_QUERIES_EXIT
    #EVENT_SYSTEM_EXITS
EndEnumeration
  
  
;-******************** structure ********************
Structure _PROGRAM_SETTINGS
    start_report_creator.l
    loop_delay.l
    List app_names.s()
EndStructure

Structure _MONITOR_APPS
    user_name.s
    exe_name.s
    date_from.l
    date_to.l
    running.l
EndStructure

Structure _MONITOR_APPS_PTR
    loop_delay.l
    List ma._MONITOR_APPS()
EndStructure

Structure _PROCESS
    pid.i
    exe.s
    usr.s
    dom.s
EndStructure

Structure SID
  Revision.b
  SubAuthorityCount.b
  *IdentifierAuthority.SID_IDENTIFIER_AUTHORITY
  SubAuthority.l[#ANYSIZE_ARRAY]
EndStructure

Structure TOKEN_USER
    *User.SID_AND_ATTRIBUTES
EndStructure

Structure _ENUM_WINDOWS
    title.s
    class.s
    pid.i
EndStructure

Structure _ENUM_WINDOWS_PTR
    List ew._ENUM_WINDOWS()
EndStructure

Structure _WND_SELECT_EXES
    id.i
    txt_select.i
    lst_exes.i
    btn_select.i
    btn_close.i
EndStructure

Structure _WND_REPORT_CERATOR
    id.i
    dte_from.i
    dte_to.i
    btn_create.i
    btn_cancel.i
EndStructure


;-******************** variables ********************

Define.l RETURN_VALUE
Global.l DATA_SAVED


;-******************** declarations ********************
Macro void : : EndMacro

Declare.b write_log_msg             ( type.l , text.s , line.s = "" , func.s = "" )
Declare.l process_program_params    ( args.l )
Declare.l load_config_file          ( *s._PROGRAM_SETTINGS )
Declare.l save_config_file          ( *s._PROGRAM_SETTINGS )
Declare.i window_callback           ( hWnd.i, uMsg.i, wParam.i, lParam.i )
Declare   thread_save_stats         ( *ma_ptr._MONITOR_APPS_PTR )
Declare   thread_monitor_apps       ( *ma_ptr._MONITOR_APPS_PTR )
Declare.l create_report             ( date_min.l , date_max.l , report_file.s )
Declare.i open_report_creator       ( *w._WND_REPORT_CERATOR )
Declare   select_exe_files          ( *w._WND_SELECT_EXES )
Declare.l main                      ( args.l )


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


;-******************** main loop ********************

RETURN_VALUE = main(CountProgramParameters())

;-******************** end of program ********************

End RETURN_VALUE


;-******************** functions ********************
Procedure .l main ( args.l )
    
    Protected.b do_loop = #True
    Protected.l start_function, date_min, date_max
    Protected.i main_wnd, wnd_evt, monitor_thread_id, stat_thread_id, conf_thread_id
    Protected   new_file$
    Protected   settings._PROGRAM_SETTINGS
    Protected   ma_ptr._MONITOR_APPS_PTR
    Protected   rwnd._WND_REPORT_CERATOR
    Protected   ewnd._WND_SELECT_EXES
    
    ;-- first process program params
    If args > 0
        start_function = process_program_params(args)
    EndIf
    
    ;-- if REPORT set in program params, the report creator starts, ...
    If start_function = 1
        
        main_wnd = open_report_creator( @rwnd )
        
    ElseIf start_function = 2
        
        save_config_file( #Null )
        End 0
        
    ElseIf start_function = 3
        
        If load_config_file(@settings)
            
            main_wnd = select_exe_files( @ewnd )
            
            If IsWindow(main_wnd)
                SortList(settings\app_names(), #PB_Sort_Ascending)
                ForEach settings\app_names()
                    AddGadgetItem(ewnd\lst_exes, -1, settings\app_names())
                Next
            Else
                MessageRequester(#APP_NAME, "Error, can't open selection window.", #PB_MessageRequester_Error)
                End 2
            EndIf
            
        EndIf
        
    Else ;-- otherwise the monitoring app
        
        ;--- load config file to get the apps to report
        If load_config_file(@settings)
            
            ;---- copy the app names to a list for the thread
            ForEach settings\app_names()
                AddElement(ma_ptr\ma())
                ma_ptr\ma()\exe_name  = settings\app_names()
                ma_ptr\ma()\user_name = UserName()
            Next
            ma_ptr\loop_delay = settings\loop_delay
            
            info("config loaded, found " + Str(ListSize(ma_ptr\ma())) + " apps to monitor")
            
        Else
            err("no app names in config file")
            MessageRequester(#APP_NAME, "There are 0 (NULL) applications to monitor. Exiting program.", #PB_MessageRequester_Warning)
            End 1
        EndIf
        
        ;--- open an invisible window
        main_wnd = OpenWindow(#PB_Any, 0, 0, 10, 10, #APP_NAME, #PB_Window_Invisible)
        If IsWindow(main_wnd)
            
            GetWindowThreadProcessId_(WindowID(main_wnd), @wnd_evt) ; only for testing
            info("window with system ID " + Str(WindowID(main_wnd)) + " and process ID: " + Str(wnd_evt) + " opened")
            
            ;---- this callback trys to hook the EXITWINDOWS messages, to save all data
            SetWindowCallback(@window_callback(), main_wnd)
            
            ;---- the thread to monitor the apps
            monitor_thread_id = CreateThread(@thread_monitor_apps(), @ma_ptr._MONITOR_APPS_PTR)
            If IsThread(monitor_thread_id)
                info("monitor thread starts successfully")
            Else
                err("can't create thread <monitor_thread_id>")
                MessageRequester(#APP_NAME, "Can't start monitoring thread. Exiting program.", #PB_MessageRequester_Error)
                End 2
            EndIf
            
        Else
            err("can't create main window")
            MessageRequester(#APP_NAME, "Can't create an invisible window. Exiting program.", #PB_MessageRequester_Error)
            End 3
        EndIf
        
    EndIf
    
    ;-- the main loop, all events get processed here
    Repeat
        
        wnd_evt = WaitWindowEvent()
        
        Select wnd_evt
                
            Case #PB_Event_CloseWindow
                do_loop = #False
                
            Case #EVENT_SYSTEM_QUERIES_EXIT ;---- this is a posted event, the window callback throws it when the msg WM_QUERIEEXITWINDOWS catched
                
                If IsThread(monitor_thread_id)
                    KillThread(monitor_thread_id)
                EndIf
                
                stat_thread_id = CreateThread(@thread_save_stats(), @ma_ptr._MONITOR_APPS_PTR)
                save_config_file(@settings)
                
            Case #EVENT_SYSTEM_EXITS ;---- this is a posted event, the window callback throws it when the msg WM_EXITWINDOWS catched
                
                If IsThread(stat_thread_id)
                    KillThread(stat_thread_id)
                EndIf
                
                If DATA_SAVED
                    info("successfully saved the collected data")
                Else
                    err("due to windows exit, some data is lost")
                EndIf
                
            Case #PB_Event_Gadget
                
                Select EventGadget()
                        
                    Case rwnd\btn_create
                        date_min = GetGadgetState(rwnd\dte_from)
                        date_max = GetGadgetState(rwnd\dte_to)
                        CloseWindow(rwnd\id)
                        info("creating report from " + FormatDate("%dd.%mm.%yyyy", date_min) + " to " + FormatDate("%dd.%mm.%yyyy", date_max))
                        
                        Protected.s report_name = GetTemporaryDirectory() + #APP_NAME + "_Report_" + Str(Date()) + ".html"
                        If create_report(date_min, date_max, report_name)
                            MessageRequester(#APP_NAME, "Report created, starting webbrowser." + #CRLF$ + "You can find the file later here:" + #CRLF$ + report_name, #PB_MessageRequester_Info)
                            RunProgram(report_name)
                        EndIf
                        
                        do_loop = #False
                        
                    Case rwnd\btn_cancel
                        do_loop = #False
                        
                    Case ewnd\btn_select
                        new_file$ = OpenFileRequester("Select exe to monitor", "*.exe", "Executeable (*.exe)|*.exe", 0)
                        If FileSize(new_file$) > 0
                            AddGadgetItem(ewnd\lst_exes, -1, GetFilePart(new_file$))
                        Else
                            MessageRequester(#APP_NAME, "No valid executeable.", #PB_MessageRequester_Warning)
                        EndIf
                        
                    Case ewnd\btn_close
                        Protected.l n
                        ClearList(settings\app_names())
                        For n = 0 To CountGadgetItems(ewnd\lst_exes)-1
                            AddElement(settings\app_names())
                            settings\app_names() = GetGadgetItemText(ewnd\lst_exes, n)
                        Next
                        save_config_file(@settings)
                        do_loop = #False
                        
                EndSelect
                
            Default
                If wnd_evt > 0 And Not IsWindow(rwnd\id)
                    Debug "uncatched window event: " + Str(wnd_evt)
                EndIf
                
        EndSelect
        
    Until do_loop = #False
    
    ;save_config_file(@settings)
    
    ProcedureReturn 0
    
EndProcedure

;- helper macro
Procedure.l date_diff( start_date.l , end_date.l = -1 )
    
    If end_date = -1 : end_date = Date() : EndIf
    ProcedureReturn end_date - start_date
    
EndProcedure

Procedure.l process_program_params ( args.l )
    
    Protected.l n
    Protected.s param
    
    For n = 0 To args-1
        
        param = UCase(ProgramParameter(n))
        
        If Left(param, 2) = "--"
            param = Mid(param, 3)
        EndIf
        
        If Left(param, 1) = "-" Or Left(param, 1) = "/"
            param = Mid(param, 2)
        EndIf
        
        Select param
                
            Case "REPORT"   : ProcedureReturn 1
                
            Case "CONFIG"   : ProcedureReturn 2
                
            Case "SELECT"   : ProcedureReturn 3
                
            Default         : ProcedureReturn 0
                
        EndSelect
        
    Next
    
    ProcedureReturn 0
    
EndProcedure

Procedure.l load_config_file ( *s._PROGRAM_SETTINGS )
    
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
        ProcedureReturn 0
        
    EndIf
    
    If *s\loop_delay = 0
        *s\loop_delay = 3600
    EndIf
    
    ProcedureReturn 1
    
EndProcedure

Procedure.l save_config_file ( *s._PROGRAM_SETTINGS )
    
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

Procedure.l cleanup_stats_list ( List ma._MONITOR_APPS() )
    
    If ListSize(ma()) = 0
        ProcedureReturn 0
    EndIf
    
    Protected.l i, j
    
    NewList tmp._MONITOR_APPS()
    CopyList(ma(), tmp())
    
    ForEach tmp()
        
        i = 0
        
        ForEach ma()
            
            If ma()\exe_name = tmp()\exe_name And ma()\date_from = tmp()\date_from And ma()\date_to = tmp()\date_to
                i + 1
            EndIf
            
            If i > 1
                DeleteElement(ma())
            EndIf
            
        Next
        
    Next
    
    FreeList(tmp())
    
    ProcedureReturn ListSize(ma())
    
EndProcedure

Procedure thread_save_stats( *ma_ptr._MONITOR_APPS_PTR )
    
    Protected.l n = 0, actual_date = Date()
    Protected.i h_json
    
    ForEach *ma_ptr\ma()
        If *ma_ptr\ma()\date_to = 0
            *ma_ptr\ma()\date_to = actual_date
        EndIf
    Next
    
    dbg("list cleaned up: " + Str(cleanup_stats_list(*ma_ptr\ma())) + " member")
    
    NewList old_ma._MONITOR_APPS()
    
    h_json = LoadJSON(#PB_Any, GetHomeDirectory() + #APP_STATS_FILE)
    If IsJSON(h_json)
        ExtractJSONList(JSONValue(h_json), old_ma())
        FreeJSON(h_json)
        dbg("JSON list 'old_ma()' has "+Str(ListSize(old_ma()))+" members")
    Else
        err("loading JSON file => " + JSONErrorMessage())        
    EndIf
    
    If (ListSize(old_ma()) + ListSize(*ma_ptr\ma())) = 0
        dbg("lists are empty, nothing to save")
        ProcedureReturn 0
    EndIf
    
    Dim tmp_ma._MONITOR_APPS(ListSize(old_ma())+ListSize(*ma_ptr\ma())-1)
    ForEach old_ma()
        tmp_ma(n) = old_ma()
        n+1
    Next
    ForEach *ma_ptr\ma()
        tmp_ma(n) = *ma_ptr\ma()
        n+1
    Next
    
    h_json = CreateJSON(#PB_Any)
    If IsJSON(h_json)
        InsertJSONArray(JSONValue(h_json), tmp_ma())
        SaveJSON(h_json, GetHomeDirectory() + #APP_STATS_FILE, #PB_JSON_PrettyPrint)
        dbg("JSON file saved, has "+Str(ArraySize(tmp_ma()))+" members")
        FreeJSON(h_json)
    Else
        err("creating JSON file => " + JSONErrorMessage())
    EndIf
    
    FreeList(old_ma())
    FreeArray(tmp_ma())
    
    DATA_SAVED = #True
    
EndProcedure

Procedure.l get_user_from_pid ( *p._PROCESS )
    
    Protected.i pid, info_len, byte_len, name_len, domain_len, sid_type_user = 1
    Protected.i proc_h, token_h
    Protected.s name, domain
    Protected   *token_user.TOKEN_USER; = AllocateStructure(TOKEN_USER) <- doesn't work, PB can't get right size of structure
    
    pid = *p\pid
    
    Macro cleanup
        CloseHandle_(token_h)
        CloseHandle_(proc_h)
    EndMacro
    
    proc_h = OpenProcess_(#PROCESS_QUERY_INFORMATION, #False, pid)
    
    If proc_h
        
        If OpenProcessToken_(proc_h, #TOKEN_QUERY, @token_h)
            
            GetTokenInformation_(token_h, #TokenUser, 0, 0, @byte_len)
            
            If byte_len > 0
                info_len = byte_len
                *token_user = AllocateMemory(byte_len)
            Else
                err("GetTokenInformation_")
                cleanup
                ProcedureReturn 0
            EndIf
            
            If GetTokenInformation_(token_h, #TokenUser, *token_user, info_len, @byte_len)
                
                LookupAccountSid_(#Null, @*token_user\user\sid, name, @name_len, domain, @domain_len, @sid_type_user)
                
                If name_len > 0 And domain_len > 0
                    name = Space(name_len + 1)
                    domain = Space(domain_len + 1)
                Else
                    err("LookupAccountSid_ -> result has length NULL")
                    cleanup
                    ProcedureReturn 0
                EndIf
                
                If LookupAccountSid_(#Null, @*token_user\user\sid, @name, @name_len, @domain, @domain_len, @sid_type_user)
                    
                    *p\usr = name
                    *p\dom = domain
                    
                Else
                    err("LookupAccountSid_")
                    cleanup
                    ProcedureReturn 0
                EndIf
                
            Else
                err("GetTokenInformation_")
                cleanup
                ProcedureReturn 0
            EndIf
            
        Else
            err("OpenProcessToken_")
            CloseHandle_(proc_h)
            ProcedureReturn 0
        EndIf
        
    Else
        err("OpenProcess_")
        ProcedureReturn 0
    EndIf
    
    cleanup
    
    FreeMemory(*token_user)
    
    ProcedureReturn 1
    
EndProcedure

Procedure.l get_process_list ( List p._PROCESS() )
    
    Protected.i snapshot, result
    NewList     pe32.PROCESSENTRY32()
    
    If ListSize(p()) > 0
        ClearList(p())
    EndIf
    
    snapshot = CreateToolhelp32Snapshot_(#TH32CS_SNAPPROCESS, 0)
    If snapshot = 0
        err("CreateToolhelp32Snapshot_")
        ProcedureReturn 0
    EndIf
    
    AddElement(pe32())
    pe32()\dwSize = SizeOf(PROCESSENTRY32)
    
    result = Process32First_(snapshot, @pe32())
    If result
        While result <> 0
            AddElement(pe32())
            pe32()\dwSize = SizeOf(PROCESSENTRY32)
            result = Process32Next_(snapshot, @pe32())
        Wend
        DeleteElement(pe32())
    Else
        err("Process32First_")
        ProcedureReturn 0
    EndIf
    
    ForEach pe32()
        
        AddElement(p())
        p()\pid = pe32()\th32ProcessID
        p()\exe = PeekS(@pe32()\szExeFile)
        
        ;get_user_from_pid(@p())
        
    Next
    
    FreeList(pe32())
    
    ProcedureReturn ListSize(p())
    
EndProcedure

Procedure thread_monitor_apps ( *ma_ptr._MONITOR_APPS_PTR )
    
    Protected.b prg_found
    Protected.l counter, cur_date
    Protected.i thread_save_stats
    Protected.s cur_exe, usr_name = UserName()
    
    NewList tmp_ma._MONITOR_APPS()
    NewList proc._PROCESS()
    
    CopyList(*ma_ptr\ma(), tmp_ma()) : ClearList(*ma_ptr\ma())
    
    Repeat 
        
        Delay ( *ma_ptr\loop_delay ) : counter + 1
        
        If get_process_list(proc())
            
            cur_date = Date()
        
            ForEach tmp_ma()
                
                With tmp_ma()
                    
                    cur_exe = \exe_name
                    
                    ForEach proc()
                        
                        prg_found = 0
                        
;                         If CompareMemoryString(@usr_name, @proc()\usr) <> #PB_String_Equal
;                             DeleteElement(proc(), 1)
;                             Continue
;                         EndIf
                        If CompareMemoryString(@cur_exe, @proc()\exe, #PB_String_NoCase) =  #PB_String_Equal
                            
                            prg_found = 1
                            
                            If \date_from = 0 And \running = #False
                                \date_from = cur_date
                                info("app '"+cur_exe+"' found, start monitoring")
                            EndIf;\date_from = 0 And \running = #False
                            
                            \running = #True
                            
                            Break;ForEach ewp\ew()
                            
                        EndIf;FindString(ewp\ew()\title, \prg_name, 1, #PB_String_NoCase) Or FindString(ewp\ew()\class, \prg_name, 1, #PB_String_NoCase)
                        
                    Next;ForEach ewp\ew()
                    
                    If prg_found  = 0
                        
                        If \running
                            
                            If \date_from And \date_to = 0
                                \date_to = cur_date
                                info("app '"+cur_exe+"' not running anymore, runs for " + FormatDate("%hh:%ii:%ss", date_diff(\date_from, cur_date)))
                            EndIf
                            
                            AddElement(*ma_ptr\ma())
                            *ma_ptr\ma() = tmp_ma()
                            
                            \date_from  = 0
                            \date_to    = 0
                            \running    = #False
                            
                        EndIf;\running
                        
                    EndIf;prg_found  = 0
                    
                EndWith
                
;                 If counter = 1
;                     If IsThread(thread_save_stats) = 0
;                         DATA_SAVED = #False
;                         thread_save_stats = CreateThread(@thread_save_stats(), *ma_ptr)
;                     EndIf;IsThread(thread_save_stats) = 0
;                     counter = 0
;                 EndIf;counter = 1
                
            Next;ForEach *ma_ptr\ma()
            
        EndIf;EnumWindows_(@list_windows_callback(), @ewp)
        
    ForEver
    
EndProcedure

Procedure.i window_callback(hWnd.i, uMsg.i, wParam.i, lParam.i) 
    
    If uMsg = #WM_QUERYENDSESSION
        
        If IsThread(monitor_thread_id)
            KillThread(monitor_thread_id)
        EndIf
        
        thread_save_stats(@ma_ptr._MONITOR_APPS_PTR)
        
        If save_config_file(@settings)
            DATA_SAVED = #True
        Else            
            DATA_SAVED = #False
        EndIf
        
        sys("message to end the session, cleaning up")
        
        ProcedureReturn 1
        
    ElseIf uMsg = #WM_ENDSESSION
        
        PostEvent(#EVENT_SYSTEM_EXITS)
        sys("end of session")
        
        ProcedureReturn 0
        
    EndIf 
    
    ProcedureReturn #PB_ProcessPureBasicEvents 
    
EndProcedure

Procedure.b write_log_msg( type.l , text.s , line.s = "" , func.s = "" )
    
    Protected.i h_file, last_error
    Protected.s log_type, last_error_msg
    
    If FileSize(GetHomeDirectory() + #APP_LOG_FILE) <= 0
        h_file = CreateFile(#PB_Any, GetHomeDirectory() + #APP_LOG_FILE)
        If IsFile(h_file)
            WriteStringN(h_file, #APP_NAME + " v" + Str(#APP_MAJOR) + "." + Str(#APP_MINOR) + "." + Str(#APP_MICRO) + " logfile, created: " + FormatDate("%hh:%ii:%ss %dd.%mm.%yyyy", Date()))
            WriteStringN(h_file, "")
            CloseFile(h_file)
        Else
            MessageRequester(#APP_NAME, "Error - can't open log file.", #PB_MessageRequester_Error)
            End 1
        EndIf
    EndIf
    
    Select type
        Case #LOG_MSG_DEBUG     : log_type = "[DEBUG]"
        Case #LOG_MSG_ERROR     : log_type = "[ERROR]"
        Case #LOG_MSG_SYSTEM    : log_type = "[SYSTEM]"
        Default                 : log_type = "[INFO]"
    EndSelect
    
    last_error = GetLastError_()
    If last_error > 0
        last_error_msg = ""
    EndIf
    
    
    h_file = OpenFile(#PB_Any, GetHomeDirectory() + #APP_LOG_FILE, #PB_File_Append|#PB_File_SharedRead|#PB_File_SharedWrite)
    
    If IsFile(h_file)
        If func
            WriteStringN(h_file, FormatDate("[%hh:%ii:%ss]", Date()) + " :: <" + func + "> :: "  + log_type + " :: " + text)
            Debug "<" + func + "> :: "  + log_type + " :: " + text
        Else
            WriteStringN(h_file, FormatDate("[%hh:%ii:%ss]", Date()) + " :: " + log_type + " :: " + text)
            Debug log_type + " :: " + text
        EndIf
        CloseFile(h_file)
    Else
        MessageRequester(#APP_NAME, "Error - can't open log file.", #PB_MessageRequester_Error)
        End 1
    EndIf
    
EndProcedure

Procedure.l create_report ( date_min.l , date_max.l , report_file.s )
    
    Protected.i h_json, h_html, l = 1
    Protected.s cur_prg, date_mask = "%dd.%mm.%yy %hh:%ii:%ss", date_mask_diff = "%hh:%ii:%ss"
    
    NewList ma._MONITOR_APPS()
    
    h_json = LoadJSON(#PB_Any, GetHomeDirectory() + #APP_STATS_FILE)
    If IsJSON(h_json)
        ExtractJSONList(JSONValue(h_json), ma())
        FreeJSON(h_json)
        dbg("JSON list 'ma()' has "+Str(ListSize(ma()))+" members")
    Else
        err("loading JSON file => " + JSONErrorMessage())        
        ProcedureReturn 0
    EndIf
    
    ;cleanup_stats_list(ma())
    
    SortStructuredList(ma(), #PB_Sort_Ascending, OffsetOf(_MONITOR_APPS\date_from), #PB_Long)
    SortStructuredList(ma(), #PB_Sort_Ascending, OffsetOf(_MONITOR_APPS\exe_name), #PB_String)
    
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
        
        ForEach ma()
            
            If cur_prg <> ma()\exe_name
                If l > 1
                    WriteStringN(h_html, "</table></center>")
                    WriteStringN(h_html, "<br>")
                EndIf
                WriteStringN(h_html, "<center><table>")
                WriteStringN(h_html, "<tr>")
                WriteStringN(h_html, "<th>Application</th><th>Date from</th><th>Date To</th><th>Duration</th>")
                WriteStringN(h_html, "</tr>")
                cur_prg = ma()\exe_name
            EndIf
            
            WriteStringN(h_html, "<tr>")
            WriteStringN(h_html, "<td>"+ma()\exe_name+"</td><td>"+FormatDate(date_mask, ma()\date_from)+"</td><td>"+FormatDate(date_mask, ma()\date_to)+"</td><td>"+FormatDate(date_mask_diff, date_diff(ma()\date_from, ma()\date_to))+"</td>")
            WriteStringN(h_html, "</tr>")
            
            l + 1
            
        Next
        
        WriteStringN(h_html, "</table></center>")
        
        WriteStringN(h_html, "</body>")
        WriteStringN(h_html, "</html>")
        
        CloseFile(h_html)
        
    Else
        err("loading creating file :: " + report_file)
        ProcedureReturn 0
    EndIf
    
    FreeList(ma())
    ProcedureReturn 1
    
EndProcedure

Procedure select_exe_files ( *w._WND_SELECT_EXES )
    
    With *w
        
        \id = OpenWindow(#PB_Any, #PB_Ignore, #PB_Ignore, 300, 480, #APP_NAME + " - select executeables", #PB_Window_SystemMenu)
        If IsWindow(\id)
            
            \txt_select = TextGadget(#PB_Any, 10, 10, 280, 30, "Select executeables to monitor:")
            \lst_exes   = ListViewGadget(#PB_Any, 10, 50, 280, 380)
            \btn_select = ButtonGadget(#PB_Any, 10, 440, 120, 30, "Select...")
            \btn_close  = ButtonGadget(#PB_Any, 170, 440, 120, 30, "Quit")
            
        Else
            err("can't create selection window")
            ProcedureReturn 0
        EndIf
        
    EndWith
    
    ProcedureReturn *w\id
    
EndProcedure

Procedure.i open_report_creator ( *w._WND_REPORT_CERATOR )
    
    Protected.l oldest_date = Date(), cur_date = Date()
    Protected.i h_json = LoadJSON(#PB_Any, GetHomeDirectory() + #APP_STATS_FILE)
    
    If IsJSON(h_json)
        NewList ma._MONITOR_APPS()
        ExtractJSONList(JSONValue(h_json), ma())
        FreeJSON(h_json)
        ForEach ma()
            If oldest_date > ma()\date_from
                oldest_date = ma()\date_from
            EndIf
        Next
        FreeList(ma())
    EndIf
    
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


; IDE Options = PureBasic 6.02 LTS (Windows - x64)
; CursorPosition = 792
; FirstLine = 324
; Folding = 0Bkw
; Optimizer
; EnableThread
; EnableXP
; EnableUser
; Executable = proc_time_logger.exe
; CommandLine = --select
; EnablePurifier
; EnableCompileCount = 84
; EnableBuildCount = 5
; EnableExeConstant