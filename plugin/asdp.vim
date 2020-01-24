"===============================================================================
"File: plugin/asdp.vim
"Description: asciidoc preview
"Last Change: 2020-01-22
"Maintainer: Shieber <QMH_XB_FLTMY@yahoo.com>
"Github: http://github.com/QMHTMY <Shieber>
"Licence: Vim Licence
"Version: 0.1
"===============================================================================

if !exists('g:debug_asdp') && exists('g:loaded_asdp')
    finish
endif
let g:loaded_asdp = 1

let s:save_cpo = &cpo
set cpo&vim
"-------------------------------------------------------------------------------

"default setting

if !exists('g:asdp_path_to_chrome')
    let g:asdp_path_to_chrome = '' " 'google-chrome'
endif

if !exists('g:asdp_auto_start')
    " open the browser once 
    let g:asdp_auto_start = 0
endif

if !exists('g:asdp_auto_open')
    " determine if the browser is open
    let g:asdp_auto_open = 0
endif

if !exists('g:asdp_auto_close')
    "close window when buffer changes
    let g:asdp_auto_close = 1
endif

if !exists('g:asdp_refresh_slow')
    " 0 refresh automatically, 1 for save mode
    let g:asdp_refresh_slow = 0
endif

if !exists('g:asdp_command_for_global')
    " 0 for asciidoc, 1 for any file
    let g:asdp_command_for_global = 0
endif

function s:start_cmd(timer) abort
  if exists('*jobstart')
    call jobstart(s:start_cmd_value)
  elseif exists('*job_start')
    call job_start(s:start_cmd_value)
  endif
endfunction

function! ASDP_browserfunc_default(url)
    " windows, including mingw
    if has('win32') || has('win64') || has('win32unix')
        let s:start_cmd_value = 'cmd /c start ' . a:url . '.html'
    " mac os
    elseif has('mac') || has('macunix') || has('gui_macvim') || system('uname') =~? '^darwin'
        if has('nvim')
            let s:start_cmd_value = 'open "' . a:url . '"'
        else
            let s:start_cmd_value = 'open ' . a:url . ''
        endif
    " linux
    elseif executable('xdg-open')
        if has('nvim')
            let s:start_cmd_value = 'xdg-open "' . a:url . '"'
        else
            let s:start_cmd_value = 'xdg-open ' . a:url . ''
       endif
    " can not find the browser
    else
        echoerr "Browser not found."
        return
    endif

    " Async open the url in browser
    if exists('*timer_start') && (exists('*jobstart') || exists('*job_start'))
        call timer_start(get(g:, 'asdp_delay_start_browser', 200), function('s:start_cmd'))
    else
    " if async is not supported, use `system` command
        call system(s:start_cmd_value)
    endif
endfunction
if !exists('g:asdp_browserfunc')
    let g:asdp_browserfunc='ASDP_browserfunc_default'
endif

let g:asdp_server_started = 0

fu! s:serverStart() abort

    if !g:asdp_server_started
        let g:asdp_server_started = 1
        call asdp#serverStart()
        call asdp#browserStart()
        call asdp#autoCmd()
        command! AsciidocPreviewStop call s:serverClose()
    else
        if !has_key(g:asdp_bufs, bufnr('%'))
            call asdp#browserStart()
            call asdp#autoCmd()
        else
            call asdp#browserStart()
        endif
    endif

endfu

fun! s:serverClose() abort

    "1. stop the server
    "2. remove all the autocmd action
    "3. init the variables to the default
    "4. remove the command

    call asdp#serverClose()
    for bufnr in keys(g:asdp_bufs)
        exec 'au! autocmd' . bufnr
    endfor
    let g:asdp_server_started = 0
    let g:asdp_bufs = {}
    if exists(':AsciidocPreviewStop')
        delcommand AsciidocPreviewStop
    endif
endfu

function s:auto_start_server() abort
  call s:serverStart()
  if exists('*timer_start')
    call timer_start(get(g:, 'asdp_delay_auto_refresh', 1000), function('asdp#asciidocRefresh'))
  endif
endfunction

if g:asdp_auto_start

    "if auto start, launch the server when enter the asiicdoc buffer

    if g:asdp_command_for_global
        au BufEnter * call s:auto_start_server()
    else
        au BufEnter *.{ad,asc,asd,ascd,adoc,asciidoc} call s:auto_start_server()
    endif
endif

"define the command to start the server when enter the asiicdoc buffer

if g:asdp_command_for_global
    au BufEnter * command! -buffer AsciidocPreview call s:serverStart()
else
    au BufEnter *.{ad,asc,asd,ascd,adoc,asciidoc} command! -buffer AsciidocPreview call s:serverStart()
endif

" mapping for user
map  <silent> <Plug>AsciidocPreview :call <SID>serverStart()<CR>
imap <silent> <Plug>AsciidocPreview <Esc>:call <SID>serverStart()<CR>a
map  <silent> <Plug>StopAsciidocPreview :if exists(':AsciidocPreviewStop') \| exec 'AsciidocPreviewStop ' \| endif<CR>
imap <silent> <Plug>StopAsciidocPreview <Esc>:if exists(':AsciidocPreviewStop') \| exec 'AsciidocPreviewStop ' \| endif<CR>a

"-------------------------------------------------------------------------------
let &cpo = s:save_cpo
unlet s:save_cpo
