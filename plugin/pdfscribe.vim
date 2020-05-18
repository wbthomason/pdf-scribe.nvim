if exists('g:pdfdscribe_loaded')
  finish
endif

if !exists('g:pdfscribe_pdf_dir')
  let g:pdfscribe_pdf_dir = '~/Downloads'
endif

if !exists('g:pdfscribe_notes_dir')
  let g:pdfscribe_notes_dir = '~/notes'
endif

if !exists('g:pdfscribe_notes_extension')
  let g:pdfscribe_notes_extension = 'md'
endif

if !exists('g:pdfscribe_notes_marker')
  let g:pdfscribe_notes_marker = '## Notes'
endif

if !exists('g:pdfscribe_notes_end_marker')
  let g:pdfscribe_notes_end_marker = '## Links'
endif

if !exists('g:pdfscribe_date_format')
  let g:pdfscribe_date_format = '%Y/%m/%d'
endif

if !exists('g:pdfscribe_note_template') && !(exists('g:pdfscribe_note_formatter') && type(g:pdfscribe_note_formatter) == v:t_func)
  let g:pdfscribe_note_template =<< trim END
- *(Page ${page}, ${modified})*${-selected_text: ${contents}-}${+selected_text::+}
${+selected_text:  > ${selected_text}+}
${+selected_text&contents:  ${contents}+}

END
endif

if !exists('g:pdfscribe_file_template') && !(exists('g:pdfscribe_file_formatter') && type(g:pdfscribe_file_formatter) == v:t_func)
  let g:pdfscribe_file_template =<< trim END
# ${title}
${+author:${author}+}
@${file_name}
${+keywords:Keywords: ${keywords}+}

*Notes created: ${date}*

## Main Idea

${notes_marker}
${notes}
${+links:${notes_end_marker}+}
${+links:+}
${+links:${links}+}
END
endif

if !exists('g:pdfscribe_link_template') && !(exists('g:pdfscribe_link_formatter') && type(g:pdfscribe_link_formatter) == v:t_func)
  let g:pdfscribe_link_template = ['- ${+title:${title}: +}${dest}']
endif

command! -nargs=? -complete=customlist,pdfscribe#complete_pdf_files PdfScribeInit call pdfscribe#init_notes(<q-args>)
command! -nargs=? -complete=customlist,pdfscribe#complete_notes_files PdfScribeUpdateNotes call pdfscribe#update_notes(<q-args>)

let g:pdfscribe_loaded = v:true
