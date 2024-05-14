/*
 * Copyright (C) 2017 Microchip Technology Inc.  All rights reserved.
 *   Joshua Henderson <joshua.henderson@microchip.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

/*
 * This application uses libdrm directly to allocate planes based on a
 * configuration file and then performs various operations on the planes.
 */
#include <fcntl.h>
#include <getopt.h>
#include <string.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <xf86drm.h>
#include <time.h>

#include "planes/engine.h"
#include "planes/kms.h"
#include "planes/draw.h"

static struct kms_device *device = NULL;

static void exit_handler(int s) {
	kms_device_close(device);
	exit(1);
}

int main(int argc, char *argv[])
{
	int fd;
	struct plane_data* planes;
	struct sigaction sig_handler;
	const char* device_file = "atmel-hlcdc";
	const uint32_t colors[2] = {0x00000000, 0x00000000}; //transparent

	sig_handler.sa_handler = exit_handler;
	sigemptyset(&sig_handler.sa_mask);
	sig_handler.sa_flags = 0;
	sigaction(SIGINT, &sig_handler, NULL);

	fd = drmOpen(device_file, NULL);
	if (fd < 0) {
		fprintf(stderr, "error: open() failed: %d\n", fd);
		return 1;
	}

	device = kms_device_open(fd);
	if (!device)
		return 1;

	planes = plane_create(device,
		DRM_PLANE_TYPE_OVERLAY, 0, 250, 40,
		kms_format_val("DRM_FORMAT_ARGB8888"));

	plane_set_pos(planes, 550, 0);

	plane_set_alpha(planes, 256);

	for (;;) {
		//clear
		plane_fb_map(planes);
		memset(planes->bufs[0], 0,  planes->fbs[0]->width * planes->fbs[0]->height * 4);

		//refill
		time_t t = time(&t);
		char *tm = ctime(&t);

		strncpy(planes->text[0].str, tm, strlen(tm)-1);
		planes->text[0].x = 20;
		planes->text[0].y = 20;
		planes->text[0].color = 0x000000ff;
		planes->text[0].size = 16;

		render_fb_checker_pattern(planes->fbs[0], colors[0], colors[1]);
		render_fb_text(planes->fbs[0], planes->text[0].x, planes->text[0].y,
			planes->text[0].str, planes->text[0].color, planes->text[0].size);

		//display
		plane_apply(planes);
		sleep(1);
	}

	plane_free(planes);
	kms_device_close(device);
	drmClose(fd);

	return 0;
}
