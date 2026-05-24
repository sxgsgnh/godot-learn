#include <xmi.h>

#include "zlib.h"

static int lua_compress(lua_State* lua) {
    size_t src_len;
    const Bytef *src = (const Bytef*)lua_tolstring(lua, 1, &src_len);
    if (!src) {
        return luaL_error(lua, "Expected string as first argument");
    }
	int compress_level = lua_tointeger(lua, 2);
	if (compress_level == -1) {
		compress_level = Z_DEFAULT_COMPRESSION;
	}
	else if (compress_level < 0 || compress_level > 9) {
		return luaL_error(lua, "Compression level must be between 0 and 9");
	}

    z_stream strm;
    int ret;

    // 估算压缩后大小
    size_t dst_len = compressBound(src_len);
    Bytef *dst = (Bytef*)malloc(dst_len);

    if (!dst) {
        return luaL_error(lua, "Memory allocation failed");
    }

    // 初始化流
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;

    // 15 + 16 表示 gzip 格式
    ret = deflateInit2(&strm, compress_level, Z_DEFLATED, 15, 8, Z_DEFAULT_STRATEGY);
    if (ret != Z_OK) {
        free(dst);
        return luaL_error(lua, "deflateInit2 failed: %d", ret);
    }

    // 设置输入输出
    strm.avail_in = src_len;
    strm.next_in = (Bytef *)src;
    strm.avail_out = dst_len;
    strm.next_out = dst;

    // 执行压缩
    ret = deflate(&strm, Z_FINISH);
    size_t compressed_len = strm.total_out;

    deflateEnd(&strm);

    if (ret == Z_STREAM_END) {
        // 压缩成功，返回压缩后的数据
        lua_pushlstring(lua, (const char*)dst, compressed_len);
        free(dst);
        return 1;
    } else {
        // 压缩失败
        free(dst);
        return luaL_error(lua, "Compression failed: %d", ret);
    }
    return ret == Z_STREAM_END ? Z_OK : ret;
}

static int lua_uncompress(lua_State* lua) {
    size_t src_len;
    Bytef *src = (Bytef*)lua_tolstring(lua, 1, &src_len);

    if (!src) {
        return luaL_error(lua, "Expected compressed data as first argument");
    }

    z_stream strm;
    int ret;

    // 初始化流
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.avail_in = src_len;
    strm.next_in = src;

    ret = inflateInit2(&strm, 15);
    if (ret != Z_OK) {
        return luaL_error(lua, "inflateInit2 failed: %d", ret);
    }

    // 动态扩展缓冲区
    size_t dst_len = src_len * 2;  // 初始大小
    Bytef *dst = NULL;

    do {
        Bytef *new_dst = (Bytef*)realloc(dst, dst_len);
        if (!new_dst) {
            free(dst);
            inflateEnd(&strm);
            return luaL_error(lua, "Memory allocation failed");
        }
        dst = new_dst;

        // 重置流状态（需要重新初始化）
        inflateEnd(&strm);
        strm.zalloc = Z_NULL;
        strm.zfree = Z_NULL;
        strm.opaque = Z_NULL;
        strm.avail_in = src_len;
        strm.next_in = src;
        strm.avail_out = dst_len;
        strm.next_out = dst;

        ret = inflateInit2(&strm, 15);
        if (ret != Z_OK) {
            free(dst);
            return luaL_error(lua, "inflateInit2 failed: %d", ret);
        }

        ret = inflate(&strm, Z_FINISH);

        if (ret == Z_BUF_ERROR && strm.avail_out == 0) {
            // 缓冲区不足，扩大后重试
            dst_len *= 2;
            continue;
        }

        break;
    } while (1);

    size_t actual_dst_len = strm.total_out;
    inflateEnd(&strm);

    if (ret == Z_STREAM_END) {
        lua_pushlstring(lua, (const char*)dst, actual_dst_len);
        free(dst);
        return 1;
    } else {
        free(dst);
        return luaL_error(lua, "Decompression failed: %d", ret);
    }
    return ret == Z_STREAM_END ? Z_OK : ret;
}

static int test(lua_State* lua) {
	printf("hello world");
	return 1;
}


int luaopen(zlib, lua_State* lua) {
    // 收集add和sub
    static const luaL_Reg funcs[] = {
        {"compress", lua_compress},
        {"decompress", lua_uncompress},
		{"test", test},
        {NULL, NULL}
    };

    lua_newtable(lua);
    // 传递函数列表
    luaL_setfuncs(lua, funcs, 0);
    return 1;
}

