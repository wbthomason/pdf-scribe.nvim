local ffi = require('ffi')

ffi.cdef[[
  // GLib types
  typedef struct {
    int domain;
    int code;
    char* message;
  } GError;

  typedef struct _GList GList;
  struct _GList {
    void* data;
    GList* next;
    GList* prev;
  };

  typedef struct {
    char* data;
    unsigned int len;
  } GArray;

  // GLib functions
  char * g_build_filename(const char* first_element, ...);
  char * g_filename_to_uri(const char* filename, const char *hostname, GError **error);
  char * g_get_current_dir(void);
  void  g_object_unref(void *);
  void * g_free(void *);

  // Poppler types
  typedef struct _PopplerPage PopplerPage;
  typedef struct _PopplerDocument PopplerDocument;
  typedef struct _PopplerAnnot PopplerAnnot;
  typedef struct _PopplerAnnotTextMarkup PopplerAnnotTextMarkup;
  typedef struct {
    double x1;
    double y1;
    double x2;
    double y2;
  } PopplerRectangle;

  typedef struct {
    double x;
    double y;
  } PopplerPoint;

  typedef struct {
    PopplerPoint p1;
    PopplerPoint p2;
    PopplerPoint p3;
    PopplerPoint p4;
  } PopplerQuadrilateral;

  typedef struct {
    PopplerRectangle area;
    PopplerAnnot* annot;
  } PopplerAnnotMapping;

  typedef enum {
    POPPLER_ANNOT_UNKNOWN,
    POPPLER_ANNOT_TEXT,
    POPPLER_ANNOT_LINK,
    POPPLER_ANNOT_FREE_TEXT,
    POPPLER_ANNOT_LINE,
    POPPLER_ANNOT_SQUARE,
    POPPLER_ANNOT_CIRCLE,
    POPPLER_ANNOT_POLYGON,
    POPPLER_ANNOT_POLY_LINE,
    POPPLER_ANNOT_HIGHLIGHT,
    POPPLER_ANNOT_UNDERLINE,
    POPPLER_ANNOT_SQUIGGLY,
    POPPLER_ANNOT_STRIKE_OUT,
    POPPLER_ANNOT_STAMP,
    POPPLER_ANNOT_CARET,
    POPPLER_ANNOT_INK,
    POPPLER_ANNOT_POPUP,
    POPPLER_ANNOT_FILE_ATTACHMENT,
    POPPLER_ANNOT_SOUND,
    POPPLER_ANNOT_MOVIE,
    POPPLER_ANNOT_WIDGET,
    POPPLER_ANNOT_SCREEN,
    POPPLER_ANNOT_PRINTER_MARK,
    POPPLER_ANNOT_TRAP_NET,
    POPPLER_ANNOT_WATERMARK,
    POPPLER_ANNOT_3D
  } PopplerAnnotType;

  typedef enum {
    POPPLER_SELECTION_GLYPH,
    POPPLER_SELECTION_WORD,
    POPPLER_SELECTION_LINE
  } PopplerSelectionStyle;

  typedef enum {
	POPPLER_ACTION_UNKNOWN,		
	POPPLER_ACTION_NONE,            
	POPPLER_ACTION_GOTO_DEST,	
	POPPLER_ACTION_GOTO_REMOTE,	
	POPPLER_ACTION_LAUNCH,		
	POPPLER_ACTION_URI,		
	POPPLER_ACTION_NAMED,		
	POPPLER_ACTION_MOVIE,		
	POPPLER_ACTION_RENDITION,       
	POPPLER_ACTION_OCG_STATE,       
	POPPLER_ACTION_JAVASCRIPT	
  } PopplerActionType;
  
  typedef struct {
    PopplerActionType type;
    char* title;
    char* file_name;
    void* dest;
  } PopplerActionGotoRemote;

  typedef struct {
    PopplerActionType type;
    char* title;
    char* uri;
  } PopplerActionUri;

  typedef union {
    PopplerActionType type;
	PopplerActionGotoRemote goto_remote;
	PopplerActionUri uri;
    // Ensure the union has the right maximum size given that members we've omitted might still be
    // present in a list
    char max_size[4];
  } PopplerAction;

  typedef struct {
    PopplerRectangle area;
    PopplerAction *action;
  } PopplerLinkMapping;

  // poppler-glib functions
  PopplerDocument * poppler_document_new_from_file(const char *uri, const char *password, GError **error);
  PopplerPage * poppler_document_get_page(PopplerDocument *document, int index);
  int poppler_document_get_n_pages(PopplerDocument *document);
  char * poppler_document_get_title(PopplerDocument *document);
  char * poppler_document_get_author(PopplerDocument *document);
  char * poppler_document_get_keywords(PopplerDocument *document);

  char * poppler_page_get_selected_text(PopplerPage *page, PopplerSelectionStyle style, PopplerRectangle *selection);
  void poppler_page_free_annot_mapping(GList *list);
  void poppler_page_get_size(PopplerPage *page, double *width, double *height);
  GList * poppler_page_get_annot_mapping(PopplerPage *page);
  char * poppler_page_get_label(PopplerPage *page);
  GList * poppler_page_get_link_mapping(PopplerPage *page);
  void poppler_page_free_link_mapping(GList *list);

  PopplerAnnotType poppler_annot_get_annot_type(PopplerAnnot *poppler_annot);
  char * poppler_annot_get_contents(PopplerAnnot *poppler_annot);
  char * poppler_annot_get_modified(PopplerAnnot *poppler_annot);
  GArray * poppler_annot_text_markup_get_quadrilaterals(PopplerAnnotTextMarkup *poppler_annot);
]]
