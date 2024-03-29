/* -*- Mode: C; Character-encoding: utf-8; -*- */

/* Copyright (C) 2004-2019 beingmeta, inc.
   Copyright (C) 2020-2022 beingmeta, LLC
   This file is part of beingmeta's Kno platform and is copyright
   and a valuable trade secret of beingmeta, inc.
*/

#ifndef _FILEINFO
#define _FILEINFO __FILE__
#endif

#include "kno/lisp.h"
#include "kno/numbers.h"
#include "kno/eval.h"
#include "kno/cprims.h"

#include <libu8/libu8io.h>

#include "sundown/markdown.h"
#include "sundown/buffer.h"
#include "sundown/autolink.h"
#include "sundown/html.h"

#define OUTPUT_BUF_UNIT 1024
#define HTML_RENDER_FLAGS (HTML_USE_XHTML|HTML_ESCAPE|HTML_SAFELINK)

KNO_EXPORT int kno_init_sundown(void) KNO_LIBINIT_FN;

static int sundown_init = 0;

DEFC_PRIM("markdown->html",markdown2html_prim,
	  KNO_MAX_ARGS(2)|KNO_MIN_ARGS(1),
	  "Converts a markdown string to HTML",
	  {"mdstring",kno_string_type,KNO_VOID},
	  {"opts",kno_any_type,KNO_VOID})
static lispval markdown2html_prim(lispval mdstring,lispval opts)
{
  lispval result = KNO_VOID;

  struct sd_callbacks callbacks;
  struct html_renderopt options;
  struct sd_markdown *markdown;
  struct buf *ob;

  ob = bufnew(OUTPUT_BUF_UNIT);

  sdhtml_renderer(&callbacks, &options, HTML_RENDER_FLAGS);
  markdown = sd_markdown_new(0, 16, &callbacks, &options);

  sd_markdown_render(ob, KNO_CSTRING(mdstring), KNO_STRLEN(mdstring), markdown);
  sd_markdown_free(markdown);

  result = kno_make_string(NULL,ob->size,ob->data);

  bufrelease(ob);

  return result;
}

DEFC_PRIM("markout",markout_prim,
	  KNO_MAX_ARGS(2)|KNO_MIN_ARGS(1),
	  "Outputs HTML for a markdown string to the "
	  "standard output",
	  {"mdstring",kno_string_type,KNO_VOID},
	  {"opts",kno_any_type,KNO_VOID})
static lispval markout_prim(lispval mdstring,lispval opts)
{
  U8_OUTPUT *out = u8_current_output;

  struct sd_callbacks callbacks;
  struct html_renderopt options;
  struct sd_markdown *markdown;
  struct buf *ob;

  ob = bufnew(OUTPUT_BUF_UNIT);

  sdhtml_renderer(&callbacks, &options, HTML_RENDER_FLAGS);
  markdown = sd_markdown_new(0, 16, &callbacks, &options);

  sd_markdown_render(ob, KNO_CSTRING(mdstring), KNO_STRLEN(mdstring), markdown);
  sd_markdown_free(markdown);

  u8_putn(out,ob->data,ob->size);

  bufrelease(ob);

  return KNO_VOID;
}

static lispval sundown_module;

KNO_EXPORT int kno_init_sundown()
{
  if (sundown_init) return 0;
  /* u8_register_source_file(_FILEINFO); */
  sundown_init = 1;
  sundown_module = kno_new_cmodule("sundown",0,kno_init_sundown);

  link_local_cprims();

  u8_register_source_file(_FILEINFO);

  return 1;
}

static void link_local_cprims()
{
  
  KNO_LINK_CPRIM("MARKDOWN->HTML",markdown2html_prim,2,sundown_module);
  KNO_LINK_ALIAS("MD->HTML",markdown2html_prim,sundown_module);

  
  KNO_LINK_CPRIM("MARKOUT",markout_prim,2,sundown_module);
}
