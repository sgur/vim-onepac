scriptencoding utf-8



" Interface {{{1

function! minpac#loader#load(path, fn_execute, ...) abort
  call minpac#init({'jobs': minpac#loader#nproc()})

  let filename = expand(a:path)

  if !filereadable(filename)
    echohl WarningMsg | echomsg '[minpac-loader] Unable to open:' a:path | echohl None
    return
  endif

  let ext = fnamemodify(filename, ':e')
  let prefs = {}
  if ext is? 'toml'
    let prefs = minpac#loader#toml#load(filename)
  endif
  if ext is? 'json'
    let prefs = minpac#loader#json#load(filename)
  endif
  if empty(prefs) || empty(get(prefs, 'plugins', []))
    echohl WarningMsg | echomsg "[minpac-loader] no plugin entries found" | echohl None
    return
  endif

  call map(
        \ filter(
        \   map(copy(prefs.plugins), 's:check(v:val)'),
        \   '!empty(v:val)'),
        \ 'minpac#add(v:val[0], v:val[1])')

  let restart_on_changed = a:0 && type(a:1) == v:t_dict && get(a:1, 'restart', 0)
  call call(a:fn_execute, [
        \ '',
        \ restart_on_changed ? {'do': function('s:hook_restart_on_update_finished')} : {}
        \ ])
endfunction

function! minpac#loader#nproc() abort
  return s:nproc
endfunction


" Internal {{{1

function! s:check(plugin) abort "{{{
  let config = a:plugin
  " Prerocess config.do hooks
  if has_key(config, 'do') && type(config.do) == v:t_string
    let config.do = s:convert_hook_from(config.do)
  endif

  try
    let url = remove(config, 'url')
    return [url, config]
  catch /^Vim\%((\a\+)\)\=:E716/
    echohl ErrorMsg | echomsg v:exception | echohl NONE
  endtry
  return []
endfunction "}}}

function! s:convert_hook_from(str) abort "{{{
  try
    if a:str =~# 'function(.\+)'
      return eval(a:str)
    endif
    " Assumed as an user functions
    return function(a:str)
  catch /^Vim\%((\a\+)\)\=:E\(15\|121\|129\|700\)/
    if a:str =~# '^{.\+}$'
      " as a lambada
      return eval(a:str)
    else
      " as an ex-command
      return a:str
    endif
  endtry
endfunction "}}}

function! s:hook_restart_on_update_finished(hooktype, updated, installed) abort "{{{
  if !(a:updated + a:installed)
    return
  endif
  if get(g:, 'loaded_restart', 0) && exists(':Restart') == 2
    Restart
  endif
endfunction "}}}


" Initialization {{{1



" 1}}}

try
  packadd minpac
catch /^Vim\%((\a\+)\)\=:E919/
finally
  if !exists('g:loaded_minpac')
    echoerr 'minpack not installed'
    finish
  endif
endtry


let s:nproc = has('win32')
      \ ? $NUMBER_OF_PROCESSORS
      \ : executable('nproc')
      \   ? systemlist('nproc')[0]
      \   : executable('sysctl')
      \     ? systemlist('sysctl -n hw.ncpu')[0]
      \     : 4

" macOS : sysctl -n machdep.cpu.cores_per_pacakge でもよさそう
