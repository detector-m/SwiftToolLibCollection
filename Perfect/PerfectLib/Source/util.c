//
//  util.c
//  PerfectLib
//
//  Created by Riven on 16/4/21.
//  Copyright © 2016年 Riven. All rights reserved.
//

#include <stdio.h>
#include <sys/fcntl.h>

int my_fcntl(int fd, int cmd, int value);

int my_fcntl(int fd, int cmd, int value) {
    return fcntl(fd, cmd, value);
}
