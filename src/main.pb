;------------------------------------------------------------------------
;- * proc_time_logger
;  * small tool to get the time of a running process
;  *
;- * main file
;  *
;  * Copyright 2020 by Markus Mueller <markus.mueller.73@hotmail.de>
;  *
;  * This program is free software; you can redistribute it and/or modify
;  * it under the terms of the GNU General Public License As published by
;  * the Free Software Foundation; either version 2 of the License, or
;  * (at your option) any later version.
;  *
;  * This program is distributed in the hope that it will be useful,
;  * but WITHOUT ANY WARRANTY; without even the implied warranty of
;  * MERCHANTABILITY or FITNESS for A PARTICULAR PURPOSE.  See the
;  * GNU General Public License for more details.
;  *
;  * You should have received a copy of the GNU General Public License
;  * along with this program; if not, write to the Free Software
;  * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
;  * MA 02110-1301, USA.
;  *
;------------------------------------------------------------------------

EnableExplicit

CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    If OSVersion() < #PB_OS_Windows_XP
        MessageRequester("Incompatible OS", "The program runs only with Windows XP or higher.")
        End 1
    EndIf
CompilerElse
    MessageRequester("Incompatible OS", "The program only runs on a Windows machine.")
    End 2
CompilerEndIf

;-******************** includes ********************
XIncludeFile "header.pbi"

;-******************** declarations ********************
Declare.l process_program_params ( args.l )
Declare.i main_window_callback   ( hWnd.i, uMsg.i, wParam.i, lParam.i )

;-******************** variables ********************
Define.b do_loop = #True
Define.l n, m, date_min, date_max
Define.i main_wnd, main_tray, wnd_evt
Define   new_file$
Define   ma_ptr._MONITOR_APPS_PTR

