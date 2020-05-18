function! pdfscribe#complete_pdf_files(arg_lead, cmdline, cursor_pos) abort
  return map(globpath(g:pdfscribe_pdf_dir, a:arg_lead . '*.pdf', v:true, v:true), {_, val -> fnamemodify(val, ':t')})
endfunction

function! pdfscribe#complete_notes_files(arg_lead, cmdline, cursor_pos) abort
  return map(globpath(g:pdfscribe_notes_dir, a:arg_lead . '*.' . g:pdfscribe_notes_extension, v:true, v:true), {_, val -> fnamemodify(val, ':t')})
endfunction

function! s:data_has_match(data, match_info) abort
  let [_, keys, _; _] = a:match_info
  let l:result = v:true
  for key in split(keys, '&', v:false)
    let l:result = l:result && has_key(a:data, key) && !empty(a:data[key])
  endfor

  return l:result
endfunction

function! s:sub_if_present(data, match_info) abort
  if s:data_has_match(a:data, a:match_info)
    return a:match_info[2]
  endif

  return ''
endfunction

function! s:sub_if_absent(data, match_info) abort
  if !s:data_has_match(a:data, a:match_info)
    return a:match_info[2]
  endif

  return ''
endfunction

function! s:substitute_string_data(data, match_info) abort
  let l:datum = get(a:data, a:match_info[1])
  if type(l:datum) == v:t_string
    return l:datum
  endif

  return a:match_info[0]
endfunction

let s:positive_conditional_pattern = '\${+\([^:]\+\):\(.\+\)+}'
let s:negative_conditional_pattern = '\${-\([^:]\+\):\(.\+\)-}'
let s:data_field_pattern = '\${\([^\}]\{-1,}\)}'

function! s:apply_template(template, data) abort
  let l:tpl = copy(a:template)

  " Find intentionally empty lines
  let l:empties = []
  let l:start = 0
  let l:empty_idx = index(l:tpl, '')
  while l:empty_idx >= 0
    call add(l:empties, l:empty_idx)
    let l:start = l:empty_idx + 1
    let l:empty_idx = index(l:tpl, '', l:start)
  endwhile

  " Resolve conditionals
  let b:pos_sub = function('s:sub_if_present', [a:data])
  let b:neg_sub = function('s:sub_if_absent', [a:data])
  let b:string_data_sub = function('s:substitute_string_data', [a:data])
  for idx in range(len(l:tpl))
    let l:tpl[idx] = substitute(l:tpl[idx], s:positive_conditional_pattern, b:pos_sub, 'g')
    let l:tpl[idx] = substitute(l:tpl[idx], s:negative_conditional_pattern, b:neg_sub, 'g')
  endfor

  " Resolve data fields
  " First, strings/flat data
  for idx in range(len(l:tpl))
    let l:tpl[idx] = substitute(l:tpl[idx], s:data_field_pattern, b:string_data_sub, 'g')
  endfor

  " Strip unintentional empty lines
  call filter(l:tpl, "v:val !=# '' || index(l:empties, v:key) >= 0")

  " Now, splice in list items (e.g. notes)
  let start = 0
  let data_field_idx = match(l:tpl, s:data_field_pattern)
  let l:result = []
  while data_field_idx >= 0
    if data_field_idx > start
      call extend(l:result, l:tpl[start : data_field_idx - 1])
    endif

    let field_idx = match(l:tpl[data_field_idx], s:data_field_pattern)
    if field_idx > 0
      let l:prefix = l:tpl[data_field_idx][:field_idx - 1]
    else
      let l:prefix = ''
    endif

    " NOTE: This is only valid b/c more than one list item on a line doesn't make sense in a
    " template
    let [_, key; _] = matchlist(l:tpl[data_field_idx], s:data_field_pattern)
    let l:replacement = get(a:data, key, '')
    if !empty(l:replacement)
      let l:replacement[0] = l:prefix . l:replacement[0]
      call extend(l:result, l:replacement)
    endif

    let start = data_field_idx + 1
    let data_field_idx = match(l:tpl, s:data_field_pattern, start)
  endwhile

  if start < len(l:tpl)
    call extend(l:result, l:tpl[start :])
  endif

  return l:result
endfunction

function! s:template_file(pdf_info, formatted_notes) abort
  let l:data = extend(a:pdf_info, {
        \ 'notes': a:formatted_notes,
        \ 'date': strftime(g:pdfscribe_date_format),
        \ 'notes_marker': g:pdfscribe_notes_marker
        \})
  if exists('g:pdfscribe_notes_end_marker')
    let l:data['notes_end_marker'] = g:pdfscribe_notes_end_marker
  endif

  return s:apply_template(g:pdfscribe_file_template, l:data)
endfunction

function! s:template_note(_, annotation) abort
  return s:apply_template(g:pdfscribe_note_template, a:annotation)
endfunction

