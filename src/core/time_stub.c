#include <time.h>
#include <stdio.h>
#include <stdlib.h>

void get_current_date_c(char* buf) {
    time_t t = time(NULL);
    struct tm *tm_info = localtime(&t);
    if (tm_info) {
        strftime(buf, 11, "%Y-%m-%d", tm_info);
    } else {
        snprintf(buf, 11, "1970-01-01");
    }
}

int run_command_c(const char* cmd) {
    return system(cmd);
}