;-******************** init ********************
info("******************** fresh start @ " + FormatDate("%yyyy-%mm-%dd", Date()) + " ********************")
If FileSize(GetHomeDirectory() + #APP_SAVE_PATH) <> -2 ; check if directory exists
    If CreateDirectory(GetHomeDirectory() + #APP_SAVE_PATH)
        info("created config directory: " + GetHomeDirectory() + #APP_SAVE_PATH)
    Else
        err("Can't create a directory in '"+GetHomeDirectory()+"'.")
    EndIf
EndIf

Select process_program_params(CountProgramParameters()) ; check program params
        
    Case #APP_FUNC_HELP
        MessageRequester(#APP_NAME, #APP_NAME + " can run with tho following parameters:" + #CRLF$ + #CRLF$ + "--config      to create a fresh config file" + #CRLF$ + "--report      to create a report" + #CRLF$ + "--select      to start the selection of the apps to monitor" + #CRLF$ + #CRLF$ + "Or start it without any aparameter, to monitor the apps.")
        End 0
        
    Case #APP_FUNC_REPORT
        Define rwnd._WND_REPORT_CERATOR
        main_wnd = open_report_creator( @rwnd )
        If Not IsWindow(main_wnd)
            err("Can't open report window.")
        EndIf
        
    Case #APP_FUNC_SELECT
        Define ewnd._WND_SELECT_EXES
        If load_settings(@settings)
            
            main_wnd = select_exe_files( @ewnd )
            
            If IsWindow(main_wnd)
                SortList(settings\app_names(), #PB_Sort_Ascending)
                ForEach settings\app_names()
                    AddGadgetItem(ewnd\lst_exes, -1, settings\app_names())
                Next
            Else
                err("Can't open selection window.")
            EndIf
            
        EndIf
        
    Case #APP_FUNC_CONFIG
        save_settings( #Null )
        End 0
        
    Default ; #APP_FUNC_DEFAULT
        
        ;-- load config file to get the apps to report
         If load_settings(@settings)
            
            ;--- copy the app names to a list for the thread
            ForEach settings\app_names()
                AddElement(ma_ptr\ma())
                ma_ptr\ma()\exe_name  = settings\app_names()
                ma_ptr\ma()\user_name = UserName()
            Next
            ma_ptr\loop_delay = settings\loop_delay
            
            info("config loaded, found " + Str(ListSize(ma_ptr\ma())) + " apps to monitor")
            
        Else
            err("There are 0 (NULL) applications to monitor.")
        EndIf
        
        ;-- open an invisible window
        main_wnd = OpenWindow(#PB_Any, 0, 0, 16, 16, #APP_NAME, #PB_Window_Invisible)
        If IsWindow(main_wnd)
            
            CompilerIf #PB_Compiler_Debugger
                main_tray = AddSysTrayIcon(#PB_Any, WindowID(main_wnd), ImageID(get_data_icon(?SYSTRAYICON)))
            CompilerEndIf
            
            GetWindowThreadProcessId_(WindowID(main_wnd), @wnd_evt) ; only for testing
            info("window with system ID " + Str(WindowID(main_wnd)) + " and process ID: " + Str(wnd_evt) + " opened")
            
            ;--- this callback trys to hook the EXITWINDOWS messages, to save all data
            SetWindowCallback(@main_window_callback(), main_wnd)
            
            ;--- the thread to monitor the apps
            monitor_thread_id = CreateThread(@thread_monitor_apps(), @ma_ptr._MONITOR_APPS_PTR)
            If IsThread(monitor_thread_id)
                info("monitor thread starts successfully")
            Else
                err("Can't start monitoring thread")
            EndIf
            
        Else
            err("Can't create an invisible window.")
        EndIf
        
EndSelect

Macro save_program_selection
    If ListSize(settings\app_names()) > 0
        ClearList(settings\app_names())
    EndIf
    For n = 0 To CountGadgetItems(ewnd\lst_exes)-1
        AddElement(settings\app_names())
        settings\app_names() = GetGadgetItemText(ewnd\lst_exes, n)
    Next
    save_settings(@settings)
EndMacro

;-******************** main ********************
Repeat
    
    wnd_evt = WaitWindowEvent()
    
    Select wnd_evt
            
        Case #PB_Event_CloseWindow
            
            If EventWindow() = ewnd\id
                save_program_selection
            EndIf
            
            do_loop = #False
            info("PB event => PB_Event_CloseWindow")
            
        Case #PB_Event_Gadget
            
            Select EventGadget()
                    
                Case rwnd\btn_create
                    date_min = GetGadgetState(rwnd\dte_from)
                    date_max = GetGadgetState(rwnd\dte_to)
                    CloseWindow(rwnd\id)
                    info("creating report from " + FormatDate("%dd.%mm.%yyyy", date_min) + " to " + FormatDate("%dd.%mm.%yyyy", date_max))
                    
                    Define.s report_name = GetTemporaryDirectory() + #APP_NAME + "_Report_" + Str(Date()) + ".html"
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
                    save_program_selection
                    do_loop = #False
                    
            EndSelect
            
        CompilerIf #PB_Compiler_Debugger
        Case #PB_Event_SysTray
            
            Select EventType()
                Case #PB_EventType_RightClick, #PB_EventType_LeftClick
                    do_loop = #False
                    info("PB event => PB_Event_SysTray")
                    
            EndSelect
        CompilerEndIf
            
        Default
            If wnd_evt > 0 And Not IsWindow(rwnd\id)
                Debug "uncatched window event: " + Str(wnd_evt)
            EndIf
            
    EndSelect
    
Until do_loop = #False

;-******************** save data ********************
If IsThread(monitor_thread_id)
    PauseThread(monitor_thread_id)
    KillThread(monitor_thread_id)
EndIf
If save_statistics()
    data_saved = #True
    info("data was sucessfully saved")
Else
    err("data wasn't saved, the stats are lost")
EndIf


;-******************** end ********************
End 0

;-******************** functions ********************

Procedure.l process_program_params ( args.l )
    
    Protected.l n
    Protected.s param
    
    For n = 0 To args-1
        
        param = UCase(ProgramParameter(n))
        
        If Left(param, 2) = "--"
            param = Mid(param, 3)
        ElseIf Left(param, 1) = "-" Or Left(param, 1) = "/"
            param = Mid(param, 2)
        Else
            info("Unknown parameter: " + param)
            Continue
        EndIf
        
        Select param
                
            Case "REPORT"   : ProcedureReturn #APP_FUNC_REPORT
                
            Case "CONFIG"   : ProcedureReturn #APP_FUNC_CONFIG
                
            Case "SELECT"   : ProcedureReturn #APP_FUNC_SELECT
                
            Case "HELP"     : ProcedureReturn #APP_FUNC_HELP
                
            Default         : ProcedureReturn #APP_FUNC_DEFAULT
                
        EndSelect
        
    Next
    
    ProcedureReturn 0
    
EndProcedure

Procedure.i main_window_callback(hWnd.i, uMsg.i, wParam.i, lParam.i) 
    
    Macro save_all
        If IsThread(monitor_thread_id)
            PauseThread(monitor_thread_id) : info("thread paused")
            KillThread(monitor_thread_id) : info("thread killed")
        EndIf
        If data_saved = #False
            If save_statistics() 
                data_saved = #True
                info("data was sucessfully saved")
            Else
                info("data wasn't saved, the stats are lost")
            EndIf
        EndIf
    EndMacro
    
    Select uMsg
            
;         Case #WM_QUIT
;             sys("event => WM_QUIT")
;             save_all
;             PostQuitMessage_(0)
;             ProcedureReturn 0
            
;         Case #WM_CLOSE
;             sys("event => WM_CLOSE")
;             save_all
;             DestroyWindow_(hWnd)
;             ProcedureReturn 0
            
        Case #WM_DESTROY
            sys("event => WM_DESTROY")
            save_all
            ;PostQuitMessage_(0)
            ProcedureReturn 0
            
        Case #WM_QUERYENDSESSION
            sys("event => WM_QUERYENDSESSION")
            ShowWindow_(hWnd, #SW_SHOW)
            save_all
            ProcedureReturn 1
            
        Case #WM_ENDSESSION
            sys("event => WM_ENDSESSION")
            If IsThread(monitor_thread_id)
                KillThread(monitor_thread_id)
            EndIf
            info("system is shutting down")
            ProcedureReturn 0

    EndSelect
    
    ProcedureReturn #PB_ProcessPureBasicEvents 
    
EndProcedure
; IDE Options = PureBasic 6.04 LTS (Windows - x64)
; CursorPosition = 199
; FirstLine = 12
; Folding = --
; Optimizer
; EnableThread
; EnableXP
; EnableUser
; DPIAware
; Compiler = PureBasic 6.04 LTS - C Backend (Windows - x64)
; EnablePurifier
; EnableCompileCount = 1
; EnableBuildCount = 0
; EnableExeConstant