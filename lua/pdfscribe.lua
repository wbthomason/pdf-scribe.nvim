-- Utility to extract PDF annotations and metadata for use in generating notes files
-- TODO: Extract and parse references
local ffi = require('ffi')
local function log_error(msg)
  io.stderr:write('[pdfscribe] ' .. msg .. '\n')
end

local function split(str, pat)
  local result = {}
  for elem in string.gmatch(str, '([^' .. pat .. ']+)') do
    table.insert(result, elem)
  end

  return result
end

if vim then
  local api = vim.api
  log_error = function(msg)
    api.nvim_command('echohl ErrorMsg')
    api.nvim_command('echom "[pdfscribe] ' .. msg .. '"')
    api.nvim_command('echohl None')
  end

  split = vim.fn.split
end

require('pdfscribe/cdefs')

local poppler = ffi.load('poppler-glib')
local glib = ffi.load('libgobject-2.0.so')

local PDF = {}

local function page_then_date_order(a, b)
  local a_page = a.page_idx
  local a_date = a.mod_date
  local b_page = b.page_idx
  local b_date = b.mod_date

  if a_page == b_page then
    return a_date < b_date
  end

  return a_page < b_page
end

local function try_open(pdf_file_path)
  if pdf_file_path == nil then
    log_error('Nil PDF path!')
    return nil
  end

  local err = ffi.new('GError*[1]', ffi.NULL)
  local pdf_file_uri = nil
  if vim.fn.filereadable(pdf_file_path) then
    pdf_file_uri = glib.g_filename_to_uri(pdf_file_path, ffi.NULL, err)
  else
    local current_dir = glib.g_get_current_dir()
    local absolute_pdf_path = glib.g_build_filename(current_dir, pdf_file_path, ffi.NULL)
    glib.g_free(current_dir)
    glib.g_free(absolute_pdf_path)
    pdf_file_uri = glib.g_filename_to_uri(absolute_pdf_path, ffi.NULL, err)
  end

  if pdf_file_uri == ffi.NULL then
    log_error(ffi.string(err[0].message))
    return nil
  end

  local pdf = poppler.poppler_document_new_from_file(pdf_file_uri, ffi.NULL, err)
  glib.g_free(pdf_file_uri)
  if pdf == ffi.NULL then
    log_error(ffi.string(err[0].message))
    return nil
  end

  if err[0] ~= ffi.NULL then glib.g_object_unref(err[0]) end
  pdf = ffi.gc(pdf, glib.g_object_unref)
  return pdf
end

local function clean_mod_date(mod_date)
  local datetime = ffi.new('int[1]', 0)
  if not poppler.poppler_date_parse(mod_date, datetime) then
    log_error('Failed to parse modified date string!')
    return nil
  end

  local date_format = '%Y/%m/%d'
  if vim then
    date_format = vim.g.pdfscribe_date_format
  end

  return os.date(date_format, tonumber(datetime))
end

function PDF:get_pages()
  if self.pdf_pages then
    return self.pdf_pages
  end

  if self.pdf == nil then
    log_error('No PDF loaded!')
    return nil
  end

  local pdf = self.pdf
  local pages = {}

  for i=1,poppler.poppler_document_get_n_pages(pdf) do
    local page = ffi.gc(poppler.poppler_document_get_page(pdf, i - 1), glib.g_object_unref)
    table.insert(pages, page)
  end

  self.pdf_pages = pages
  return self.pdf_pages
end

function PDF:get_keywords()
  if self.pdf_keywords then
    return self.pdf_keywords
  end

  if self.pdf == nil then
    log_error('No PDF loaded!')
    return nil
  end

  local keywords_raw = poppler.poppler_document_get_keywords(self.pdf)
  if keywords_raw ~= ffi.NULL then
    self.pdf_keywords = ffi.string(keywords_raw)
    glib.g_free(keywords_raw)
  end

  return self.pdf_keywords
end

function PDF:get_author()
  if self.pdf_author then
    return self.pdf_author
  end

  if self.pdf == nil then
    log_error('No PDF loaded!')
    return nil
  end

  local author_raw = poppler.poppler_document_get_author(self.pdf)
  if author_raw ~= ffi.NULL then
    self.pdf_author = ffi.string(author_raw)
    glib.g_free(author_raw)
  end

  return self.pdf_author
end

function PDF:get_title()
  if self.pdf_title then
    return self.pdf_title
  end

  if self.pdf == nil then
    log_error('No PDF loaded!')
    return nil
  end

  local title_raw = poppler.poppler_document_get_title(self.pdf)
  if title_raw ~= ffi.NULL then
    self.pdf_title = ffi.string(title_raw)
    glib.g_free(title_raw)
  end

  return self.pdf_title
end

function PDF:get_external_links()
  if self.pdf_links then
    return self.pdf_links
  end

  local pages = self:get_pages()
  if pages == nil then
    return nil
  end

  local links = {}
  for _, page in ipairs(pages) do
    local _link_mappings = poppler.poppler_page_get_link_mapping(page)
    local link_mappings = _link_mappings
    while link_mappings ~= ffi.NULL do
      local link_mapping = ffi.cast('PopplerLinkMapping*', link_mappings.data)
      local link_action = link_mapping.action
      if link_action.type == poppler.POPPLER_ACTION_URI then
        link_action = link_action.uri
        local title_raw = link_action.title
        local action = { dest = ffi.string(link_action.uri) }
        if title_raw ~= ffi.NULL then
          action.title = ffi.string(title_raw)
        end

        table.insert(links, action)
      elseif link_action.type == poppler.POPPLER_ACTION_GOTO_REMOTE then
        link_action = link_action.goto_remote
        local title_raw = link_action.title
        local action = { dest = ffi.string(link_action.file_name) }
        if title_raw ~= ffi.NULL then
          action.title = ffi.string(title_raw)
        end

        table.insert(links, action)
      end

      link_mappings = link_mappings['next']
    end

    poppler.poppler_page_free_link_mapping(_link_mappings)
  end

  self.pdf_links = links
  return self.pdf_links
