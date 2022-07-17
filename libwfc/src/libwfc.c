

/*
 *  Author: Michael Roth <mroth@nessie.de>
 *
 *  Copyright (c) 2004, 2005, 2006 Michael Roth <mroth@nessie.de>
 *
 *  Permission is hereby granted, free of charge, to any person 
 *  obtaining a copy of this software and associated documentation
 *  files (the "Software"), to deal in the Software without restriction,
 *  including without limitation the rights to use, copy, modify, merge,
 *  publish, distribute, sublicense, and/or sell copies of the Software,
 *  and to permit persons to whom the Software is furnished to do so,
 *  subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be 
 *  included in all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 *  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 *  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 *  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 *  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 *  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 *  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 */

// LibWfc.cpp
// Extension lib defines
#define LIB_NAME "LibWfc"
#define MODULE_NAME "libwfc"

#include <stdio.h>
#include <vector>

// include the Defold SDK
#include <dmsdk/sdk.h>

#define STB_IMAGE_STATIC
#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_RESIZE_IMPLEMENTATION
#include "stb_image.h"

#define STBI_MSC_SECURE_CRT
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"
#include "stb_image_resize.h"


#define MAX_HISTOGRAM_VALUES    1000 * 1024     
#define MAX_IMAGE_NAME          256

#define TEXTBUFFER_SIZE         sizeof(char) * 1000 * 1024


static bool g_imgui_NewFrame        = false;
static char* g_imgui_TextBuffer     = 0;


// Build an image cache
typedef struct ImgObject 
{
    int                w;
    int                h;
    int                comp;
    GLuint             tid;
    char               name[MAX_IMAGE_NAME];
    unsigned char *    data;
} ImgObject;

static std::vector<ImgObject>     images;

// Image handling needs to be smarter, but this will do for the time being.
static int libwfc_ImageLoadData(lua_State* L)
{
    DM_LUA_STACK_CHECK(L, 1);
    const char * filename = luaL_checkstring(L, 1);

    // If its already in the vector, return the id
    for(int i=0; i<images.size(); i++)
    {
        if(strcmp(images[i].name, filename) == 0) 
        {
            lua_pushinteger(L, i);
            return 1;
        }
    }

    ImgObject     iobj;
    unsigned char *strdata = (unsigned char *)luaL_checkstring(L, 2);
    int lendata = luaL_checkinteger(L, 3);
    iobj.data = stbi_load_from_memory( strdata, lendata, &iobj.w, &iobj.h, NULL, STBI_rgb_alpha);
    //dmLogError("Loaded Image: %s %d %d \n", filename, iobj.w, iobj.h);
    iobj.comp = 4;
    
    if(iobj.data == nullptr)
    {
        dmLogError("Error loading image: %s\n", filename);
        lua_pushnil(L);
        return 1;
    }
    images.push_back(iobj);
    int idx = images.size() - 1;
    
    lua_pushinteger(L, idx);
    return 1;
}

static int libwfc_ImageLoad( lua_State *L)
{
    DM_LUA_STACK_CHECK(L, 1);
    const char * filename = luaL_checkstring(L, 1);

    // If its already in the vector, return the id
    for(int i=0; i<images.size(); i++)
    {
        if(strcmp(images[i].name, filename) == 0) 
        {
            lua_pushinteger(L, i);
            return 1;
        }
    }

    ImgObject     iobj;
    iobj.data = stbi_load(filename, &iobj.w, &iobj.h, NULL, STBI_rgb_alpha);
    iobj.comp = 4;
    if(iobj.data == nullptr)
    {
        dmLogError("Error loading image: %s\n", filename);
        lua_pushnil(L);
        return 1;
    }

    images.push_back(iobj);
    int idx = images.size() - 1;
  
    lua_pushinteger(L, idx);
    return 1;
}

static int libwfc_ImageLoadSize( lua_State *L )
{
    DM_LUA_STACK_CHECK(L, 1);
    const char * filename = luaL_checkstring(L, 1);
    int newwidth    = luaL_checkinteger(L, 2);
    int newheight   = luaL_checkinteger(L, 3);
    unsigned char* resizedPixels = (unsigned char *)malloc( newwidth * newheight * 4);

    ImgObject     iobj;
    iobj.data       = stbi_load(filename, &iobj.w, &iobj.h, NULL, STBI_rgb_alpha);
    iobj.comp       = 4;
    if(iobj.data == nullptr)
    {
        dmLogError("Error loading image: %s\n", filename);
        lua_pushnil(L);
        return 1;
    }
    stbir_resize_uint8(iobj.data, iobj.w, iobj.h, 0, resizedPixels, newwidth, newheight, NULL, 4);

    stbi_image_free(iobj.data);
    iobj.data = resizedPixels;
    iobj.w = newwidth;
    iobj.h = newheight;

    images.push_back(iobj);
    int idx = images.size() - 1;

    lua_pushinteger(L, idx);
    return 1;
}

