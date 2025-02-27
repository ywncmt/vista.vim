" Copyright (c) 2019 Liu-Cheng Xu
" MIT License
" vim: ts=2 sw=2 sts=2 et

let s:floating_timer = -1
let s:last_lnum = -1

" Vista sidebar window usually sits at the right side.
" TODO improve me!
function! s:CalculatePosition(lines) abort
  let lines = a:lines
  let pos = s:floating_opened_pos

  let width = max(map(copy(a:lines), 'strdisplaywidth(v:val)'))

  let width = max([width, 40])
  let height = len(lines)

  " Calculate anchor
  " North first, fallback to South if there is no enough space.
  let bottom_line = line('w0') + winheight(0) - 1
  if pos[1] + height <= bottom_line
    let vert = 'N'
    let row = 1
  else
    let vert = 'S'
    let row = 0
  endif

  " TODO should be tweaked accroding to the position of vista sidebar
  let hors = ['E', 'W']

  let [_, _, cur_col, _, _] = getcurpos()

  " West first, fallback into East if there is no enough space.
  if pos[2] + width <= &columns
    let hor = hors[0]
    let col = 0
  else
    let hor = hors[1]
    let col = 1
  endif

  return [width, height, vert.hor, row-1, col+4-cur_col]
endfunction

function! s:ApplyClose() abort
  if exists('#VistaFloatingWin')
    autocmd! VistaFloatingWin
  endif

  if exists('s:floating_win_id')
    let winnr = win_id2win(s:floating_win_id)

    if winnr > 0
      execute winnr.'wincmd c'
    endif
  endif

  let t:vista.floating_visible = v:false
endfunction

function! s:CloseOnCursorMoved() abort
  " To avoid closing floating window immediately, check the cursor
  " was really moved.
  if getpos('.') == s:floating_opened_pos
    return
  endif

  call s:ApplyClose()
endfunction

function! s:CloseOnWinEnter() abort
  let winnr = win_id2win(s:floating_win_id)

  " Floating window has been closed already.
  if winnr == 0
    autocmd! VistaFloatingWin
    return
  endif

  " We are just in the floating window. Do not close it
  if winnr == winnr()
    return
  endif

  autocmd! VistaFloatingWin
  execute winnr.'wincmd c'

  let t:vista.floating_visible = v:false
endfunction

function! s:Display(msg) abort
  let msg = a:msg

  if !exists('s:floating_bufnr') || !bufexists(s:floating_bufnr)
    let s:floating_bufnr = nvim_create_buf(v:false, v:false)
  endif

  let s:floating_opened_pos = getpos('.')
  let [width, height, anchor, row, col] = s:CalculatePosition(a:msg)

  " silent is neccessary for the both strategy!
  silent let s:floating_win_id = nvim_open_win(
        \ s:floating_bufnr, v:true, {
        \   'width': width,
        \   'height': height,
        \   'relative': 'cursor',
        \   'anchor': anchor,
        \   'row': row + 0.4,
        \   'col': col - 5,
        \ })

  call nvim_buf_set_lines(s:floating_bufnr, 0, -1, 0, a:msg)

  let target_line = getbufline(s:floating_bufnr, s:floating_lnum)[0]
  let [_, start, end] = matchstrpos(target_line, '\C'.s:cur_tag)

  if start != -1
    " {line} is zero-based.
    call nvim_buf_add_highlight(s:floating_bufnr, -1, 'Search', s:floating_lnum-1, start, end)
  endif

  setlocal
        \ winhl=Normal:Pmenu
        \ buftype=nofile
        \ nobuflisted
        \ bufhidden=hide
        \ nonumber
        \ norelativenumber
        \ signcolumn=no
        \ nofoldenable

  let &l:filetype = getbufvar(t:vista.source.bufnr, '&ft')

  wincmd p

  augroup VistaFloatingWin
    autocmd!
    autocmd CursorMoved <buffer> call s:CloseOnCursorMoved()
    autocmd BufEnter,WinEnter,WinLeave  * call s:CloseOnWinEnter()
  augroup END

  let t:vista.floating_visible = v:true
endfunction

function! vista#floating#Close() abort
  call s:ApplyClose()
endfunction

function! vista#floating#Display(lnum, tag) abort
  silent! call timer_stop(s:floating_timer)

  let lnum = a:lnum

  " See if it's identical to the last lnum to avoid blink. Ref #55
  "
  " No need to display again when it's already visible.
  if lnum == s:last_lnum
        \ && get(t:vista, 'floating_visible', v:false)
    return
  endif

  " We save the tag info so that it could be used later for adding the tag highlight.
  "
  " It's problematic when calculating the highlight position here, leading to
  " the displacement of current tag highlighting position.
  let s:last_lnum = lnum
  let s:cur_tag = a:tag

  " Show 5 lines around the tag source line [lnum-5, lnum+5]
  let range = 5

  if lnum - range > 0
    let s:floating_lnum = range + 1
  else
    let s:floating_lnum = lnum
  endif

  let begin = max([lnum - range, 1])
  let end = begin + range * 2
  let lines = getbufline(t:vista.source.bufnr, begin, end)

  let delay = get(g:, 'vista_floating_delay', 100)
  let s:floating_timer = timer_start(
        \ delay,
        \ { -> s:Display(lines)},
        \ )
endfunction
