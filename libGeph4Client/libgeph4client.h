#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

char *call_geph(const char *opt);

void upload_packet(unsigned char *pkt, int len);

int download_packet(unsigned char *buffer, int buflen);

//int try_download_packet(unsigned char *buffer, int buflen);

int check_bridges(unsigned char *buffer, int buflen);

int get_logs(unsigned char *buffer, int buflen);