end

function PDF:get_annotations()
  if self.pdf_annotations then
    return self.pdf_annotations
  end

  local pages = self:get_pages()
  if pages == nil then
    return nil
  end

  local annots = {}
  local selection_rect = ffi.new('PopplerRectangle', { 0.0, 0.0, 0.0, 0.0 })
  for i, page in ipairs(pages) do
    local page_label_raw = poppler.poppler_page_get_label(page)
    local page_label = nil
    if page_label_raw ~= ffi.NULL then
      page_label = ffi.string(page_label_raw)
      glib.g_free(page_label_raw)
    end

    local width = ffi.new('double[1]', 1.0)
    local height = ffi.new('double[1]', 1.0)
    poppler.poppler_page_get_size(page, width, height)

    local _annot_mappings = poppler.poppler_page_get_annot_mapping(page)
    local annot_mappings = _annot_mappings
    while annot_mappings ~= ffi.NULL do
      local annot_mapping = ffi.cast('PopplerAnnotMapping*', annot_mappings.data)
      local annotation = {
        page_idx = i,
        page_label = page_label,
        page = page_label and page_label or i
      }
      local annotation_data = annot_mapping.annot
      local annotation_type = poppler.poppler_annot_get_annot_type(annotation_data)
      if
        annotation_type == poppler.POPPLER_ANNOT_TEXT or
        annotation_type == poppler.POPPLER_ANNOT_HIGHLIGHT or
        annotation_type == poppler.POPPLER_ANNOT_UNDERLINE
      then
        local contents_raw = poppler.poppler_annot_get_contents(annotation_data)
        if contents_raw ~= ffi.NULL then
          annotation.contents = split(ffi.string(contents_raw), '\n')
          glib.g_free(contents_raw)
        end

        if
          annotation_type == poppler.POPPLER_ANNOT_HIGHLIGHT or
          annotation_type == poppler.POPPLER_ANNOT_UNDERLINE
        then
          local highlight_quads_array = poppler.poppler_annot_text_markup_get_quadrilaterals(
            ffi.cast('PopplerAnnotTextMarkup*', annotation_data))

          local highlight_text = {}
          local highlight_quads = ffi.cast(
            'PopplerQuadrilateral*',
            ffi.cast('void*', highlight_quads_array.data))

          for j=1,highlight_quads_array.len do
            local quad = highlight_quads[j - 1]
            selection_rect.x1 = quad.p1.x
            selection_rect.y1 = height[0] - quad.p4.y
            selection_rect.x2 = quad.p4.x
            selection_rect.y2 = height[0] - quad.p1.y
            local highlight_text_raw = poppler.poppler_page_get_selected_text(
              page,
              poppler.POPPLER_SELECTION_WORD,
              selection_rect
            )

            if highlight_text_raw ~= ffi.NULL then
              local original_text = ffi.string(highlight_text_raw)
              -- Each quadrilateral seems to correspond to a single line of text, so we can assume
              -- that newlines are erroneous within a single quad's text
              local clean_text, total_matches = string.gsub(original_text, '\n', ' ')
              local correct_text = (total_matches > 0) and clean_text or original_text
              table.insert(highlight_text, correct_text)
            end
          end

          annotation.selected_text = table.concat(highlight_text, ' ')
        end

        local mod_date_raw = poppler.poppler_annot_get_modified(annotation_data)
        annotation.mod_date = ffi.string(mod_date_raw)
        annotation.modified = clean_mod_date(mod_date_raw)
        glib.g_free(mod_date_raw)
        table.insert(annots, annotation)
      end

      annot_mappings = annot_mappings['next']
    end

    poppler.poppler_page_free_annot_mapping(_annot_mappings)
  end

  table.sort(annots, page_then_date_order)
  self.pdf_annotations = annots
  return self.pdf_annotations
end

function PDF:load(pdf_file_path)
  local pdf = {}
  setmetatable(pdf, self)
  self.__index = self
  self.pdf = try_open(pdf_file_path)
  if self.pdf == nil then
    return nil
  end

  return pdf
end

local M = { }
M.PDF = PDF
M.load_pdf = function(pdf_file_path)
  return PDF:load(pdf_file_path)
end

M.get_all_info = function(pdf_file_path)
  local pdf = PDF:load(pdf_file_path)
  if pdf then
    local result = { file = pdf_file_path }
    local author = pdf:get_author()
    if author then
      result.author = author
    end

    local keywords = pdf:get_keywords()
    if keywords then
      result.keywords = keywords
    end

    result.title = pdf:get_title()
    local links = pdf:get_external_links()
    if links then
      result.links = links
    end

    result.annotations = pdf:get_annotations()

    return result
  end

  return {}
end

M.get_annotations = function(pdf_file_path)
  local pdf = PDF:load(pdf_file_path)
  if pdf then
    return pdf:get_annotations()
  end

  return {}
end

return M