static int libwfc_ImageGet( lua_State *L )
{
    int id = luaL_checkinteger(L, 1);
    if(id>=0 && id <images.size())
    {
        if(images[id].tid >= 0) {
            
            lua_pushinteger(L, images[id].w);
            lua_pushinteger(L, images[id].h);
            lua_pushinteger(L, 4);
            lua_pushlstring(L, (char *)images[id].data, images[id].w * images[id].h * 4 );
            return 4;
        }
        else 
            lua_pushnil(L);
    }
    else 
        lua_pushnil(L);
    return 1;
}

static int libwfc_ImageGetPixel( lua_State *L )
{
    int id  = luaL_checkinteger(L, 1);
    int x   = luaL_checkinteger(L, 2);
    int y   = luaL_checkinteger(L, 3);
    if(id>=0 && id <images.size())
    {
        if(images[id].tid >= 0) {
            lua_pushinteger(L, images[id].data[x * 4 + y * images[id].w * 4]);
            lua_pushinteger(L, images[id].data[x * 4 + y * images[id].w * 4 + 1]);
            lua_pushinteger(L, images[id].data[x * 4 + y * images[id].w * 4 + 2]);
            lua_pushinteger(L, images[id].data[x * 4 + y * images[id].w * 4 + 3]);
            return 4;
         }
    }
    lua_pushnil(L);
    return 1;
}

static int libwfc_ImageSave( lua_State *L )
{
    DM_LUA_STACK_CHECK(L, 1);
    const char * filename = luaL_checkstring(L, 1);
    int w = luaL_checkinteger(L, 2);
    int h = luaL_checkinteger(L, 3);
    luaL_checktype(L, 4, LUA_TTABLE);

    int imgsize = w * h;
    unsigned int *pdata = (unsigned int *)malloc( imgsize * 4 );

    // Table is at idx 5
    lua_pushnil(L);
    int valct = 0;
    // Build a number array matching the buffer. They are all assumed to be type float (for the time being)
    while(( lua_next( L, 4 ) != 0) && (valct < imgsize)) {
        pdata[valct++] = (unsigned int)lua_tonumber( L, -1 );
        lua_pop( L, 1 );
    }

    // if CHANNEL_NUM is 4, you can use alpha channel in png
    stbi_write_png(filename, w, h, STBI_rgb_alpha, (unsigned char *)pdata, w * 4);
    free(pdata);

    lua_pushinteger(L, valct);
    return 1;
}

static int libwfc_ImageFree( lua_State *L )
{
    DM_LUA_STACK_CHECK(L, 0);
    int tid = luaL_checkinteger(L, 1);
    assert(tid>=0 && tid <images.size());
    images[tid].tid = -1;
    return 0;
}

// Functions exposed to Lua
static const luaL_reg Module_methods[] =
{
    {"image_load", libwfc_ImageLoad},
    {"image_load_data", libwfc_ImageLoadData},
    {"image_get", libwfc_ImageGet},
    {"image_save", libwfc_ImageSave},
    {"image_free", libwfc_ImageFree},
    {"image_getpixel", libwfc_ImageGetPixel},
    {"image_loadsize", libwfc_ImageLoadSize },
    {0, 0}
};


static void LuaInit(lua_State* L)
{
  int top = lua_gettop(L);

  // Register lua names
  luaL_register(L, MODULE_NAME, Module_methods);

  lua_pop(L, 1);
  assert(top == lua_gettop(L));
}

dmExtension::Result AppInitializeLibWfc(dmExtension::AppParams* params)
{
  return dmExtension::RESULT_OK;
}

dmExtension::Result InitializeLibWfc(dmExtension::Params* params)
{
  // Init Lua
  LuaInit(params->m_L);
  printf("Registered %s Extension\n", MODULE_NAME);
  return dmExtension::RESULT_OK;
}

dmExtension::Result AppFinalizeLibWfc(dmExtension::AppParams* params)
{
  return dmExtension::RESULT_OK;
}

dmExtension::Result FinalizeLibWfc(dmExtension::Params* params)
{
  for(int i=0; i<images.size(); i++)
    stbi_image_free( images[i].data );
  images.clear();
  return dmExtension::RESULT_OK;
}


// Defold SDK uses a macro for setting up extension entry points:
//
// DM_DECLARE_EXTENSION(symbol, name, app_init, app_final, init, update, on_event, final)

// LibWfc is the C++ symbol that holds all relevant extension data.
// It must match the name field in the `ext.manifest`
DM_DECLARE_EXTENSION(LibWfc, LIB_NAME, AppInitializeLibWfc, AppFinalizeLibWfc, InitializeLibWfc, 0, 0, FinalizeLibWfc)
