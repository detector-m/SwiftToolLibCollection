/*
 *  Mod_perfect.hpp
 *  Mod_perfect
 *
 *  Created by Riven on 16/4/28.
 *  Copyright © 2016年 Riven. All rights reserved.
 *
 */

#ifndef Mod_perfect_
#define Mod_perfect_

#include "httpd.h"
#ifdef strtoul
#undef strtoul
#endif
#include <http_config.h>
#include <http_protocol.h>
#include <http_protocol.h>
#include <http_main.h>
#include <http_core.h>
#include <ap_compat.h>

/* The classes below are exported */
#pragma GCC visibility push(default)


class Mod_perfect
{
	public:
		void HelloWorld(const char *);
};

#pragma GCC visibility pop
#endif
