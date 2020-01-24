"==============================================================================
"File: autoload/asdp.vim
"Description: asciidoc preview
"Last Change: 2020-01-22
"Maintainer: Shieber <QMH_XB_FLTMY@yahoo.com>
"Github: http://github.com/QMHTMY <Shieber>
"Licence: Vim Licence
"Version: 0.1
"===============================================================================

if !exists('g:asdp_py_version')
    if has('python3')
        let g:asdp_py_version = 3
        let s:py_cmd = 'py3 '
    elseif has('python')
        let g:asdp_py_version = 2
        let s:py_cmd = 'py '
    else
        echoerr 'PluginError: asciidoc-preview requires vim has python or python3 feature'
        finish
    endif
else
    if g:asdp_py_version == 3
        let s:py_cmd = 'py3 '
    else
        let s:py_cmd = 'py '
    endif
endif

function! s:asdp_is_windows() abort
    return  (has('win16') || has('win32') || has('win64'))
endfunction

let g:asdp_port = 8686
let g:asdp_prefix = localtime()
let g:asdp_bufs = {}
let s:path_to_server = expand('<sfile>:p:h') . "/server/server.py"
let g:asdp_cwd = ''

"python/python3 import init
exec s:py_cmd . 'import vim'
exec s:py_cmd . 'import sys'
exec s:py_cmd . 'import os'
exec s:py_cmd . 'import re'
exec s:py_cmd . 'cwd = vim.eval("expand(\"<sfile>:p:h\")")'
exec s:py_cmd . "cwd = re.sub(r'(?<=^.)', r':', os.sep.join(cwd.split('/')[1:])) if os.name == 'nt' and cwd.startswith('/') else cwd"
exec s:py_cmd . 'sys.path.insert(0,cwd)'
exec s:py_cmd . 'from server import send'
exec s:py_cmd . 'import base64'

fun! asdp#browserStart() abort "open browser and save the buffer number
    if !has_key(g:asdp_bufs, bufnr('%'))
        call s:browserStart()
        let g:asdp_bufs[bufnr('%')] = 1
    endif
endfu

fun! asdp#browserClose() abort "remove the buffer number and send close message to the browser
    if has_key(g:asdp_bufs, bufnr('%'))
        call remove(g:asdp_bufs, bufnr('%'))
        try
            call s:browserClose()
        catch /.*/
        endtry
    endif
endfun

fun! asdp#asciidocRefresh(...) abort  "refresh the asciidoc preview
    if has_key(g:asdp_bufs, bufnr('%'))
        try
            call s:asciidocRefresh()
        catch /.*/
            " not need to restart server since it will occur problem
            " call asdp#serverStart()
        endtry
    elseif g:asdp_auto_open
        call asdp#browserStart()
    endif
endfun

fun! asdp#serverStart() abort "start server
    try
        call s:serverStart()
    catch /.*/
        echoerr 'server start failed'
    endtry
endfu

fun! asdp#serverClose() abort "close server
    try
        call s:serverClose()
    catch /.*/
    endtry
endfu

fun! asdp#autoCmd() abort
    call s:autocmd()
endfu

fun! s:serverStart() abort "function for starting the server
    let g:asdp_port = g:asdp_port + localtime()[7:10]
    if s:asdp_is_windows()
        let l:cmd = "silent !start /b python " . '"' . s:path_to_server . '" ' . g:asdp_port
        if exists('g:asdp_open_to_the_world')
            let l:cmd = l:cmd . ' 0.0.0.0'
        endif
        exec l:cmd | redraw
    else
        let l:cmd = "python " . s:path_to_server . " " . g:asdp_port
        if exists('g:asdp_open_to_the_world')
            let l:cmd = l:cmd . ' 0.0.0.0'
        endif
        call system(l:cmd . " >/dev/null 2>&1 &") | redraw
    endif
endfun

fun! s:serverClose() abort "function for close the server
    exec s:py_cmd . "send.serverClose()"
endfu

fun! s:browserStart() abort "function for opening the browser
    " whether mathjax support
    if exists('g:mathjax_vim_path')
        let s:mathjax_vim_path = g:mathjax_vim_path
    else
        let s:mathjax_vim_path = ''
    endif

    let g:asdp_cwd = expand('%:p') . '&' . s:mathjax_vim_path

    " py2/py3 different resolve for str
    if g:asdp_py_version == 3
        exec s:py_cmd . 'vim.command("let g:asdp_cwd = \"" + base64.b64encode(vim.eval("g:asdp_cwd").encode("utf-8")).decode("utf-8") + "\"")'
    elseif g:asdp_py_version == 2
        exec s:py_cmd . 'vim.command("let g:asdp_cwd = \"" + base64.b64encode(vim.eval("g:asdp_cwd")) + "\"")'
    endif

    if exists('g:asdp_path_to_chrome') && len(g:asdp_path_to_chrome) > 0
        if s:asdp_is_windows()
            exec "silent !start " . g:asdp_path_to_chrome . " http://127.0.0.1:" . g:asdp_port . "/asciidoc/" . g:asdp_prefix . bufnr('%') . '?' . g:asdp_cwd
        else
            call system(g:asdp_path_to_chrome . " \"http://127.0.0.1:" . g:asdp_port . "/asciidoc/" . g:asdp_prefix . bufnr('%') . '?' . g:asdp_cwd . "\" >/dev/null 2>&1 &")
        endif
    elseif exists('g:asdp_browserfunc') && len(g:asdp_browserfunc) > 0
        execute 'call ' . g:asdp_browserfunc . '("' . "http://127.0.0.1:" . g:asdp_port . "/asciidoc/" . g:asdp_prefix . bufnr('%') . '?' . g:asdp_cwd . '")'
    else
        echoerr 'Plugin: asciidoc-preview (g:asdp_path_to_chrome) or (g:asdp_browserfunc) not set'
    endif
    if exists('*timer_start')
      call timer_start(get(g:, 'asdp_delay_auto_refresh', 1000), function('asdp#asciidocRefresh'))
    endif
endfun

fun! s:browserClose() abort "function for closing the browser
    exec s:py_cmd . "send.asciidocClose()"
endfu

fun! s:asciidocRefresh() abort "function for refresh the asciidoc
    exec s:py_cmd . "send.asciidocRefresh()"
endfun

fu! s:autocmd() abort
    "echo buffer has its own autocmd auto group
    exec 'aug autocmd' . bufnr('%')
        setl updatetime=1000
        au!
        if g:asdp_auto_close
            au BufLeave <buffer> call asdp#browserClose()
        endif
        au VimLeave * call asdp#serverClose()
        if g:asdp_refresh_slow
          au CursorHold,BufWrite,InsertLeave <buffer> call asdp#asciidocRefresh()
        else
          au CursorHold,CursorHoldI,CursorMoved,CursorMovedI <buffer> call asdp#asciidocRefresh()
        endif
    aug END
endfu
