*&---------------------------------------------------------------------*
*& Report ZDELAY_BGRJOBS
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
report zdelay_bgrjobs.

tables tbtco.

*--------------------------------------------------------------------*
* SELECTION SCREEN
*--------------------------------------------------------------------*
selection-screen begin of block b1 with frame title text-001.

select-options s_date for tbtco-sdlstrtdt default sy-datum obligatory.
select-options s_time for tbtco-sdlstrttm obligatory.
select-options s_job  for tbtco-jobname.
parameters     p_delay type i default 30 obligatory.

selection-screen end of block b1.

initialization.

  data gv_time_low type t.
  data gv_time_high type t.

  gv_time_low = sy-uzeit + 30.
  gv_time_high = gv_time_low + ( p_delay * 60 ).

  s_time-sign = 'I'.
  s_time-option = 'EQ'.
  s_time-low = gv_time_low.
  s_time-high = gv_time_high.
  append s_time to s_time[].

*--------------------------------------------------------------------*
* START-OF-SELECTION
*--------------------------------------------------------------------*
start-of-selection.

  data gv_date type d.
  data gv_time type t.

  " Get all scheduled background jobs for selection interval
  select jobname, jobcount, sdlstrtdt, sdlstrttm from tbtco
    where jobname   in @s_job[]
      and sdlstrtdt in @s_date[]
      and sdlstrttm in @s_time[]
      and status     = 'S'
      into table @data(lt_tbtco).

  if lines( lt_tbtco ) = 0.
    write 'No scheduled background jobs found'.
    return.
  endif.

  " Calculate the delay time in seconds
  p_delay = p_delay * 60.

  " Loop through all scheduled jobs and delay
  loop at lt_tbtco assigning field-symbol(<gs_tbtco>).
    " Add the delay time to the timestamp
    cl_abap_tstmp=>td_add( exporting date     = <gs_tbtco>-sdlstrtdt
                                     time     = <gs_tbtco>-sdlstrttm
                                     secs     = p_delay
                           importing res_date = gv_date
                                     res_time = gv_time ).

    " Update the job start time in the database
    update tbtco set sdlstrtdt = @gv_date,
                     sdlstrttm = @gv_time
      where jobname  = @<gs_tbtco>-jobname
      and   jobcount = @<gs_tbtco>-jobcount.
    if sy-subrc = 0.
      commit work.
      write / |Background job { <gs_tbtco>-jobname } that was scheduled to start { <gs_tbtco>-sdlstrtdt date = environment } { <gs_tbtco>-sdlstrttm time = environment }|.
      write / |is now scheduled to start { gv_date date = environment } { gv_time time = environment }|.
    else.
      rollback work.
      write / |Error updating job { <gs_tbtco>-jobname }|.
    endif.
  endloop.
