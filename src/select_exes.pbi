;------------------------------------------------------------------------
;- * proc_time_logger
;  * small tool to get the time of a running process
;  *
;- * include: select_exes.pbi
;  *
;  * Copyright 2020 by Markus Mueller <markus.mueller.73@hotmail.de>
;  *
;  * For the license look in the main.pb file
;  *
;------------------------------------------------------------------------

;-******************** structures ********************
Structure _WND_SELECT_EXES
    id.i
    txt_select.i
    lst_exes.i
    btn_select.i
    btn_close.i
EndStructure

;-******************** functions ********************
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

; IDE Options = PureBasic 6.04 LTS (Windows - x64)
; CursorPosition = 20
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