function! s:template_link(_, link) abort
  return s:apply_template(g:pdfscribe_link_template, a:link)
endfunction

function! pdfscribe#init_notes(pdf_name) abort
  if a:pdf_name ==# ''
    " If no argument was given, assume the paper is named the same thing as the current buffer
    let l:pdf_name = expand('%:t:r') . '.pdf'
    let l:notes_path = expand('%:p')
  else
    let l:pdf_name = a:pdf_name
    let l:notes_path = printf('%s/%s.%s', g:pdfscribe_notes_dir, fnamemodify(l:pdf_name, ':r'), g:pdfscribe_notes_extension)
  endif

  let l:pdf_path = expand(printf('%s/%s', g:pdfscribe_pdf_dir, l:pdf_name))
  let l:pdf_info = luaeval("require('pdfscribe').get_all_info(_A)", l:pdf_path)
  if empty(l:pdf_info)
    echohl WarningMsg
    echom '[pdfscribe] No PDF info for ' . fnamemodify(l:pdf_path, ':~:.') . '!'
    echohl None
    return
  endif

  call extend(l:pdf_info, {'file_name': fnamemodify(l:pdf_name, ':r')})
  execute 'edit ' . l:notes_path
  if exists('g:pdfscribe_note_formatter') && type(g:pdfscribe_note_formatter) == v:t_func
    let l:formatted_notes = call(g:pdfscribe_note_formatter, l:pdf_info['annotations'])
  else
    let l:formatted_notes = map(copy(l:pdf_info['annotations']), function('s:template_note'))
    " Now flatten the nested list
    let l:flattened_notes = []
    for note in l:formatted_notes
      call extend(l:flattened_notes, note)
    endfor

    let l:formatted_notes = l:flattened_notes
  endif

  if has_key(l:pdf_info, 'links')
    if exists('g:pdfscribe_link_formatter') && type(g:pdfscribe_link_formatter) == v:t_func
      let l:formatted_links = call(g:pdfscribe_link_formatter, l:pdf_info['links'])
    else
      let l:formatted_links = map(copy(l:pdf_info['links']), function('s:template_link'))
      " Now flatten the nested list
      let l:flattened_links = []
      for link in l:formatted_links
        call extend(l:flattened_links, link)
      endfor

      let l:formatted_links = l:flattened_links
    endif

    let l:pdf_info.raw_links = l:pdf_info.links
    let l:pdf_info.links = l:formatted_links
  endif

  if exists('g:pdfscribe_file_formatter') && type(g:pdfscribe_file_formatter) == v:t_func
    call extend(l:pdf_info, {'formatted_notes': l:formatted_notes})
    let l:formatted_contents = call(g:pdfscribe_file_formatter, l:pdf_info)
  else
    let l:formatted_contents = s:template_file(l:pdf_info, l:formatted_notes)
  endif

  call append(0, l:formatted_contents)
endfunction

function! pdfscribe#update_notes(file_name) abort
  if a:file_name ==# ''
    " If no argument was given, assume the paper is named the same thing as the current buffer
    let l:pdf_name = expand('%:t:r') . '.pdf'
    let l:notes_path = expand('%:p')
  else
    let l:pdf_name = fnamemodify(a:file_name, ':t:r') . '.pdf'
    let l:notes_path = printf('%s/%s.%s', g:pdfscribe_notes_dir, fnamemodify(a:file_name, ':t:r'), g:pdfscribe_notes_extension)
  endif

  let l:pdf_path = expand(printf('%s/%s', g:pdfscribe_pdf_dir, l:pdf_name))
  let l:annotations = luaeval("require('pdfscribe').get_annotations(_A)", l:pdf_path)
  if empty(l:annotations)
    echohl WarningMsg
    echom '[pdfscribe] No annotations for ' . l:pdf_path . '!'
    echohl None
    return
  endif

  if exists('g:pdfscribe_note_formatter') && type(g:pdfscribe_note_formatter) == v:t_func
    let l:formatted_notes = call(g:pdfscribe_note_formatter, l:annotations)
  else
    let l:formatted_notes = map(l:annotations, function('s:template_note'))
  endif

  execute 'edit ' . l:notes_path
  let l:notes_section_line = search(g:pdfscribe_notes_marker, 'csw')
  if exists('g:pdfscribe_notes_end_marker')
    let l:notes_section_end_line = search(g:pdfscribe_notes_end_marker, 'cw')
    let l:notes_section_end_line = l:notes_section_end_line - 1
    if l:notes_section_end_line < l:notes_section_line
      let l:notes_section_end_line = -1
    endif
  else
    let l:notes_section_end_line = -1
  endif

  let l:flattened_notes = []
  for note in l:formatted_notes
    call extend(l:flattened_notes, note)
  endfor

  let l:formatted_notes = l:flattened_notes
  call nvim_buf_set_lines(0, l:notes_section_line, l:notes_section_end_line, v:false, l:formatted_notes)
endfunction
