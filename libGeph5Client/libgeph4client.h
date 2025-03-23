#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

int get_log_line(unsigned char *buffer, int buflen);

/**
 * Starts a geph4-client daemon with given options.
 * @param opt JSON string with options.
 * @param daemon_rpc_secret Secret key for RPC.
 * @return An integer key for the started daemon, or -1 on error.
 */
int start(const char *opt, const char *daemon_rpc_secret);

/**
 * Stops a running geph4-client daemon.
 * @param daemon_key The key of the daemon to stop.
 * @return 0 on success, non-zero on failure.
 */
int stop(int daemon_key);

/**
 * Performs a synchronization operation.
 * @param opt JSON string with options.
 * @param buffer Buffer for input/output data.
 * @param buflen Length of the buffer.
 * @return Length of data written to the buffer, or -1 on error.
 */
int geph_sync(const char *opt, char *buffer, int buflen);

/**
 * Performs a binder RPC operation.
 * @param req Request string.
 * @param buffer Buffer for input/output data.
 * @param buflen Length of the buffer.
 * @return Length of data written to the buffer, or -1 on error.
 */
int binder_rpc(const char *req, char *buffer, int buflen);

/**
 * Creates a debug pack.
 * @param daemon_key The key of the daemon.
 * @param dest Destination path for the debug pack.
 * @return 0 on success, -1 if daemon not found, -2 on other errors.
 */
int debugpack(int daemon_key, const char *dest);

/**
 * Retrieves the version of the library.
 * @param buffer Buffer for the version string.
 * @param buflen Length of the buffer.
 * @return Length of data written to the buffer, or -1 on error.
 */
int version(char *buffer, int buflen);

/**
 * Sends a VPN packet.
 * @param daemon_key The key of the daemon.
 * @param pkt Pointer to the packet data.
 * @param len Length of the packet data.
 * @return 0 on success, -1 if daemon not found, -2 on other errors.
 */
int send_vpn(int daemon_key, const unsigned char *pkt, int len);

/**
 * Receives a VPN packet.
 * @param daemon_key The key of the daemon.
 * @param buffer Buffer for the received packet.
 * @param buflen Length of the buffer.
 * @return Length of data written to the buffer, or -1 on error.
 */
int recv_vpn(int daemon_key, char *buffer, int buflen);

//void upload_packet(unsigned char *pkt, int len);
//
//int download_packet(unsigned char *buffer, int buflen);