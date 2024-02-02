;------------------------------------------------------------------------
;- * proc_time_logger
;  * small tool to get the time of a running process
;  *
;- * include: monitoring.pbi
;  *
;  * Copyright 2020 by Markus Mueller <markus.mueller.73@hotmail.de>
;  *
;  * For the license look in the main.pb file
;  *
;------------------------------------------------------------------------

;-******************** structures ********************
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

; moved to header
Structure _MONITOR_APPS
    user_name.s
    exe_name.s
    date_from.l
    date_to.l
    running.l
EndStructure

; moved to header
Structure _MONITOR_APPS_PTR
    loop_delay.l
    List ma._MONITOR_APPS()
EndStructure

;-******************** global vars ********************
;Global ma_ptr._MONITOR_APPS_PTR

;-******************** functions ********************
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
    
    ;NewList tmp_ma._MONITOR_APPS()
    NewList proc._PROCESS()
    
    ;CopyList(*ma_ptr\ma(), tmp_ma()) : ClearList(*ma_ptr\ma())
    
    Repeat 
        
        Delay ( *ma_ptr\loop_delay ) : counter + 1
        
        If get_process_list(proc())
            
            cur_date = Date()
        
            ForEach *ma_ptr\ma()
                
                With *ma_ptr\ma()
                    
                    cur_exe = \exe_name
                    
                    ForEach proc()
                        
                        prg_found = 0
                        
                        If CompareMemoryString(@cur_exe, @proc()\exe, #PB_String_NoCase) =  #PB_String_Equal
                            
                            prg_found = 1
                            
                            If \running = #False
                                
                                LockMutex(sync_mutex)
                                
                                If Not FindMapElement(STATISTIC(), cur_exe)
                                    AddMapElement(STATISTIC(), cur_exe)
                                    STATISTIC()\exe_name = cur_exe
                                EndIf
                                If ListSize(STATISTIC(cur_exe)\times()) > 0
                                    LastElement(STATISTIC(cur_exe)\times())
                                    If STATISTIC(cur_exe)\times()\start_date = 0
                                        STATISTIC(cur_exe)\times()\start_date = cur_date
                                    Else
                                        AddElement(STATISTIC(cur_exe)\times())
                                        STATISTIC(cur_exe)\times()\start_date = cur_date
                                    EndIf
                                Else
                                    AddElement(STATISTIC(cur_exe)\times())
                                    STATISTIC(cur_exe)\times()\start_date = cur_date
                                EndIf
                                
                                UnlockMutex(sync_mutex)
                                
                                \running = #True
                                
                                info("app '"+cur_exe+"' found, start monitoring")
                                
                            EndIf
                            
                            DeleteElement(proc(), #True)
                            
                            Break;ForEach proc()
                            
                        EndIf;CompareMemoryString(@cur_exe, @proc()\exe, #PB_String_NoCase) =  #PB_String_Equal
                        
                    Next;ForEach ewp\ew()
                    
                    If prg_found  = 0
                        
                        If \running
                            
                            LastElement(STATISTIC(cur_exe)\times())
                            STATISTIC(cur_exe)\times()\finish_date = cur_date
                            info("app '"+cur_exe+"' not running anymore, runs for " + FormatDate("%hh:%ii:%ss", date_diff(STATISTIC(cur_exe)\times()\start_date, cur_date)) + " hours")
                            
                            \running = #False
                            
                        EndIf;\running
                        
                    EndIf;prg_found  = 0
                    
                EndWith
                
            Next;ForEach *ma_ptr\ma()
            
        EndIf;get_process_list(proc())
        
    ForEver
    
EndProcedure


; IDE Options = PureBasic 6.04 LTS (Windows - x64)
; CursorPosition = 254
; FirstLine = 92
; Folding = 7
; Optimizer
; EnableXP
; EnableUser
; DPIAware
; UseMainFile = main.pb
; EnablePurifier
; EnableCompileCount = 0
; EnableBuildCount = 0
; EnableExeConstant