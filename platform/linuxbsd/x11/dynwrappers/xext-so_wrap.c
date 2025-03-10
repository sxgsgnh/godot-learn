// This file is generated. Do not edit!
// see https://github.com/hpvb/dynload-wrapper for details
// generated by generate-wrapper.py 0.7 on 2024-12-12 14:50:47
// flags: generate-wrapper.py --sys-include thirdparty/linuxbsd_headers/X11/extensions/Xext.h --include ./thirdparty/linuxbsd_headers/X11/extensions/shape.h --sys-include thirdparty/linuxbsd_headers/X11/extensions/shape.h --soname libXext.so.6 --init-name xext --output-header ./platform/linuxbsd/x11/dynwrappers/xext-so_wrap.h --output-implementation ./platform/linuxbsd/x11/dynwrappers/xext-so_wrap.c --ignore-other --implementation-header thirdparty/linuxbsd_headers/X11/Xlib.h
//
#include <stdint.h>

#include "thirdparty/linuxbsd_headers/X11/Xlib.h"
#define XShapeQueryExtension XShapeQueryExtension_dylibloader_orig_xext
#define XShapeQueryVersion XShapeQueryVersion_dylibloader_orig_xext
#define XShapeCombineRegion XShapeCombineRegion_dylibloader_orig_xext
#define XShapeCombineRectangles XShapeCombineRectangles_dylibloader_orig_xext
#define XShapeCombineMask XShapeCombineMask_dylibloader_orig_xext
#define XShapeCombineShape XShapeCombineShape_dylibloader_orig_xext
#define XShapeOffsetShape XShapeOffsetShape_dylibloader_orig_xext
#define XShapeQueryExtents XShapeQueryExtents_dylibloader_orig_xext
#define XShapeSelectInput XShapeSelectInput_dylibloader_orig_xext
#define XShapeInputSelected XShapeInputSelected_dylibloader_orig_xext
#define XShapeGetRectangles XShapeGetRectangles_dylibloader_orig_xext
#include "thirdparty/linuxbsd_headers/X11/extensions/Xext.h"
#include "thirdparty/linuxbsd_headers/X11/extensions/shape.h"
#undef XShapeQueryExtension
#undef XShapeQueryVersion
#undef XShapeCombineRegion
#undef XShapeCombineRectangles
#undef XShapeCombineMask
#undef XShapeCombineShape
#undef XShapeOffsetShape
#undef XShapeQueryExtents
#undef XShapeSelectInput
#undef XShapeInputSelected
#undef XShapeGetRectangles
#include <dlfcn.h>
#include <stdio.h>
int (*XShapeQueryExtension_dylibloader_wrapper_xext)(Display *, int *, int *);
int (*XShapeQueryVersion_dylibloader_wrapper_xext)(Display *, int *, int *);
void (*XShapeCombineRegion_dylibloader_wrapper_xext)(Display *, Window, int, int, int, Region, int);
void (*XShapeCombineRectangles_dylibloader_wrapper_xext)(Display *, Window, int, int, int, XRectangle *, int, int, int);
void (*XShapeCombineMask_dylibloader_wrapper_xext)(Display *, Window, int, int, int, Pixmap, int);
void (*XShapeCombineShape_dylibloader_wrapper_xext)(Display *, Window, int, int, int, Window, int, int);
void (*XShapeOffsetShape_dylibloader_wrapper_xext)(Display *, Window, int, int, int);
int (*XShapeQueryExtents_dylibloader_wrapper_xext)(Display *, Window, int *, int *, int *, unsigned int *, unsigned int *, int *, int *, int *, unsigned int *, unsigned int *);
void (*XShapeSelectInput_dylibloader_wrapper_xext)(Display *, Window, unsigned long);
unsigned long (*XShapeInputSelected_dylibloader_wrapper_xext)(Display *, Window);
XRectangle *(*XShapeGetRectangles_dylibloader_wrapper_xext)(Display *, Window, int, int *, int *);
int initialize_xext(int verbose) {
  void *handle;
  char *error;
  handle = dlopen("libXext.so.6", RTLD_LAZY);
  if (!handle) {
    if (verbose) {
      fprintf(stderr, "%s\n", dlerror());
    }
    return(1);
  }
  dlerror();
// XShapeQueryExtension
  *(void **) (&XShapeQueryExtension_dylibloader_wrapper_xext) = dlsym(handle, "XShapeQueryExtension");
  if (verbose) {
    error = dlerror();
    if (error != NULL) {
      fprintf(stderr, "%s\n", error);
    }
  }
// XShapeQueryVersion
  *(void **) (&XShapeQueryVersion_dylibloader_wrapper_xext) = dlsym(handle, "XShapeQueryVersion");
  if (verbose) {
    error = dlerror();
    if (error != NULL) {
      fprintf(stderr, "%s\n", error);
    }
  }
// XShapeCombineRegion
  *(void **) (&XShapeCombineRegion_dylibloader_wrapper_xext) = dlsym(handle, "XShapeCombineRegion");
  if (verbose) {
    error = dlerror();
    if (error != NULL) {
      fprintf(stderr, "%s\n", error);
    }
  }
// XShapeCombineRectangles
  *(void **) (&XShapeCombineRectangles_dylibloader_wrapper_xext) = dlsym(handle, "XShapeCombineRectangles");
  if (verbose) {
    error = dlerror();
    if (error != NULL) {
      fprintf(stderr, "%s\n", error);
    }
  }
// XShapeCombineMask
  *(void **) (&XShapeCombineMask_dylibloader_wrapper_xext) = dlsym(handle, "XShapeCombineMask");
  if (verbose) {
    error = dlerror();
    if (error != NULL) {
      fprintf(stderr, "%s\n", error);
    }
  }
// XShapeCombineShape
  *(void **) (&XShapeCombineShape_dylibloader_wrapper_xext) = dlsym(handle, "XShapeCombineShape");
  if (verbose) {
    error = dlerror();
    if (error != NULL) {
      fprintf(stderr, "%s\n", error);
    }
  }
// XShapeOffsetShape
  *(void **) (&XShapeOffsetShape_dylibloader_wrapper_xext) = dlsym(handle, "XShapeOffsetShape");
  if (verbose) {
    error = dlerror();
    if (error != NULL) {
      fprintf(stderr, "%s\n", error);
    }
  }
// XShapeQueryExtents
  *(void **) (&XShapeQueryExtents_dylibloader_wrapper_xext) = dlsym(handle, "XShapeQueryExtents");
  if (verbose) {
    error = dlerror();
    if (error != NULL) {
      fprintf(stderr, "%s\n", error);
    }
  }
// XShapeSelectInput
  *(void **) (&XShapeSelectInput_dylibloader_wrapper_xext) = dlsym(handle, "XShapeSelectInput");
  if (verbose) {
    error = dlerror();
    if (error != NULL) {
      fprintf(stderr, "%s\n", error);
    }
  }
// XShapeInputSelected
  *(void **) (&XShapeInputSelected_dylibloader_wrapper_xext) = dlsym(handle, "XShapeInputSelected");
  if (verbose) {
    error = dlerror();
    if (error != NULL) {
      fprintf(stderr, "%s\n", error);
    }
  }
// XShapeGetRectangles
  *(void **) (&XShapeGetRectangles_dylibloader_wrapper_xext) = dlsym(handle, "XShapeGetRectangles");
  if (verbose) {
    error = dlerror();
    if (error != NULL) {
      fprintf(stderr, "%s\n", error);
    }
  }
return 0;
}
