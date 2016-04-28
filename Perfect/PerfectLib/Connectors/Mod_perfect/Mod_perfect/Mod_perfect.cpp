/*
 *  Mod_perfect.cpp
 *  Mod_perfect
 *
 *  Created by Riven on 16/4/28.
 *  Copyright © 2016年 Riven. All rights reserved.
 *
 */

#include <iostream>
#include "Mod_perfect.hpp"
#include "Mod_perfectPriv.hpp"

void Mod_perfect::HelloWorld(const char * s)
{
	 Mod_perfectPriv *theObj = new Mod_perfectPriv;
	 theObj->HelloWorldPriv(s);
	 delete theObj;
};

void Mod_perfectPriv::HelloWorldPriv(const char * s) 
{
	std::cout << s << std::endl;
};

