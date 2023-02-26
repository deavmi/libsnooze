#include<unistd.h>
#include<sys/select.h>

void fdSetZero(fd_set* set)
{
    FD_ZERO(set);
}

void fdSetSet(int fd, fd_set* set)
{
    FD_SET(fd, set);
}