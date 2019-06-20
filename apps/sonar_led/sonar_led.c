/* sonar_led.c  :  This program demonstrates the use of the
 * sonar and leds on the hba class project.
 *
 * Build with: gcc -o sonar_led sonar_led.c
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


static void sndcmd(int fd, char *cmd); // send a command to the board, get prompt

int main()
{
    // XXX int8_t counter;         // the 8-bit count to display
    int  tmp_int;           // a temporary integer
    int  cmdfd;             // FD for commands for leds
    int  evtfd;             // FD for sonar data
    struct sockaddr_in skt; // network address for hbaserver
    int  adrlen;
    char strled[99];        // command to set the leds
    char strevt[99];        // where to receive the button press string
    int  sonar_val;           // latest button event as an integer
    int  RANGE=3;

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
    sndcmd(cmdfd, "hbaset hba_sonar ctrl 1\n");
    sleep(1);

    /* Blink the LEDs */
    sndcmd(cmdfd, "hbaset hba_basicio leds ff\n");
    sleep(0.2);
    sndcmd(cmdfd, "hbaset hba_basicio leds 00\n");
    sleep(0.2);
    sndcmd(cmdfd, "hbaset hba_basicio leds ff\n");
    sleep(0.2);
    sndcmd(cmdfd, "hbaset hba_basicio leds 00\n");

    /* Open another connection to sonar data */
    (void) memset((void *) &skt, 0, (size_t) adrlen);
    skt.sin_family = AF_INET;
    skt.sin_port = htons(8870);
    if ((inet_aton("127.0.0.1", &(skt.sin_addr)) == 0) ||
        ((evtfd = socket(AF_INET, SOCK_STREAM, 0)) < 0) ||
        (connect(evtfd, (struct sockaddr *) &skt, adrlen) < 0)) {
        printf("Error: unable to connect to hbaserver.\n");
        exit(-1);
    }

    // XXX counter = 0;   // leds are already showing zero

    /* Start the stream of button events */
    // write(evtfd, "dpcat hba_basicio buttons\n", 20);
    /* the above command never returns so we do not use sndcmd() */

    while(1) {
        /* read sonar data */
        sprintf(strevt, "hbaget hba_sonar sonar0\n");
        write(evtfd, strevt, strlen(strevt));
        read(evtfd, strevt, 4);    // two digits, newline, prompt
        sscanf(strevt, "%02x\n\\", &sonar_val);
        printf("sonar_val: %02x\n", sonar_val);

        /* display new value of count */
        // XXX sprintf(strled, "hbaset hba_basicio leds %02x\n", (counter & 0xff));
        if (sonar_val < RANGE*1) {
            sprintf(strled, "hbaset hba_basicio leds 1\n");
        } else if (sonar_val < RANGE*2) {
            sprintf(strled, "hbaset hba_basicio leds 3\n");
        } else if (sonar_val < RANGE*3) {
            sprintf(strled, "hbaset hba_basicio leds 7\n");
        } else if (sonar_val < RANGE*4) {
            sprintf(strled, "hbaset hba_basicio leds f\n");
        } else if (sonar_val < RANGE*5) {
            sprintf(strled, "hbaset hba_basicio leds 1f\n");
        } else if (sonar_val < RANGE*6) {
            sprintf(strled, "hbaset hba_basicio leds 3f\n");
        } else if (sonar_val < RANGE*7) {
            sprintf(strled, "hbaset hba_basicio leds 7f\n");
        } else {
            sprintf(strled, "hbaset hba_basicio leds ff\n");
        }

        sndcmd(cmdfd, strled);
        sleep(0.1);
        // XXX counter++;
    }
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
