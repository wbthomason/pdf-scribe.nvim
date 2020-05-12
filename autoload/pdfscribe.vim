function! pdfscribe#complete_pdf_files(arg_lead, cmdline, cursor_pos) abort
  return globpath(g:pdfscribe_pdf_dir, a:arg_lead, v:true)
endfunction

function! pdfscribe#complete_notes_files(arg_lead, cmdline, cursor_pos) abort
  return globpath(g:pdfscribe_notes_dir, a:arg_lead, v:true)
endfunction

function! s:data_has_match(data, match_info) abort
  let [_, key, _] = a:match_info
  return has_key(a:data, key)
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

function! s:substitute_data_field(data, match_info) abort
  return get(a:data, a:match_info[1])
endfunction

let s:positive_conditional_pattern = '\${+\([^:]\+\):\(.\+\)+}'
let s:negative_conditional_pattern = '\${-\([^:]\+\):\(.\+\)-}'
let s:data_field_pattern = '\${\([^\}]\{-1,}\)}'

function! s:apply_template(template, data) abort
  let l:result = copy(a:template)
  " Resolve conditionals
  let l:pos_sub = function('s:sub_if_present', [a:data])
  let l:neg_sub = function('s:sub_if_absent', [a:data])
  let l:data_sub = function('s:substitute_data_field', [a:data])
  for idx in range(len(l:result))
    let l:result[idx] = substitute(l:result[idx], s:positive_conditional_pattern, l:pos_sub, 'g')
    let l:result[idx] = substitute(l:result[idx], s:negative_conditional_pattern, l:neg_sub, 'g')
  endfor

  " Resolve data fields
  for idx in range(len(l:result))
    let l:result[idx] = substitute(l:result[idx], s:data_field_pattern, l:data_sub, 'g')
  endfor

  " Flatten any nesting, e.g. from substituting in notes lines for a file template
  let l:flat_result = []
  for result_elem in l:result
    if type(result_elem) == v:t_list
      call extend(l:flat_result, result_elem)
    else
      call add(l:flat_result, result_elem)
    endif
  endfor

  return l:flat_result
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

function! s:template_note(annotation) abort
  return s:apply_template(g:pdfscribe_note_template, a:annotation)
endfunction

function! pdfscribe#init_notes(pdf_name) abort
  if a:pdf_name ==# ''
    " If no argument was given, assume the paper is named the same thing as the current buffer
    let l:pdf_name = expand('%:t:r')
    let l:notes_path = expand('%:p')
  else
    let l:pdf_name = a:pdf_name
    let l:notes_path = printf('%s/%s.%s', g:pdfscribe_notes_dir, l:pdf_name, g:pdfscribe_notes_extension)
  endif

  let l:pdf_path = printf('%s/%s', g:pdfscribe_pdf_dir, l:pdf_name)
  let l:pdf_info = luaeval("require('pdfscribe').get_all_info(_A)", l:pdf_path)
  edit l:notes_path
  if exists('*' . g:pdfscribe_note_formatter)
    let l:formatted_notes = call(g:pdfscribe_note_formatter, l:pdf_info['annotations'])
  else
    let l:formatted_notes = map(copy(l:pdf_info['annotations']), function('s:template_note'))
  endif

  if exists('*' . g:pdfscribe_file_formatter)
    let l:formatted_contents = call(g:pdfscribe_file_formatter, [l:pdf_info, l:formatted_notes])
  else
    let l:formatted_contents = s:template_file(l:pdf_info, l:formatted_notes)
  endif

  call append(0, l:formatted_contents)
endfunction

function! pdfscribe#update_notes(pdf_name) abort
  if a:pdf_name ==# ''
    " If no argument was given, assume the paper is named the same thing as the current buffer
    let l:pdf_name = expand('%:t:r')
    let l:notes_path = expand('%:p')
  else
    let l:pdf_name = a:pdf_name
    let l:notes_path = printf('%s/%s.%s', g:pdfscribe_notes_dir, l:pdf_name, g:pdfscribe_notes_extension)
  endif

  let l:pdf_path = printf('%s/%s', g:pdfscribe_pdf_dir, l:pdf_name)
  let l:annotations = luaeval("require('pdfscribe').get_annotations(_A)", l:pdf_path)
  if exists('*' . g:pdfscribe_note_formatter)
    let l:formatted_notes = call(g:pdfscribe_note_formatter, l:annotations)
  else
    let l:formatted_notes = map(l:annotations, function('s:template_note'))
  endif

  edit l:notes_path
  let l:notes_section_line = search(g:pdfscribe_notes_marker, 'csw')
  if exists('g:pdfscribe_notes_end_marker')
    let l:notes_section_end_line = search(g:pdfscribe_notes_end_marker, 'cw')
  else
    let l:notes_section_end_line = -1
  endif

  call nvim_buf_set_lines(0, l:notes_section_line + 1, l:notes_section_end_line, v:false, l:formatted_notes)
endfunction
