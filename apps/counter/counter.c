/* counter.c  :  This program demonstrates implementing
 * a counter on the leds.  It is also used to get information
 * on how fast we can write to registers on the FPGA.
 *
 * Build with: gcc -o counter counter.c
 * Be sure hbaserver is running and listening on port 8870
 */


#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <stddef.h>
#include <string.h>    /* for memset */
#include <arpa/inet.h> /* for inet_addr() */
#include <time.h>
#include <sys/time.h>


static void sndcmd(int fd, char *cmd); // send a command to the board, get prompt

int main()
{
    int8_t counter;         // the 8-bit count to display
    int  cmdfd;             // FD for commands for leds
    struct sockaddr_in skt; // network address for hbaserver
    int  adrlen;
    char strled[99];        // command to set the leds
    struct timeval tv1, tv2;
    double total_time;
    double writes_per_sec;

    // Open connection to DPserver daemon
    adrlen = sizeof(struct sockaddr_in);
    (void) memset((void *) &skt, 0, (size_t) adrlen);
    skt.sin_family = AF_INET;
    skt.sin_port = htons(8870);
    if ((inet_aton("127.0.0.1", &(skt.sin_addr)) == 0) ||
        ((cmdfd = socket(AF_INET, SOCK_STREAM, 0)) < 0) ||
        (connect(cmdfd, (struct sockaddr *) &skt, adrlen) < 0)) {
        printf("Error: unable to connect to hbaserver.\n");
        exit(-1);
    }

    /* Setup peripherals */
    // XXX sndcmd(cmdfd, "hbaset serial_fpga port /dev/ttyUSB1\n");
    // XXX sleep(1);

    counter = 0;   // leds are already showing zero

    // Start the timer
    gettimeofday(&tv1, NULL);

    for (int i=0; i<1024; i++)
    {
        /* display new value of count */
        sprintf(strled, "hbaset hba_basicio leds %02x\n", (counter & 0xff));
        sndcmd(cmdfd, strled);
        counter = (counter+1) % 256;
    }

    // close the socket
    close(cmdfd);

    // Stop the timer
    gettimeofday(&tv2, NULL);

    total_time = (double) (tv2.tv_usec - tv1.tv_usec) / 1000000 +
        (double) (tv2.tv_sec - tv1.tv_sec);
    printf ("Count to 1024. Time = %f seconds \n", total_time);
    writes_per_sec = 1024 / total_time;
    printf("Register writes per second: %f\n",writes_per_sec);

}

/* sndcmd():  Send a command to hbaserver and wait for a response.  The
 *     response will be a prompt character, which we ignore and return,
 *     or an error message which we send to stderr. */
static void sndcmd(int fd, char *cmd)
{
    size_t count;          // number of chars in command to send
    char   c;              // prompt or error message character
    int    retval;         // return value of read()

    count = strlen(cmd);        // should sanity check count
    write(fd, cmd, count);   // should look at write() return value

    /* loop getting characters.  Return on a prompt character '\' and
     * send any other character to stderr. */
    while (1) {
        retval = read(fd, &c, 1);
        if (0 >= retval)
            exit(1);       // did TCP conn go down?
        else if ('\\' == c)
            return;        // got a prompt char.  Done with command
        else
            write(2, &c, 1);    // send to stderr
    }
}

